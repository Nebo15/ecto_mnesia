defmodule EctoMnesia.Record.Context do
  @moduledoc """
  Context stores `table`, `query` and `match_spec` that can be used for conversions between schemas and Mnesia records.
  """
  alias EctoMnesia.Table
  alias EctoMnesia.Record.Context

  defstruct table: %Context.Table{}, query: %Context.Query{}, match_spec: %Context.MatchSpec{}

  @doc """
  Creates new context table, and stores schema meta information that can be used to reconstruct query result.
  """
  def new(table, schema) when is_atom(table),
    do: table |> Atom.to_string() |> new(schema)
  def new(table, schema) when is_binary(table) and is_atom(schema) do
    table_name = Table.get_name(table)
    mnesia_attributes =
      case Table.attributes(table_name) do
        {:ok, name} -> name
        {:error, :no_exists} -> []
      end

    structure =
      Enum.map(1..length(mnesia_attributes), fn index ->
        {Enum.at(mnesia_attributes, index - 1), {index - 1, String.to_atom("$#{index}")}}
      end)

    %Context{
      table: %Context.Table{schema: schema, name: table_name, structure: structure},
      query: %Context.Query{select: mnesia_attributes}
    }
  end

  @doc """
  Assigns `Ecto.Query` to a context and rebuilds MatchSpec with updated data.
  """
  def assign_query(_conext, %Ecto.SubQuery{}, _sources),
    do: raise Ecto.Query.CompileError, "`Ecto.Query.subquery/1` is not supported by Mnesia adapter."
  def assign_query(_context, %Ecto.Query{havings: havings}, _sources) when is_list(havings) and length(havings) > 0,
    do: raise Ecto.Query.CompileError, "`Ecto.Query.having/3` is not supported by Mnesia adapter."
  def assign_query(context, %Ecto.Query{} = query, sources) do
    context
    |> update_query_select(query)
    |> update_query_sources(sources)
    |> build_match_spec(query)
  end

  # Stores `Ecto.Query.select` value into `context.select` field.
  defp update_query_select(context, nil),
    do: context
  defp update_query_select(context, %Ecto.Query{select: select}),
    do: update_query_select(context, select)
  defp update_query_select(context, select),
    do: %{context | query: %{context.query | select: select}}

  # Stores query sources `context.sources` field.
  defp update_query_sources(context, sources),
    do: %{context | query: %{context.query | sources: sources}}

  @doc """
  Returns match spec that can be used in `:mnesia.select/3`.
  """
  def get_match_spec(%Context{match_spec: %Context.MatchSpec{} = match_spec}),
    do: Context.MatchSpec.dump(match_spec)

  # Builds new match_spec on query updates
  defp build_match_spec(context, query),
    do: Context.MatchSpec.update(context, query)

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
  def find_field_placeholder!(field, %Context{table: %Context.Table{structure: structure, name: name}})
    when is_atom(field) do
    case Keyword.get(structure, field) do
      nil -> raise ArgumentError, "Field `#{inspect field}` does not exist in table `#{inspect name}`"
      {_index, placeholder} -> placeholder
    end
  end
  def find_field_placeholder!(field, %Context{}), do: field

  @doc """
  Returns MatchSpec body placeholders for all fields in a context.
  """
  def get_fields_placeholders(%Context{table: %Context.Table{structure: structure}}) do
    Enum.map(structure, fn {_name, {_index, placeholder}} -> placeholder end)
  end
end
