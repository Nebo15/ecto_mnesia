defmodule Ecto.Mnesia.Adapter.Ordering do
  @moduledoc """
  Since there are `order by` function in Mnesia,
  we need to generate function that will order data after fetching it from DB.
  """
  require Logger

  @doc """
  This function generates the ordering function that will be applied on a query result.
  """
  def get_ordering_fn([]), do: &(&1)
  def get_ordering_fn(ordering) do
    fn data ->
      data
      |> Enum.sort(&sort(&1, &2, ordering))
    end
  end

  defp sort([left], [right], ordering) do
    Logger.debug("#{inspect left}, #{inspect right}, #{inspect ordering}")
    cmp(left, right, ordering) == :gt
  end

  defp cmp(left, right, [%{expr: [asc: {{:., [], [{:&, [], [0]}, field]}, _,_}]} | t]) do
    case {Map.get(left, field), Map.get(right, field)} do
      {l, r} when l < r ->
        :lt
      {l, r} when l > r ->
        :gt
      _eq ->
        cmp(left, right, t)
    end
  end

  defp cmp(left, right, [%{expr: [desc: {{:., [], [{:&, [], [0]}, field]}, _,_}]} | t]) do
    case {Map.get(left, field), Map.get(right, field)} do
      {l, r} when l < r ->
        :gt
      {l, r} when l > r ->
        :lt
      _eq ->
        cmp(left, right, t)
    end
  end
end
