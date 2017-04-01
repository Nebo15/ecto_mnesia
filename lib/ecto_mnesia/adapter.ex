defmodule EctoMnesia.Adapter do
  @moduledoc """
  Ecto 2.X adapter for Mnesia Erlang term database.

  ## Run-Time Storage Options

    * `:host` - Node hostname.
    * `:dir` - Path where Mnesia should store DB data.
    * `:storage_type` - Type of Mnesia storage.

  ### Mnesia Storage Types

    * `:disc_copies` - store data in both RAM and on dics. Recommended value for most cases.
    * `:ram_copies` - store data only in RAM. Data will be lost on node restart.
    Useful when working with large datasets that don't need to be persisted.
    * `:disc_only_copies` - store data only on dics. This will limit database size to 2GB and affect
    adapter performance.

  ## Limitations

  There are some limitations when using Ecto with MySQL that one
  needs to be aware of.

  ### Transactions

  Right now all transactions will be run in dirty context.

  ### UUIDs

  Mnesia does not support UUID types. Ecto emulates them by using `binary(16)`.

  ### DDL Transaction

  Mnesia migrations are DDL's by their nature, so Ecto does not have control over it
  and behavior may be different from other adapters.

  ### Types

  Mnesia doesn't care about types, so all data will be stored as-is.
  """
  # Adapter behavior
  @behaviour Ecto.Adapter
  @adapter_implementation EctoMnesia.Planner

  @doc false
  defmacro __before_compile__(_env), do: :ok

  @doc false
  defdelegate ensure_all_started(repo, type), to: @adapter_implementation
  @doc false
  defdelegate child_spec(repo, opts), to: @adapter_implementation

  @doc false
  defdelegate prepare(operation, query), to: @adapter_implementation
  @doc false
  defdelegate execute(repo, query_meta, query_cache, sources, preprocess, opts), to: @adapter_implementation
  @doc false
  defdelegate insert(repo, query_meta, sources, on_conflict, returning, opts), to: @adapter_implementation
  @doc false
  defdelegate insert_all(repo, query_meta, header, rows, on_conflict, returning, opts), to: @adapter_implementation
  @doc false
  defdelegate update(repo, query_meta, params, filter, autogen, opts), to: @adapter_implementation
  @doc false
  defdelegate delete(repo, query_meta, filter, opts), to: @adapter_implementation
  @doc false
  def stream(_, _, _, _, _, _),
    do: raise ArgumentError, "stream/6 is not supported by adapter, use EctoMnesia.Table.Stream.new/2 instead"

  @doc false
  defdelegate transaction(repo, opts, fun), to: @adapter_implementation
  @doc false
  defdelegate in_transaction?(repo), to: @adapter_implementation
  @doc false
  defdelegate rollback(repo, tid), to: @adapter_implementation

  @doc false
  defdelegate autogenerate(type), to: @adapter_implementation
  @doc false
  defdelegate loaders(primitive, type), to: @adapter_implementation
  @doc false
  defdelegate dumpers(primitive, type), to: @adapter_implementation

  # Storage behaviour for migrations
  @behaviour Ecto.Adapter.Storage
  @storage_implementation EctoMnesia.Storage
  @migrator_implementation EctoMnesia.Storage.Migrator

  @doc false
  defdelegate storage_up(config), to: @storage_implementation
  @doc false
  defdelegate storage_down(config), to: @storage_implementation
  @doc false
  defdelegate execute_ddl(repo, ddl, opts), to: @migrator_implementation, as: :execute
  @doc false
  def supports_ddl_transaction?, do: false
end
