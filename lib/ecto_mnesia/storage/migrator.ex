defmodule Ecto.Mnesia.Storage.Migrator do
  alias Ecto.Mnesia.Table
  alias :mnesia, as: Mnesia

  # TODO: Support all commands
  # @type command ::
  #   raw :: String.t |
  #   {:create, Table.t, [table_subcommand]} |
  #   {:create_if_not_exists, Table.t, [table_subcommand]} |
  #   {:alter, Table.t, [table_subcommand]} |
  #   {:drop, Table.t} |
  #   {:drop_if_exists, Table.t} |
  #   {:create, Index.t} |
  #   {:create_if_not_exists, Index.t} |
  #   {:drop, Index.t} |
  #   {:drop_if_exists, Index.t}

  # @typedoc "All commands allowed within the block passed to `table/2`"
  # @type table_subcommand ::
  #   {:add, field :: atom, type :: Ecto.Type.t | Reference.t, Keyword.t} |
  #   {:modify, field :: atom, type :: Ecto.Type.t | Reference.t, Keyword.t} |
  #   {:remove, field :: atom}


  @pk_table_name :id_seq

  # Tables
  def execute(_repo, {:create, %Ecto.Migration.Table{name: table}, instructions}, _opts) do
    enshure_pk_table!()

    new_attrs = instructions
    |> Enum.reduce([], &reduce_fields/2)
    |> Enum.uniq()

    case do_create_table(table, new_attrs) do
      :ok -> :ok
      :already_exists -> raise "Table #{table} already exists"
    end
  end

  def execute(_repo, {:create_if_not_exists, %Ecto.Migration.Table{name: table}, instructions}, _opts) do
    enshure_pk_table!()

    table_attrs = try do
      table |> Table.get_name() |> Mnesia.table_info(:attributes)
    catch
      :exit, {:aborted, _reason} -> []
    end

    new_attrs = instructions
    |> Enum.reduce(table_attrs, &reduce_fields/2)
    |> Enum.uniq()

    case do_create_table(table, new_attrs) do
      :ok -> :ok
      :already_exists -> :ok
    end
  end

  def execute(_repo, {:alter, %Ecto.Migration.Table{name: table}, instructions}, _opts) do
    enshure_pk_table!()

    table_attrs = try do
      table |> Table.get_name() |> Mnesia.table_info(:attributes)
    catch
      :exit, {:aborted, _reason} -> []
    end

    new_attrs = instructions
    |> Enum.reduce(table_attrs, &reduce_fields/2)
    |> Enum.uniq()

    case Mnesia.transform_table(table, &alter_fn(&1, table_attrs, new_attrs), new_attrs) do
      {:atomic, :ok} -> :ok
      {:aborted, {:already_exists, ^table}} -> :ok
    end
  end

  # Indexes
  def execute(_repo, {:create, %Ecto.Migration.Index{table: table, columns: columns}}, _opts) do
    columns
    |> Enum.uniq()
    |> Enum.map(fn index ->
      case Mnesia.add_table_index(table, index) do
        {:atomic, :ok} -> :ok
        {:node_not_running, node} -> raise "Node #{inspect node} is not started"
        {:aborted, {:already_exists, ^table, ^index}} -> raise "Table #{table} index #{index} already exists"
      end
    end)
  end

  defp do_create_table(table, attributes) do
    case Mnesia.create_table(table, [attributes: attributes, disc_copies: [Kernel.node()]]) do
      {:atomic, :ok} ->
        Mnesia.wait_for_tables([table], 1_000)
        :ok
      {:aborted, {:already_exists, ^table}} -> :already_exists
    end
  end

  defp reduce_fields({:add, field, _type, _opts}, fields) do
    fields ++ [field]
  end

  defp reduce_fields({:drop, field, _type, _opts}, fields) do
    fields
    |> Enum.filter(&(&1 != field))
  end

  defp reduce_fields({:remove, field}, fields) do
    fields
    |> Enum.filter(&(&1 != field))
  end

  defp alter_fn(record, fields_before, fields_after) do
    record
  end

  defp enshure_pk_table! do
    res = try do
      Mnesia.table_info(:size, @pk_table_name)
    catch
      :exit, {:aborted, {:no_exists, :size, _}} -> :no_exists
    end

    case res do
      :no_exists ->
        do_create_table(@pk_table_name, [:thing, :id])
      _ ->
        Mnesia.wait_for_tables([@pk_table_name], 1_000)
        :ok
    end
  end
end
