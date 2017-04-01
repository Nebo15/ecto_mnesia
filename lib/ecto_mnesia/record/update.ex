defmodule EctoMnesia.Record.Update do
  @moduledoc """
  This module decodes `query.updates` AST (from `Ecto.Query`) and applies all changes on a Mnesia record.
  """
  alias EctoMnesia.Record.Context

  @doc """
  Build am update statement from Keyword for `EctoMnesia.Table.update/4`.
  """
  def from_keyword(_schema, _table, params, %Context{table: %Context.Table{structure: structure, name: name}}) do
    Enum.map(params, fn {key, value} ->
      case Keyword.get(structure, key) do
        {i, _} -> {i, value}
        nil -> raise ArgumentError, "Field `#{inspect key}` does not exist in table `#{inspect name}`"
      end
    end)
  end

  @doc """
  Update record by a `Ecto.Query.updates` instructions.
  """
  def update_record(exprs, sources, context), do: update_record([], exprs, sources, context)
  def update_record(updates, [], _sources, _context), do: updates
  def update_record(updates, [%Ecto.Query.QueryExpr{expr: expr} | expr_t], sources, context) do
    updates
    |> apply_rules(expr, sources, context)
    |> update_record(expr_t, sources, context)
  end

  defp apply_rules(updates, [], _sources, _context), do: updates
  defp apply_rules(updates, [rule | rules_t], sources, context) do
    updates
    |> apply_conditions(rule, sources, context)
    |> apply_rules(rules_t, sources, context)
  end

  defp apply_conditions(updates, {_, []}, _sources, _context), do: updates
  defp apply_conditions(updates, {key, [con | conds_t]}, sources, context) do
    updates
    |> apply_condition({key, con}, sources, context)
    |> apply_conditions({key, conds_t}, sources, context)
  end

  defp apply_condition(updates, {:set, {field, expr}}, sources, context) do
    index = Context.find_field_index!(field, context)
    value = Context.MatchSpec.unbind(expr, sources)

    updates ++ [{index, value}]
  end

  defp apply_condition(updates, {op, {field, expr}}, sources, context) when op in [:inc, :push, :pull] do
    index = Context.find_field_index!(field, context)
    value = Context.MatchSpec.unbind(expr, sources)

    updates ++ [{index, op, value}]
  end
end
