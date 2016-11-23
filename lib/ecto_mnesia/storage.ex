defmodule Ecto.Mnesia.Storage do
  @moduledoc """
  This module provides interface to manage Mnesia state and records data structure.
  """
  require Logger
  alias :mnesia, as: Mnesia

  @behaviour Ecto.Adapter.Storage

  @doc """
  Start the Mnesia database.
  """
  def start, do: Mnesia.start

  @doc """
  Stop the Mnesia database.
  """
  def stop, do: Mnesia.stop

  @doc """
  Creates the storage given by options.

  Returns `:ok` if it was created successfully.
  Returns `{:error, :already_up}` if the storage has already been created or
  `{:error, term}` in case anything else goes wrong.

  Supported `copy_type` values: `:disc_copies`, `:ram_copies`, `:disc_only_copies`.

  ## Examples

      storage_up(host: `Kernel.node`,
                 copy_type: :,
                 hostname: 'localhost')
  """
  def storage_up(config) do
    config = conf(config)

    Mnesia.change_table_copy_type(:schema, config[:host], config[:mnesia_backend])
    case Mnesia.create_schema([config[:host]]) do
      {:error, {_, {:already_exists, _}}} -> :ok
      :ok -> :ok
    end

    # # TODO: Remove it from storage up to be used in Ecto Migrator
    # migrate_schemas(config[:host], config[:mnesia_backend], config[:mnesia_meta_schema])
  end

  def storage_down(config) do
    config = conf(config)
    stop()
    Mnesia.delete_schema([config[:host]])
    start()
  end

  @doc """
  Creates tables and indexes from a Ecto.Mnesia meta-schema.
  """
  def migrate_schemas(_host, _copy_type, []), do: :ok
  def migrate_schemas(host, copy_type, meta_schema) do
    Enum.map(meta_schema.meta, fn {table, fields} ->
      create_table(host, table, copy_type, fields)
      create_indexes(meta_schema, table)
    end)

    :ok
  end

  @doc """
  Creates a table.
  """
  def create_table(host, table, copy_type, fields) do
    Mnesia.create_table(table, [{:attributes, fields}, {copy_type, [host]}])
  end

  @doc """
  Creates table secondary indexes.
  """
  def create_indexes(meta_schema, table) do
    case List.keymember?(meta_schema.keys, table, 0) do
      false ->
        Mnesia.add_table_index(table, :id)
      true ->
        process_keys(meta_schema, table)
    end
  end

  defp process_keys(model, table) do
    case List.keyfind(model.keys, table, 0) do
      {table, key_fields} ->
        Enum.map(key_fields, &Mnesia.add_table_index(table, &1))
      _ ->
        :skip
    end
  end

  defp conf(config) do
    [
      host: config[:host] || Kernel.node,
      mnesia_backend: config[:mnesia_backend] || :disc_copies,
      mnesia_meta_schema: (if config[:mnesia_meta_schema], do: config[:mnesia_meta_schema], else: [])
    ]
  end
end
