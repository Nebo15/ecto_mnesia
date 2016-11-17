defmodule Ecto.Mnesia.Adapter.Ordering do
  @moduledoc """
  Since there are `order by` function in Mnesia,
  we need to generate function that will order data after fetching it from DB.
  """

  @doc """
  This function generates the ordering function that will be applied on a query result.
  """
  def get_ordering_fn([], _), do: &(&1)
  def get_ordering_fn(ordering, table), do: fn data -> order(ordering, table, data) end

  # defp order([], _), do: []
  # defp order(order_bys, table), do: order(order_bys, table, [])

  defp order([], _, acc), do: acc |> Enum.reverse
  defp order([%{expr: [asc: {{:., [], [{:&, [], [0]}, field]}, _,_}]} | t], table, acc) do
    placeholder = table
    |> Ecto.Mnesia.Query.placeholders
    |> Dict.get(field)

    order(t, table, [placeholder | acc])
  end
end
