defmodule Ecto.Mnesia.Query do
  @moduledoc """
  This module converts Ecto.Query AST to MatchSpec.

  Specs:
    - [QLC](http://erlang.org/doc/man/qlc.html)
    - [Match Specification](http://erlang.org/doc/apps/erts/match_spec.html)
  """
  require Logger
  alias Ecto.Mnesia.Record.Context

  def match_spec(%Ecto.SubQuery{}, _context, _bindings),
    do: raise Ecto.Query.CompileError, "Subqueries is not supported by Mnesia adapter."
  def match_spec(%Ecto.Query{havings: havings}, _context, _bindings) when is_list(havings) and length(havings) > 0,
    do: raise Ecto.Query.CompileError, "Havings is not supported by Mnesia adapter."
  def match_spec(%Ecto.Query{} = query, %Context{} = context, bindings) when is_list(bindings) do
    context = context
    |> Context.update_select(query)
    |> Context.update_bindings(bindings)

    # TODO rename bindings to sources
    # https://github.com/elixir-ecto/ecto/blob/8cddc211ac9423702faee8b5528a1b11474762d3/lib/ecto/adapters/postgres/connection.ex#L406

    body = match_body(context, bindings)

    # Save placeholders in context so we will know how to extract result data
    context = context
    |> Context.update_match_body(body)

    {context, [{match_head(context), match_conditions(query, bindings, context), [body]}]}
  end

  # Build match_spec head part (data placeholders)
  defp match_head(%Context{table: table} = context) do
    context
    |> Context.get_placeholders()
    |> Enum.into([table])
    |> List.to_tuple()
  end

  # Select was present
  defp match_body(%Context{select: %Ecto.Query.SelectExpr{fields: expr}} = context, bindings) do
    expr
    |> select_fields(bindings)
    |> Enum.map(&Context.find_placeholder!(&1, context))
  end

  # Select wasn't present, so we select everything
  defp match_body(%Context{select: select} = context, _bindings) when is_list(select) do
    select
    |> Enum.map(&Context.find_placeholder!(&1, context))
  end

  defp select_fields({:&, [], [0, fields, _]}, _bindings), do: fields
  defp select_fields({{:., [], [{:&, [], [0]}, field]}, _, []}, _bindings), do: [field]
  defp select_fields({:^, [], [_]} = expr, bindings), do: [unbind(expr, bindings)]
  defp select_fields(exprs, bindings) when is_list(exprs) do
    exprs
    |> Enum.flat_map(&select_fields(&1, bindings))
  end

  # Resolve params
  defp match_conditions(%Ecto.Query{wheres: wheres}, bindings, context),
    do: match_conditions(wheres, bindings, context, [])
  defp match_conditions([], _bindings, _context, acc),
    do: acc
  defp match_conditions([%{expr: expr, params: params} | tail], bindings, context, acc) do
    condition = match_condition(expr, merge_bindings(bindings, params), context)
    match_conditions(tail, bindings, context, [condition | acc])
  end

  # `expr.params` seems to be always empty, but we need to deal with cases when it's not
  defp merge_bindings(bindings1, bindings2) when is_list(bindings1) and is_list(bindings2), do: bindings1 ++ bindings2
  defp merge_bindings(bindings, nil), do: bindings

  # `is_nil` is a special case when we need to :== with nil value
  defp match_condition({:is_nil, [], [field]}, bindings, context) do
    {:==, condition_expression(field, bindings, context), nil}
  end

  # `:in` is a special case when we need to expand it to multiple `:or`'s
  defp match_condition({:in, [], [field, parameters]}, bindings, context) do
    field = condition_expression(field, bindings, context)

    parameters
    |> Enum.map(fn parameter ->
      {:==, field, condition_expression(parameter, bindings, context)}
    end)
    |> List.insert_at(0, :or)
    |> List.to_tuple()
  end

  # Conditions that have one argument. Functions (is_nil, not).
  defp match_condition({op, [], [field]}, bindings, context) do
    {guard_function_operation(op), condition_expression(field, bindings, context)}
  end

  # Other conditions with multiple arguments (<, >, ==, !=, etc)
  defp match_condition({op, [], [field, parameter]}, bindings, context) do
    {
      guard_function_operation(op),
      condition_expression(field, bindings, context),
      condition_expression(parameter, bindings, context)
    }
  end

  # Fields
  def condition_expression({{:., [], [{:&, [], [0]}, field]}, _, []}, _bindings, context) do
    Context.find_placeholder!(field, context)
  end

  # Recursively expand ecto query expressions and build conditions
  def condition_expression({op, [], [left, right]}, bindings, context) do
    {
      guard_function_operation(op),
      condition_expression(left, bindings, context),
      condition_expression(right, bindings, context)
    }
  end

  # Another part of this function is to use binded variables values
  def condition_expression(%Ecto.Query.Tagged{value: value}, _bindings, _context), do: value
  def condition_expression(raw_value, bindings, _context), do: unbind(raw_value, bindings)

  def unbind({:^, [], [index]}, bindings) do
    bindings
    |> Enum.at(index)
    |> get_binded()
  end
  def unbind(value, _bindings), do: value

  # Binded variable value
  defp get_binded({value, {_, _}}), do: value
  defp get_binded(value), do: value

  # Convert Ecto.Query operations to MatchSpec analogs. (Only ones that doesn't match.)
  defp guard_function_operation(:!=), do: :'/='
  defp guard_function_operation(:<=), do: :'=<'
  defp guard_function_operation(op), do: op
end
