defmodule Ecto.Mnesia.Record do
  @moduledoc """
  This module provides set of helpers for conversions between Mnesia records and Ecto Schemas.
  """
  alias Ecto.Mnesia.Record.Context

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
  def to_schema(record, %Context{schema: schema, fields: fields}) do
    {_, schema} = record
    |> Enum.reduce({0, schema.__struct__}, &reduce_fields(&1, &2, fields))

    [schema]
  end

  def reduce_fields(nil, {field_index, struct}, _fields), do: {field_index + 1, struct}
  def reduce_fields(field_value, {field_index, struct}, fields) do
    field_name = get_field_name!(fields, field_index)
    struct = struct |> Map.put(field_name, field_value)
    {field_index + 1, struct}
  end

  def get_field_name!(fields, field_index) do
    field_name = Enum.find_value(fields, fn
      {field_name, {^field_index, _}} -> field_name
      _ -> nil
    end)

    if field_name == nil do
      raise ArgumentError, "Can't find field with index #{inspect field_index} in schema fields"
    end

    field_name
  end
end
