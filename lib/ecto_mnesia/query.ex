defmodule Ecto.Mnesia.Query do
  @moduledoc """
  This module converts Ecto.Query AST to MatchSpec.

  Specs:
    - [QLC](http://erlang.org/doc/man/qlc.html)
    - [Match Specification](http://erlang.org/doc/apps/erts/match_spec.html)
  """
  require Logger

  def match_spec(%Ecto.SubQuery{}, _opts),
    do: raise Ecto.Query.CompileError, "Subqueries is not supported by Mnesia adapter."
  def match_spec(%Ecto.Query{havings: havings}, _opts)
    when is_list(havings) and length(havings) > 0,
    do: raise Ecto.Query.CompileError, "Havings is not supported by Mnesia adapter."

  def match_spec(%Ecto.Query{from: {table, _schema}, wheres: wheres, select: select}, opts) do
    schema = table |> String.to_atom |> :mnesia.table_info(:attributes)
    [{match_head(table), match_conditions(wheres, table, opts, []), [:"$_"]}]
  end
  def match_spec(_schema, table, fields, wheres, opts) do
    schema = table |> String.to_atom |> :mnesia.table_info(:attributes)
    [{match_head(table), match_conditions(wheres, table, opts, []), [match_body(fields, schema)]}]
  end

  defp match_head(table) do
    table
    |> placeholders
    |> Dict.values
    |> Enum.into([String.to_atom(table)])
    |> List.to_tuple
  end

  defp match_conditions([], _table, _opts, acc), do: acc
  defp match_conditions([%{expr: expr, params: params} | tail], table, _opts, acc) do
    # Resolve params
    condition = match_condition(expr, table, params)
    match_conditions(tail, table, params, [condition | acc])
  end

  # For Queries without `select` section
  defp match_body(nil, schema) do
    schema
    |> Enum.map(fn field ->
      schema
      |> Enum.find_index(&(&1 == field))
      |> Kernel.+(1)
      |> Integer.to_string
      |> (&String.to_atom("$" <> &1)).()
    end)
  end

  defp match_body([{:&, [], [0, fields, _fields_count]}], schema) do
    fields
    |> List.foldl([], fn(field, acc) ->
      pos = schema
        |> Enum.find_index(&(&1 == field))
        |> Kernel.+(1)
        |> Integer.to_string
        |> (&String.to_atom("$" <> &1)).()

      acc ++ [pos]
    end)
  end

  # `is_nil` is a special case when we need to :== with nil value
  defp match_condition({:is_nil, [], [field]}, table, opts) do
    {:==, condition_expression(field, table, opts), nil}
  end

  # `:in` is a special case when we need to expand it to multiple `:or`'s
  defp match_condition({:in, [], [field, parameters]}, table, opts) do
    field = condition_expression(field, table, opts)

    parameters
    |> Enum.map(fn parameter ->
      {:==, field, condition_expression(parameter, table, opts)}
    end)
    |> List.insert_at(0, :or)
    |> List.to_tuple
  end

  # Conditions that have one argument. Functions (is_nil, not).
  defp match_condition({op, [], [field]}, table, opts) do
    {guard_function_operation(op), condition_expression(field, table, opts)}
  end

  # Other conditions with multiple arguments (<, >, ==, !=, etc)
  defp match_condition({op, [], [field, parameter]}, table, opts) do
    {
      guard_function_operation(op),
      condition_expression(field, table, opts),
      condition_expression(parameter, table, opts)
    }
  end

  # Fields
  defp condition_expression({{:., [], [{:&, [], [0]}, name]}, _, []}, table, _opts) do
    dict = placeholders(table)
    case List.keyfind(dict, name, 0) do
      {_name, value} -> value
      nil -> throw "Field `#{name}` does not exist in table `#{table}`"
    end
  end

  # Binded variable need to be casted to type that can be compared by Mnesia guard function
  defp condition_expression({:^, [], [index]}, _table, opts) do
    opts
    |> Enum.at(index)
    |> get_binded()
    |> Ecto.Mnesia.Schema.cast_type()
  end

  # Binded variable value
  defp get_binded({value, {_, _}}), do: value
  defp get_binded(value), do: value

  # Recursively expand ecto query expressions and build conditions
  defp condition_expression({op, [], [left, right]}, table, opts) do
    {guard_function_operation(op), condition_expression(left, table, opts), condition_expression(right, table, opts)}
  end

  # Another part of this function is to use binded variables values
  defp condition_expression(%Ecto.Query.Tagged{value: value}, _table, _opts) do
    value
  end

  defp condition_expression(raw_value, _table, _opts) do
    raw_value
  end

  defp placeholders(table) do
    fields =
      table |>
      String.to_atom |>
      :mnesia.table_info(:attributes)

    placeholders =
      1..length(fields)
      |> Enum.map(&"$#{&1}")
      |> Enum.map(&String.to_atom/1)

    fields
    |> Enum.zip(placeholders)
  end

  @doc """
  Convert Ecto.Query operations to MatchSpec analogs. (Only ones that doesn't match.)
  """
  defp guard_function_operation(:!=), do: :'/='
  defp guard_function_operation(:<=), do: :'=<'
  defp guard_function_operation(op), do: op
end
