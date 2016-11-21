defmodule Ecto.Mnesia.Query.Context do
  @moduledoc """
  Context for operations with a database.
  """
  alias Ecto.Mnesia.Table
  alias Ecto.Mnesia.Query.Context

  defstruct schema: nil, table: nil, fields: [], select: []

  def new(table, schema) when is_binary(table) and is_atom(schema) do
    table = table |> Table.get_name()
    mnesia_attributes = table |> Table.attributes()

    fields = 1..length(mnesia_attributes)
    |> Enum.map(fn index ->
      {Enum.at(mnesia_attributes, index - 1), {index - 1, String.to_atom("$#{index}")}}
    end)

    %Context{schema: schema, table: table, fields: fields, select: mnesia_attributes}
  end

  @doc """
  Update selects with a `Ecto.Query.fields` struct.
  """
  def update_selects(context, nil), do: context
  def update_selects(context, %Ecto.Query.SelectExpr{fields: selects}), do: update_selects(context, selects)
  def update_selects(context, [{:&, [], [0, selects, _selects_count]}]), do: %{context | select: selects}
  def update_selects(context, selects), do: %{context | select: selects}

  def find_index!(field, %Context{fields: fields, table: table}) when is_atom(field) do
    case Keyword.get(fields, field) do
      nil -> raise ArgumentError, "Field `#{inspect field}` does not exist in table `#{inspect table}`"
      {index, _placeholder} -> index
    end
  end

  def find_placeholder!(field, %Context{fields: fields, table: table}) when is_atom(field) do
    case Keyword.get(fields, field) do
      nil -> raise ArgumentError, "Field `#{inspect field}` does not exist in table `#{inspect table}`"
      {_index, placeholder} -> placeholder
    end
  end

  def get_placeholders(%Context{fields: fields}) do
    fields
    |> Enum.map(fn {_name, {_index, placeholder}} -> placeholder end)
  end
end
