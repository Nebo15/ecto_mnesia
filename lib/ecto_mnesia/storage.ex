defmodule EctoMnesia.Storage do
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
  def start do
    check_mnesia_dir()
    Mnesia.start()
  end
  @doc """
  Stop the Mnesia database.
  """
  def stop do
    check_mnesia_dir()
    Mnesia.stop
  end

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
    check_mnesia_dir()
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
    check_mnesia_dir()
    config = conf(config)
    stop()
    Mnesia.delete_schema([config[:host]])
    start()
  end

  def conf(config \\ []) do
    Confex.process_env([
      host: config[:host] || @defaults[:host],
      storage_type: config[:storage_type] || @defaults[:storage_type]
    ])
  end

  @doc """
  Checks that the Application environment for `mnesia_dir` is of
  a correct type.
  """
  def check_mnesia_dir do
    dir = Application.get_env(:mnesia, :dir, nil)
    case dir do
      nil ->
        Logger.warn "Mnesia dir is not set. Mnesia use default path."
      dir when is_binary(dir) ->
        Logger.error "Mnesia dir is a binary. Mnesia requires a charlist, which is set with simple quotes ('')"
      dir when is_list(dir) ->
        :ok
      _dir ->
        Logger.error "Mnesia dir is not character list. Mnesia will not work. "
    end
  end
end
