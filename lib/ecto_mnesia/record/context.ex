defmodule Ecto.Mnesia.Record.Context do
  @moduledoc """
  Context stores `table`, `query` and `match_spec` that can be used for conversions between schemas and Mnesia records.
  """
  alias Ecto.Mnesia.Table
  alias Ecto.Mnesia.Record.Context

  defstruct table: %Context.Table{}, query: %Context.Query{}, match_spec: %Context.MatchSpec{}

  @doc """
  Creates new context table, and stores schema meta information that can be used to reconstruct query result.
  """
  def new(table, schema) when is_binary(table) and is_atom(schema) do
    table_name = table |> Table.get_name()
    mnesia_attributes = case table_name |> Table.attributes() do
      {:ok, name} -> name
      {:error, :no_exists} -> []
    end

    structure = 1..length(mnesia_attributes)
    |> Enum.map(fn index ->
      {Enum.at(mnesia_attributes, index - 1), {index - 1, String.to_atom("$#{index}")}}
    end)

    %Context{
      table: %Context.Table{schema: schema, name: table_name, structure: structure},
      query: %Context.Query{select: mnesia_attributes}
    }
  end

  @doc """
  Stores `Ecto.Query.select` value into `context.select` field.
  """
  def update_query_select(context, nil),
    do: context
  def update_query_select(context, %Ecto.Query{select: select}),
    do: update_query_select(context, select)
  def update_query_select(context, select),
    do: %{context | query: %{context.query | select: select}}

  @doc """
  Stores MatchSpec query body into `context.match_body` field.
  """
  def update_match_spec_body(context, match_body),
    do: %{context | match_spec: %{context.match_spec | body: match_body}}

  @doc """
  Stores query sources `context.sources` field.
  """
  def update_query_sources(context, sources),
    do: %{context | query: %{context.query | sources: sources}}

  @doc """
  Returns match spec that can be used in `:mnesia.select/3`.
  """
  def get_match_spec(%Context{match_spec: %Context.MatchSpec{} = match_spec}),
    do: match_spec.dump()

  @doc """
  Returns MatchSpec record field index by a `field` name.

  Raises if field is not found in a context.
  """
  def find_field_index!(field, %Context{table: %Context.Table{structure: structure, name: name}})
    when is_atom(field) do
    case Keyword.get(structure, field) do
      nil -> raise ArgumentError, "Field `#{inspect field}` does not exist in table `#{inspect name}`"
      {index, _placeholder} -> index
    end
  end

  @doc """
  Returns a Mnesia MatchSpec body placeholder for a field.

  Raises if field is not found in a context.
  """
  def find_field_placeholder!({{:., [], [{:&, [], [0]}, field]}, _, []}, %Context{} = context) when is_atom(field),
    do: field |> find_field_placeholder!(context)
  def find_field_placeholder!(field, %Context{table: %Context.Table{structure: structure, name: name}})
    when is_atom(field) do
    case Keyword.get(structure, field) do
      nil -> raise ArgumentError, "Field `#{inspect field}` does not exist in table `#{inspect name}`"
      {_index, placeholder} -> placeholder
    end
  end
  def find_field_placeholder!(field, %Context{}), do: field # TODO: remove this line

  @doc """
  Returns MatchSpec body placeholders for all fields in a context.
  """
  def get_fields_placeholders(%Context{table: %Context.Table{structure: structure}}) do
    structure
    |> Enum.map(fn {_name, {_index, placeholder}} -> placeholder end)
  end
end
