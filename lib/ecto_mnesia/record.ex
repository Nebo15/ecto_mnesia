defmodule EctoMnesia.Record do
  @moduledoc """
  This module provides set of helpers for conversions between Mnesia records and Ecto Schemas.
  """
  alias EctoMnesia.Record.Context

  @doc """
  Convert Ecto Schema struct to tuple that can be inserted to Mnesia.
  """
  def new(schema, table, params) do
    table
    |> Context.new(schema)
    |> new(params)
  end
  def new(%Context{table: %Context.Table{name: table, structure: structure}} = context, params) do
    nilled_record = [table | List.duplicate(nil, length(structure))]

    params
    |> List.foldl(nilled_record, fn {field, value}, acc ->
      List.replace_at(acc, Context.find_field_index!(field, context) + 1, value)
    end)
    |> List.to_tuple()
  end
end
