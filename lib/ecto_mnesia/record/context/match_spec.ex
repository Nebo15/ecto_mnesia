defmodule EctoMnesia.Record.Context.MatchSpec do
  @moduledoc """
  This module provides a context that is able to rebuild Mnesia `match_spec` by `Ecto.Query` AST whenever new query
  is assigned to a context.

  Specs:
    - [QLC](http://erlang.org/doc/man/qlc.html)
    - [Match Specification](http://erlang.org/doc/apps/erts/match_spec.html)
  """
  alias EctoMnesia.Record.Context

  defstruct head: [], conditions: [], body: []

  def update(%Context{query: %Context.Query{sources: sources}} = context, %Ecto.Query{} = query) do
    %{context | match_spec: %{
      context.match_spec |
        body: match_body(context, sources),
        head: match_head(context),
        conditions: match_conditions(query, sources, context)
      }
    }
  end

  def dump(%Context.MatchSpec{head: head, conditions: conditions, body: body}) do
    [{head, conditions, [body]}]
  end

  # Build match_spec head part (data placeholders)
  defp match_head(%Context{table: %Context.Table{name: table_name}} = context) do
    context
    |> Context.get_fields_placeholders()
    |> Enum.into([table_name])
    |> List.to_tuple()
  end

  # Select was present
  defp match_body(%Context{query: %Context.Query{select: %Ecto.Query.SelectExpr{fields: expr}}} = context, sources) do
    expr
    |> select_fields(sources)
    |> Enum.map(&Context.find_field_placeholder!(&1, context))
  end

  # Select wasn't present, so we select everything
  defp match_body(%Context{query: %Context.Query{select: select}} = context, _sources) when is_list(select) do
    Enum.map(select, &Context.find_field_placeholder!(&1, context))
  end

  defp select_fields({:&, [], [0, fields, _]}, _sources), do: fields
  defp select_fields({{:., [], [{:&, [], [0]}, field]}, _, []}, _sources), do: [field]
  defp select_fields({:^, [], [_]} = expr, sources), do: [unbind(expr, sources)]
  defp select_fields(exprs, sources) when is_list(exprs) do
    Enum.flat_map(exprs, &select_fields(&1, sources))
  end

  # Resolve params
  defp match_conditions(%Ecto.Query{wheres: wheres}, sources, context),
    do: match_conditions(wheres, sources, context, [])
  defp match_conditions([], _sources, _context, acc),
    do: acc
  defp match_conditions([%{expr: expr, params: params} | tail], sources, context, acc) do
    condition = condition_expression(expr, merge_sources(sources, params), context)
    match_conditions(tail, sources, context, [condition | acc])
  end

  # `expr.params` seems to be always empty, but we need to deal with cases when it's not
  defp merge_sources(sources1, sources2) when is_list(sources1) and is_list(sources2), do: sources1 ++ sources2
  defp merge_sources(sources, nil), do: sources

  # Unbinding parameters
  def condition_expression({:^, [], [_]} = binding, sources, _context), do: unbind(binding, sources)
  def condition_expression({op, [], [field, {:^, [], [_]} = binding]}, sources, context) do
     parameters = unbind(binding, sources)
     condition_expression({op, [], [field, parameters]}, sources, context)
  end

  # `is_nil` is a special case when we need to :== with nil value
  def condition_expression({:is_nil, [], [field]}, sources, context) do
    {:==, condition_expression(field, sources, context), nil}
  end

  # `:in` is a special case when we need to expand it to multiple `:or`'s
  def condition_expression({:in, [], [field, parameters]}, sources, context) when is_list(parameters) do
    field = condition_expression(field, sources, context)

    expr = parameters
    |> unbind(sources)
    |> Enum.map(fn parameter ->
      {:==, field, condition_expression(parameter, sources, context)}
    end)

    if expr == [] do
      {:==, true, false} # Hack to return zero values
    else
      expr
      |> List.insert_at(0, :or)
      |> List.to_tuple()
    end
  end

  def condition_expression({:in, [], [_field, _parameters]}, _sources, _context) do
    raise RuntimeError, "Complex :in queries is not supported by the Mnesia adapter."
  end

  # Conditions that have one argument. Functions (is_nil, not).
  def condition_expression({op, [], [field]}, sources, context) do
    {guard_function_operation(op), condition_expression(field, sources, context)}
  end

  # Other conditions with multiple arguments (<, >, ==, !=, etc)
  def condition_expression({op, [], [field, parameter]}, sources, context) do
    {
      guard_function_operation(op),
      condition_expression(field, sources, context),
      condition_expression(parameter, sources, context)
    }
  end

  # Fields
  def condition_expression({{:., [], [{:&, [], [0]}, field]}, _, []}, _sources, context) do
    Context.find_field_placeholder!(field, context)
  end

  # Recursively expand ecto query expressions and build conditions
  def condition_expression({op, [], [left, right]}, sources, context) do
    {
      guard_function_operation(op),
      condition_expression(left, sources, context),
      condition_expression(right, sources, context)
    }
  end

  # Another part of this function is to use binded variables values
  def condition_expression(%Ecto.Query.Tagged{value: value}, _sources, _context), do: value
  def condition_expression(raw_value, sources, _context), do: unbind(raw_value, sources)

  def unbind({:^, [], [start_at, end_at]}, sources) do
    Enum.slice(sources, Range.new(start_at, end_at))
  end
  def unbind({:^, [], [index]}, sources) do
    sources
    |> Enum.at(index)
    |> get_binded()
  end
  def unbind(value, _sources), do: value

  # Binded variable value
  defp get_binded({value, {_, _}}), do: value
  defp get_binded(value), do: value

  # Convert Ecto.Query operations to MatchSpec analogs. (Only ones that doesn't match.)
  defp guard_function_operation(:!=), do: :'/='
  defp guard_function_operation(:<=), do: :'=<'
  defp guard_function_operation(op), do: op
end
