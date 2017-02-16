defmodule Ecto.Mnesia.Storage do
  @moduledoc """
  This module provides interface to manage Mnesia state and records data structure.
  """
  require Logger
  alias :mnesia, as: Mnesia

  @behaviour Ecto.Adapter.Storage

  @defaults [
    host: {:system, :atom, "MNESIA_HOST", Kernel.node()},
    storage_type: {:system, :atom, "MNESIA_STORAGE_TYPE", :disc_copies}
  ]

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

      storage_up(host: `Kernel.node`, storage_type: :disc_copies)
  """
  def storage_up(config) do
    config = conf(config)

    Logger.info "==> Setting Mnesia schema table copy type"
    Mnesia.change_table_copy_type(:schema, config[:host], config[:storage_type])

    Logger.info "==> Ensuring Mnesia schema exists"
    case Mnesia.create_schema([config[:host]]) do
      {:error, {_, {:already_exists, _}}} -> {:error, :already_up}
      {:error, reason} ->
          Logger.error "create_schema failed with reason #{inspect reason}"
          {:error, :unknown}
      :ok -> :ok
    end
  end

  @doc """
  Temporarily stops Mnesia, deletes schema and then brings it back up again.
  """
  def storage_down(config) do
    config = conf(config)
    stop()
    Mnesia.delete_schema([config[:host]])
    start()
  end

  def conf(config \\ []) do
    [
      host: config[:host] || @defaults[:host],
      storage_type: config[:storage_type] || @defaults[:storage_type]
    ]
    |> Confex.process_env()
  end
end
