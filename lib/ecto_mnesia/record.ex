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

  def to_query_result([], _), do: []
  def to_query_result([el | _] = records, %Context{} = context) when is_list(el) do
    records
    |> Enum.map(&to_query_result(&1, context))
  end
  def to_query_result(record, %Context{schema: schema, select: select} = context) do
    select
    |> result_type(schema)
    |> do_transform(record, context)
  end

  defp result_type(%Ecto.Query.SelectExpr{expr: {:&, [], [0]}}, schema), do: schema.__struct__
  defp result_type(%Ecto.Query.SelectExpr{expr: _expr}, _schema), do: []
  defp result_type(list, _schema) when is_list(list), do: []

  defp do_transform(acc, record, %Context{match_body: match_body, fields: fields}) when is_map(acc) do
    record
    |> Enum.reduce({0, acc}, &reduce_schema(&1, &2, match_body, fields))
    |> elem(1)
    |> List.wrap()
  end

  defp do_transform([], record, %Context{select: %{fields: select_fields}, bindings: bindings}) do
    select_fields
    |> Enum.reduce({0, []}, &reduce_list(&1, &2, record, bindings))
    |> elem(1)
    |> List.wrap()
  end

  defp reduce_schema(field_value, {field_index, struct}, match_body, fields) when is_map(struct) do
    field_name = field_index |> get_field_name!(fields, match_body)
    struct = struct |> Map.put(field_name, field_value)
    {field_index + 1, struct}
  end

  defp reduce_list({{:., [], [{:&, [], [0]}, _field_name]}, _, []}, {field_index, acc}, record, _bindings)
    when is_list(acc) do
    field_value = record |> Enum.at(field_index)
    {field_index + 1, acc ++ [field_value]}
  end

  defp reduce_list({:^, _, _} = binding, {field_index, acc}, _record, bindings) do
    field_value = binding |> Query.unbind(bindings)
    {field_index + 1, acc ++ [field_value]}
  end

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
