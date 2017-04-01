defmodule EctoMnesia.Storage.Migrator do
  @moduledoc """
  This module implements `Ecto.Storage` behavior that is used by `Ecto.Migrations`.
  """
  alias EctoMnesia.Table
  alias :mnesia, as: Mnesia

  @pk_table_name :id_seq

  @doc false
  # Tables
  def execute(repo, {:create, %Ecto.Migration.Table{name: table, engine: type}, instructions}, _opts) do
    ensure_pk_table!(repo)

    table_attrs =
      instructions
      |> Enum.reduce([], &reduce_fields(&1, &2, [], :skip))
      |> Enum.uniq()

    case do_create_table(repo, table, type, table_attrs) do
      :ok -> :ok
      :already_exists -> raise "Table #{table} already exists"
    end
  end

  def execute(repo, {:create_if_not_exists, %Ecto.Migration.Table{name: table, engine: type}, instructions}, _opts) do
    ensure_pk_table!(repo)

    table_attrs =
      try do
        table
        |> Table.get_name()
        |> Mnesia.table_info(:attributes)
      catch
        :exit, {:aborted, _reason} -> []
      end

    new_table_attrs =
      instructions
      |> Enum.reduce(table_attrs, &reduce_fields(&1, &2, [], :skip))
      |> Enum.uniq()

    case do_create_table(repo, table, type, new_table_attrs) do
      :ok -> :ok
      :already_exists -> :ok
    end
  end

  def execute(repo, {:alter, %Ecto.Migration.Table{name: table}, instructions}, _opts) do
    ensure_pk_table!(repo)

    table_attrs =
      try do
        table
        |> Table.get_name()
        |> Mnesia.table_info(:attributes)
      catch
        :exit, {:aborted, _reason} -> []
      end

    new_table_attrs =
      instructions
      |> Enum.reduce(table_attrs, &reduce_fields(&1, &2, table_attrs, :raise))
      |> Enum.uniq()

    try do
      case Mnesia.transform_table(table, &alter_fn(&1, table_attrs, new_table_attrs), new_table_attrs) do
        {:atomic, :ok} -> :ok
        error -> error
      end
    catch
      :exit, {:aborted, {:no_exists, {_, :record_name}}} -> raise "Table #{table} does not exists"
    end
  end

  def execute(repo, {:rename, %Ecto.Migration.Table{name: table}, old_field, new_field}, _opts) do
    ensure_pk_table!(repo)

    table_attrs =
      try do
        table
        |> Table.get_name()
        |> Mnesia.table_info(:attributes)
      catch
        :exit, {:aborted, _reason} -> []
      end

    new_table_attrs =
      [{:rename, old_field, new_field}]
      |> Enum.reduce(table_attrs, &reduce_fields(&1, &2, table_attrs, :raise))
      |> Enum.uniq()

    renames = [{old_field, new_field}]

    try do
      case Mnesia.transform_table(table, &alter_fn(&1, table_attrs, new_table_attrs, renames), new_table_attrs) do
        {:atomic, :ok} -> :ok
        error -> error
      end
    catch
      :exit, {:aborted, {:no_exists, {_, :record_name}}} -> raise "Table #{table} does not exists"
    end
  end

  def execute(_repo, {:drop, %Ecto.Migration.Table{name: table}}, _opts) do
    case Mnesia.delete_table(table) do
      {:atomic, :ok} -> :ok
      {:aborted, {:no_exists, _}} -> raise "Table #{table} does not exists"
    end
  end

  def execute(_repo, {:drop_if_exists, %Ecto.Migration.Table{name: table}}, _opts) do
    case Mnesia.delete_table(table) do
      {:atomic, :ok} -> :ok
      {:aborted, {:no_exists, _}} -> :ok
    end
  end

  # Indexes
  def execute(_repo, {:create, %Ecto.Migration.Index{table: table, columns: columns}}, _opts) do
    columns
    |> Enum.uniq()
    |> Enum.map(fn index ->
      case Mnesia.add_table_index(table, index) do
        {:atomic, :ok} -> :ok
        {:node_not_running, not_found_node} -> raise "Node #{inspect not_found_node} is not started"
        {:aborted, {:already_exists, ^table, _}} -> raise "Index for field #{index} in table #{table} already exists"
      end
    end)
  end

  def execute(_repo, {:create_if_not_exists, %Ecto.Migration.Index{table: table, columns: columns}}, _opts) do
    columns
    |> Enum.uniq()
    |> Enum.map(fn index ->
      case Mnesia.add_table_index(table, index) do
        {:atomic, :ok} -> :ok
        {:node_not_running, not_found_node} -> raise "Node #{inspect not_found_node} is not started"
        {:aborted, {:already_exists, ^table, _}} -> :ok
      end
    end)
  end

  def execute(_repo, {:drop, %Ecto.Migration.Index{table: table, columns: columns}}, _opts) do
    columns
    |> Enum.uniq()
    |> Enum.map(fn index ->
      case Mnesia.del_table_index(table, index) do
        {:atomic, :ok} -> :ok
        {:node_not_running, not_found_node} -> raise "Node #{inspect not_found_node} is not started"
        {:aborted, {:no_exists, ^table, _}} -> raise "Index for field #{index} in table #{table} does not exists"
      end
    end)
  end

  def execute(_repo, {:drop_if_exists, %Ecto.Migration.Index{table: table, columns: columns}}, _opts) do
    columns
    |> Enum.uniq()
    |> Enum.map(fn index ->
      case Mnesia.del_table_index(table, index) do
        {:atomic, :ok} -> :ok
        {:node_not_running, not_found_node} -> raise "Node #{inspect not_found_node} is not started"
        {:aborted, {:no_exists, ^table, _}} -> :ok
      end
    end)
  end

  # Helpers
  defp do_create_table(repo, table, type, attributes) do
    config = conf(repo)
    tab_def = [{:attributes, attributes}, {config[:storage_type], [config[:host]]}, {:type, get_engine(type)}]
    case Mnesia.create_table(table, tab_def) do
      {:atomic, :ok} ->
        Mnesia.wait_for_tables([table], 1_000)
        :ok
      {:aborted, {:already_exists, ^table}} ->
        :already_exists
    end
  end

  defp get_engine(nil), do: :ordered_set
  defp get_engine(type) when is_atom(type), do: type

  defp reduce_fields({:remove, field}, fields, table_fields, on_not_found) do
    if on_not_found == :raise and !field_exists?(table_fields, field) do
      raise "Field #{field} not found"
    end

    Enum.filter(fields, &(&1 != field))
  end

  defp reduce_fields({:rename, old_field, new_field}, fields, table_fields, on_not_found) do
    if on_not_found == :raise and !field_exists?(table_fields, old_field) do
      raise "Field #{old_field} not found"
    end

    case Enum.find_index(fields, &(&1 == old_field)) do
      nil ->
        if on_not_found == :raise, do: raise "Field #{old_field} not found", else: fields
      index when is_number(index) ->
        List.replace_at(fields, index, new_field)
    end
  end

  defp reduce_fields({:add, field, _type, _opts}, fields, _table_fields, on_duplicate) do
    if on_duplicate == :raise and field_exists?(fields, field) do
      raise "Duplicate field #{field}"
    end

    fields ++ [field]
  end

  defp reduce_fields({:modify, field, _type, _opts}, fields, table_fields, on_not_found) do
    if on_not_found == :raise and !field_exists?(table_fields ++ fields, field) do
      raise "Field #{field} not found"
    end

    fields
  end

  defp field_exists?(table_fields, field), do: field in table_fields

  # Altering function traverses Mnesia table on schema migrations and moves field values to persist them
  defp alter_fn(record, fields_before, fields_after, data_migrations \\ []) do
    record_name = elem(record, 0)
    acc = Enum.map(1..length(fields_after), fn _ -> nil end)

    fields_after
    |> Enum.reduce(acc, fn field, acc ->
      old_index = find_field_index(fields_before, field, data_migrations)
      new_index = find_field_index(fields_after, field)

      value =
        case old_index do
          nil -> nil
          index -> elem(record, index + 1)
        end

      List.replace_at(acc, new_index, value)
    end)
    |> List.insert_at(0, record_name)
    |> List.to_tuple()
  end

  def find_field_index(fields, field),
    do: Enum.find_index(fields, &(&1 == field))
  def find_field_index(fields, field, data_migrations) do
    case Enum.find(data_migrations, fn {_old_name, new_name} -> new_name == field end) do
      {old_field, _new_field} ->
        find_field_index(fields, old_field)
      nil ->
        find_field_index(fields, field)
    end
  end

  defp ensure_pk_table!(repo) do
    res =
      try do
        Mnesia.table_info(:size, @pk_table_name)
      catch
        :exit, {:aborted, {:no_exists, :size, _}} -> :no_exists
      end

    case res do
      :no_exists ->
        do_create_table(repo, @pk_table_name, :set, [:thing, :id])
      _ ->
        Mnesia.wait_for_tables([@pk_table_name], 1_000)
        :ok
    end
  end

  defp conf(repo),
    do: EctoMnesia.Storage.conf(repo.config)
end
