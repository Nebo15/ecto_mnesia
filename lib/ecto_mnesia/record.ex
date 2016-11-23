defmodule Ecto.Mnesia.Record do
  @moduledoc """
  This module provides set of helpers for conversions between Mnesia records and Ecto Schemas.
  """
  alias Ecto.Mnesia.Record.Context
  alias Ecto.Mnesia.Query

  @doc """
  Convert Ecto Schema struct to tuple that can be inserted to Mnesia.
  """
  def new(schema, params, table) do
    table = table |> Ecto.Mnesia.Table.get_name()
    fields = schema.__schema__(:fields)
    nilled_tuple = List.to_tuple([table | List.duplicate(nil, length(fields))])
    params
    |> List.foldl(nilled_tuple, fn ({k, v}, acc) ->
      :erlang.setelement(:string.str(fields, [k]) + 1, acc, v)
    end)
  end

  def to_schema([], _), do: []
  def to_schema([el | _] = records, %Context{} = context) when is_list(el) do
    records
    |> Enum.map(&to_schema(&1, context))
  end
  def to_schema(record, %Context{schema: schema, match_body: match_body, fields: fields, select: select}) do
    {_, fields} = record
    |> Enum.reduce({0, schema.__struct__}, &reduce_fields(&1, &2, match_body, fields))

    # fields = fields
    # |> Enum.map(&select_fields(&1, select))

    [fields]
  end

  defp reduce_fields(field_value, {field_index, struct}, match_body, fields) do
    field_name =  field_index |> get_field_name!(fields, match_body)
    struct = struct |> Map.put(field_name, field_value)
    {field_index + 1, struct}
  end

  def get_field_name!(fields, field_index) do
    field_name = Enum.find_value(fields, fn
      {field_name, {^field_index, _}} -> field_name

  defp get_field_name!(field_index, fields, match_body) do
    field_placeholder = match_body |> Enum.at(field_index)

    field_name = fields
    |> Query.condition_expression([], %{}) # Dump field name from expression
    |> Enum.find_value(fn
      {field_name, {_, ^field_placeholder}} -> field_name
      _ -> nil
    end)

    if field_name == nil do
      raise ArgumentError, "Can't find field with index #{inspect field_index} in schema fields"
    end

    field_name
  end
end
