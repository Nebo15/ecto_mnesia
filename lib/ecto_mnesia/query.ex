defmodule Ecto.Mnesia.Query do
  @moduledoc """
  Ecto.Query converter interface for MatchSpec.
  """
  require Logger

  def  match_spec(model, tab, fields: fields, wheres: wheres) do
       [{head(tab), guards(wheres, tab, []), [match_pos(fields, model)]}] end

  def  head(table) do
       table |> placeholders |> Dict.values
             |> Enum.into([String.to_atom(table)]) |> List.to_tuple end

  def  unholders({{:., [], [{:&, [], [0]}, name]}, _, []}, table) do
       table |> placeholders |> Dict.get(name) end

  def  placeholders(table) do
       fields   = table |> String.to_atom |> :mnesia.table_info(:attributes)
       placeholders = 1..length(fields) |> Enum.map(&"$#{&1}") |> Enum.map(&String.to_atom/1)
       fields |> Enum.zip(placeholders) end

  def  str(field, model), do: Integer.to_string :string.str(model.__schema__(:fields),[field])

  @doc false
  def  match_pos(fields, model) do
       fields |> Enum.map(fn field -> String.to_atom("$" <> str(field, model)) end) end

  def  result([], _, acc), do: acc |> Enum.reverse
  def  result([{{:., [], [{:&, [], [0]}, field]}, _, _} | t], table, acc) do
       result(t, table, [field | acc]) end

  def  guards([], _, acc) do acc end
  def  guards([%{expr: {operator, [], [field, parameter]}} | t], table, acc) do
       guard = {operator, unholders(field, table), parameter}
       guards(t, table, [guard | acc]) end

  def  resolve([], _, acc), do: acc
  def  resolve([{op, p, {:^, [], [idx]}} | t], par, acc) do
       resolve(t, par, [{op, p, Enum.at(par, idx)} | acc]) end
  def  resolve([{op, p, val} | t], par, acc) do
       resolve(t, par, [{op, p, val} | acc]) end

  def  make_tuple(schema, params, table) do
       Logger.info("Schema: #{inspect schema}")
       fields = schema.__schema__(:fields)
       List.foldl(params, List.to_tuple([table | List.duplicate(nil, length(fields))]),
          fn ({k, v}, acc) -> :erlang.setelement(:string.str(fields,[k]) + 1, acc, v) end) end

  def  ordering([], _), do: []
  def  ordering(order_bys, table), do: ordering(order_bys, table, [])

  def  ordering([], _, acc), do: acc |> Enum.reverse
  def  ordering([%{expr: [asc: {{:., [], [{:&, [], [0]}, field]}, _,_}]} | t], table, acc) do
       placeholder = table |> placeholders |> Dict.get(field)
       ordering(t, table, [placeholder | acc]) end

end
