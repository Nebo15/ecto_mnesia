defmodule Ecto.Mnesia.Record.Update do
  @moduledoc """
  This module decodes `query.updates` AST (from `Ecto.Query`) and applies all changes on a Mnesia record.
  """
  alias Ecto.Mnesia.Record.Context

  @doc """
  Update record by a `Ecto.Query.updates` instructions.
  """
  def update_record(record, [], _sources, _context), do: record
  def update_record(record, [%Ecto.Query.QueryExpr{expr: expr} | expr_t], sources, context) do
    record
    |> apply_rules(expr, sources, context)
    |> update_record(expr_t, sources, context)
  end

  defp apply_rules(record, [], _sources, _context), do: record
  defp apply_rules(record, [rule | rules_t], sources, context) do
    record
    |> apply_conditions(rule, sources, context)
    |> apply_rules(rules_t, sources, context)
  end

  defp apply_conditions(record, {_, []}, _sources, _context), do: record
  defp apply_conditions(record, {key, [con | conds_t]}, sources, context) do
    record
    |> apply_condition({key, con}, sources, context)
    |> apply_conditions({key, conds_t}, sources, context)
  end

  defp apply_condition(record, {:set, {field, expr}}, sources, context) do
    index = Context.find_field_index!(field, context)
    value = Context.MatchSpec.unbind(expr, sources)

    record
    |> List.replace_at(index, value)
  end

  defp apply_condition(record, {:inc, {field, expr}}, sources, context) do
    index = Context.find_field_index!(field, context)
    value = Context.MatchSpec.unbind(expr, sources)

    record
    |> List.update_at(index, fn
      numeric when is_number(numeric) or is_float(numeric) ->
        numeric + value
      nil ->
        value
    end)
  end

  defp apply_condition(record, {:push, {field, expr}}, sources, context) do
    index = Context.find_field_index!(field, context)
    value = Context.MatchSpec.unbind(expr, sources)

    record
    |> List.update_at(index, fn
      list when is_list(list) -> list ++ [value]
      nil -> [value]
    end)
  end

  defp apply_condition(record, {:pull, {field, expr}}, sources, context) do
    index = Context.find_field_index!(field, context)
    value = Context.MatchSpec.unbind(expr, sources)

    record
    |> List.update_at(index, fn
      list when is_list(list) -> Enum.filter(list, &(&1 != value))
      nil -> []
    end)
  end
end
