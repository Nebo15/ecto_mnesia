defmodule Ecto.Mnesia.Query do
  @moduledoc """
  Ecto.Query converter interface for MatchSpec.
  """
  require Logger

  def  match_spec(model, tab, fields, wheres, params) do
       model = tab |> String.to_atom |> :mnesia.table_info(:attributes)
       Logger.info("MSPEC FIELDS #{inspect fields}")
       Logger.info("MSPEC SELECT #{inspect model}")
       [{head(tab), guards(wheres, tab, params, []), [[:"$_"]]}] end
                                                     #[match_pos(fields,model)]}] end

  def  head(table) do
       table |> placeholders |> Dict.values
             |> Enum.into([String.to_atom(table)]) |> List.to_tuple end

  def  unholders({{:., [], [{:&, [], [0]}, name]}, _, []} = a, table, params) do
       dict = placeholders(table)
       Logger.info("Dot #{inspect dict}")
       Logger.info("Name #{inspect name}")
       Logger.info("Table #{inspect table}")
       Logger.info("Params #{inspect params}")
       value =  case List.keyfind(dict, name, 0) do
               {name, value} -> value;
               :undefined -> nil end
#       value = table |> placeholders |> Dict.get(name)
       Logger.info("Dot #{inspect value}")
       value
       end
  def  unholders({:^, [], [index]} = a, table, params) do
       Logger.info("Quote #{inspect a}")
       transmute(:lists.nth(index+1,params))
  end
  def  unholders({op, [], [left, right]} = a, table, params) do
       Logger.info("Op #{inspect a}")
       {op, unholders(left, table, params), unholders(right, table, params)} end

  def  placeholders(table) do
       fields   = table |> String.to_atom |> :mnesia.table_info(:attributes)
       placeholders = 1..length(fields) |> Enum.map(&"$#{&1}") |> Enum.map(&String.to_atom/1)
       fields |> Enum.zip(placeholders) end

  def  str(field, model),   do: Integer.to_string :string.str(model.__schema__(:fields),[field])
  def  str2(field, fields), do: Integer.to_string :string.str(fields,[field])

  @doc false
  def  match_pos(fields, model) do
       fields |> Enum.map(fn
           {{_, _, [_, field]}, _, _} -> String.to_atom("$" <> str2(field, model)) end) end

  def  result([], _, acc), do: acc |> Enum.reverse
  def  result([{{:., [], [{:&, [], [0]}, field]}, _, _} | t], table, acc) do
       result(t, table, [field | acc]) end

  def  guards([], _, params, acc) do acc end
  def  guards([%{expr: {operator, [], [field, parameter]}} | t], table, params, acc) do
       :io.format("Guard: ~p~n",[{operator, field, parameter}])
       guard = {operator, unholders(field, table, params), unholders(parameter, table, params) }
       guards(t, table, params, [guard | acc]) end

  def  resolve([], _, acc), do: acc
  def  resolve([{op, p, {:^, [], [idx]}} | t], par, acc) do
       resolve(t, par, [{op, p, Enum.at(par, idx)} | acc]) end
  def  resolve([{op, p, val} | t], par, acc) do
       resolve(t, par, [{op, p, val} | acc]) end

  def  make_tuple(schema, params, table) do
       Logger.info("Schema: #{inspect schema}")
       fields = schema.__schema__(:fields)
       List.foldl(params, List.to_tuple([table | List.duplicate(nil, length(fields))]),
          fn ({k, v}, acc) -> :erlang.setelement(:string.str(fields,[k]) + 1, acc, transmute(v)) end) end

  def  transmute(%Decimal{coef: x, exp: y, sign: z}), do: x
  def  transmute(x), do: x

  def  ordering([], _), do: []
  def  ordering(order_bys, table), do: ordering(order_bys, table, [])

  def  ordering([], _, acc), do: acc |> Enum.reverse
  def  ordering([%{expr: [asc: {{:., [], [{:&, [], [0]}, field]}, _,_}]} | t], table, acc) do
       placeholder = table |> placeholders |> Dict.get(field)
       ordering(t, table, [placeholder | acc]) end

end
