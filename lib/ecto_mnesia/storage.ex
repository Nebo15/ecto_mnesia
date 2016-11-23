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

  # TODO: Support ram-only storage creation and migrations

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
  end

  def storage_down(config) do
    config = conf(config)
    stop()
    Mnesia.delete_schema([config[:host]])
    start()
  end

  defp conf(config) do
    [
      host: config[:host] || Kernel.node,
      mnesia_backend: config[:mnesia_backend] || :disc_copies,
      mnesia_meta_schema: (if config[:mnesia_meta_schema], do: config[:mnesia_meta_schema], else: [])
    ]
  end
end
