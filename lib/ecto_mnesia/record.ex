defmodule Ecto.Mnesia.Record do
  @moduledoc """
  This module provides set of helpers for conversions between Mnesia records and Ecto Schemas.
  """
  alias Ecto.Mnesia.Record.Context
  alias Ecto.Mnesia.MatchSpec
  alias Ecto.Mnesia.Table

  @doc """
  Convert Ecto Schema struct to tuple that can be inserted to Mnesia.
  """
  def new(schema, params, table) do
    table = table |> Table.get_name()
    fields = schema.__schema__(:fields)
    nilled_tuple = List.to_tuple([table | List.duplicate(nil, length(fields))])
    params
    |> List.foldl(nilled_tuple, fn ({k, v}, acc) ->
      :erlang.setelement(:string.str(fields, [k]) + 1, acc, v)
    end)
  end

  @doc """
  Converts record or records list to result that is similar to `Ecto.Repo`.

  Raises if there is unknown field defined in record context.
  """
  def to_query_result([], _), do: []
  def to_query_result([el | _] = records, %Context{} = context) when is_list(el) do
    records
    |> Enum.map(&to_query_result(&1, context))
  end
  def to_query_result(record, %Context{table: %Context.Table{schema: schema},
                                       query: %Context.Query{select: select}} = context) do
    select
    |> get_result_type(schema)
    |> build_result(record, context)
  end

  defp get_result_type(%Ecto.Query.SelectExpr{expr: {:&, [], [0]}}, schema), do: schema.__struct__
  defp get_result_type(%Ecto.Query.SelectExpr{expr: _expr}, _schema), do: []
  defp get_result_type(list, _schema) when is_list(list), do: []

  defp build_result(acc, record, %Context{table: %Context.Table{structure: structure},
                                          match_spec: %Context.MatchSpec{body: match_body}}) when is_map(acc) do
    record
    |> Enum.reduce({0, acc}, &reduce_schema(&1, &2, match_body, structure))
    |> elem(1)
    |> List.wrap()
  end

  defp build_result([], record, %Context{query: %Context.Query{select: %Ecto.Query.SelectExpr{fields: select_fields},
                                                               sources: sources}}) do
    select_fields
    |> Enum.reduce({0, []}, &reduce_list(&1, &2, record, sources))
    |> elem(1)
    |> List.wrap()
  end

  defp reduce_schema(field_value, {field_index, struct}, match_body, fields) when is_map(struct) do
    field_name = field_index |> get_field_name!(fields, match_body)
    struct = struct |> Map.put(field_name, field_value)
    {field_index + 1, struct}
  end

  defp reduce_list({{:., [], [{:&, [], [0]}, _field_name]}, _, []}, {field_index, acc}, record, _sources)
    when is_list(acc) do
    field_value = record |> Enum.at(field_index)
    {field_index + 1, acc ++ [field_value]}
  end

  defp reduce_list({:^, _, _} = source, {field_index, acc}, _record, sources) do
    field_value = source |> MatchSpec.unbind(sources)
    {field_index + 1, acc ++ [field_value]}
  end

  defp get_field_name!(field_index, fields, match_body) do
    field_placeholder = match_body |> Enum.at(field_index)

    field_name = fields
    |> MatchSpec.condition_expression([], %{}) # Dump field name from expression
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
