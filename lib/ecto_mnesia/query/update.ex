defmodule Ecto.Mnesia.Query.Update do
  @moduledoc """
  This module implements `update` instructions from Ecto.Query struct.
  """
  alias Ecto.Mnesia.{Table, Query}

  def update_record(record, _table, [], _params), do: record
  def update_record(record, table, [%Ecto.Query.QueryExpr{expr: expr} | expr_t], params) do
    record
    |> apply_rules(table, expr, params)
    |> update_record(table, expr_t, params)
  end

  defp apply_rules(record, _table, [], _params), do: record
  defp apply_rules(record, table, [rule | rules_t], params) do
    record
    |> apply_conditions(table, rule, params)
    |> apply_rules(table, rules_t, params)
  end

  defp apply_conditions(record, _table, {_, []}, _params), do: record
  defp apply_conditions(record, table, {key, [con | conds_t]}, params) do
    record
    |> apply_condition(table, {key, con}, params)
    |> apply_conditions(table, {key, conds_t}, params)
  end

  defp apply_condition(record, table, {:set, {field, expr}}, params) do
    index = get_field_index!(table, field)
    value = Query.condition_expression(expr, table, params)

    record
    |> List.replace_at(index, value)
  end

  defp apply_condition(record, table, {:inc, {field, expr}}, params) do
    index = get_field_index!(table, field)
    value = Query.condition_expression(expr, table, params)

    record
    |> List.update_at(index, &(&1 + value))
  end

  defp apply_condition(_record, _table, {:push, _}, _params), do: throw ":push updates is not supported by the adapter"
  defp apply_condition(_record, _table, {:pull, _}, _params), do: throw ":pull updates is not supported by the adapter"

  defp get_field_index!(table, field) do
    index = table
    |> Table.get_name()
    |> :mnesia.table_info(:attributes)
    |> Enum.find_index(&(field == &1))

    case index do
      nil -> throw "Field `#{field}` does not exist in table `#{table}`"
      i -> i
    end
  end
end
