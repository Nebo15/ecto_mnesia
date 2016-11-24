defmodule Ecto.Mnesia.Record.Context do
  @moduledoc """
  Context is used by many modules to construct queries and reconstruct structs on query return.
  """
  alias Ecto.Mnesia.Table
  alias Ecto.Mnesia.Record.Context

  defstruct schema: nil, table: nil, fields: [], select: [], match_body: nil, bindings: []

  @doc """
  Creates new context table, and stores schema meta information that can be used to reconstruct query result.
  """
  def new(table, schema) when is_binary(table) and is_atom(schema) do
    table = table |> Table.get_name()
    mnesia_attributes = try do
      table |> Table.attributes()
    catch
      :exit, {:aborted, {:no_exists, _, :attributes}} -> []
    end

    fields = 1..length(mnesia_attributes)
    |> Enum.map(fn index ->
      {Enum.at(mnesia_attributes, index - 1), {index - 1, String.to_atom("$#{index}")}}
    end)

    %Context{schema: schema, table: table, fields: fields, select: mnesia_attributes, match_body: nil}
  end

  @doc """
  Stores `Ecto.Query.select` value into `context.select` field.
  """
  def update_select(context, nil), do: context
  def update_select(context, %Ecto.Query{select: select}), do: update_select(context, select)
  def update_select(context, select), do: %{context | select: select}

  @doc """
  Stores MatchSpec query body into `context.match_body` field.
  """
  def update_match_body(context, match_body), do: %{context | match_body: match_body}

  @doc """
  Stores query bindings `context.bindings` field.
  """
  def update_bindings(context, bindings), do: %{context | bindings: bindings}

  def find_index!(field, %Context{fields: fields, table: table}) when is_atom(field) do
    case Keyword.get(fields, field) do
      nil -> raise ArgumentError, "Field `#{inspect field}` does not exist in table `#{inspect table}`"
      {index, _placeholder} -> index
    end
  end

  @doc """
  Returns a Mnesia MatchSpec body placeholder for a field.

  Raises if field does not exist in context or Mnesia table.
  """
  def find_placeholder!({{:., [], [{:&, [], [0]}, field]}, _, []}, %Context{} = context) when is_atom(field),
    do: field |> find_placeholder!(context)
  def find_placeholder!(field, %Context{fields: fields, table: table}) when is_atom(field) do
    case Keyword.get(fields, field) do
      nil -> raise ArgumentError, "Field `#{inspect field}` does not exist in table `#{inspect table}`"
      {_index, placeholder} -> placeholder
    end
  end
  def find_placeholder!(field, %Context{}), do: field

  @doc """
  Returns placeholders for all schema fields defined in a context.
  """
  def get_placeholders(%Context{fields: fields}) do
    fields
    |> Enum.map(fn {_name, {_index, placeholder}} -> placeholder end)
  end
end
