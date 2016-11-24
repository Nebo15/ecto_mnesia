defmodule Ecto.Adapters.Mnesia do
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
    * `:disc_only_copies` - store data only on dics. This will limit database size to 2GB and affect adapter performance.

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
  require Logger
  alias :mnesia, as: Mnesia
  alias Ecto.Mnesia.{Record, Query, Table}
  alias Ecto.Mnesia.Record.{Context, Ordering, Update}

  @behaviour Ecto.Adapter

  @required_apps [:mnesia]

  @doc false
  defmacro __before_compile__(_env), do: :ok

  @doc """
  Ensure all applications necessary to run the adapter are started.
  """
  def ensure_all_started(_repo, type) do
    @required_apps
    |> Enum.each(fn app ->
      {:ok, _} = Application.ensure_all_started(app, type)
    end)

    {:ok, @required_apps}
  end

  @doc false
  # Returns the childspec that starts the adapter process.
  # This method is called from `Ecto.Repo.Supervisor.init/2`.
  def child_spec(_repo, _opts), do: Supervisor.Spec.supervisor(Supervisor, [[], [strategy: :one_for_one]])

  @doc false
  # Automatically generate next ID for binary keys, leave sequence keys empty for generation on insert.
  def autogenerate(:id), do: nil
  def autogenerate(:embed_id), do: Ecto.UUID.autogenerate()
  def autogenerate(:binary_id), do: Ecto.UUID.autogenerate()

  @doc false
  # Prepares are called by Ecto before `execute/6` methods.
  def prepare(operation, %Ecto.Query{from: {table, schema}, order_bys: order_bys, limit: limit} = query) do
    ordering_fn = order_bys |> Ordering.get_ordering_fn()
    context = table |> Context.new(schema)
    limit = limit |> get_limit()
    {:nocache, {operation, query, limit, context, ordering_fn}}
  end

  @doc false
  # Perform `mnesia:select` on prepared query and convert the results to Ecto Schema.
  def execute(_repo, %{sources: {{table, _schema}}, fields: _fields, take: _take},
                      {:nocache, {:all, %Ecto.Query{} = query, limit, context, ordering_fn}},
                      params, _preprocess, _opts) do
    {context, match_spec} = Query.match_spec(query, context, params)
    Logger.debug("Selecting by match specification `#{inspect match_spec}` with limit `#{inspect limit}`")

    result = table
    |> Table.select(match_spec, limit)
    |> Record.to_query_result(context)
    |> ordering_fn.()

    {length(result), result}
  end

  # Deletes all records that match Ecto.Query
  def execute(_repo, %{sources: {{table, _schema}}, fields: _fields, take: _take},
                      {:nocache, {:delete_all, %Ecto.Query{} = query, limit, context, ordering_fn}},
                      params, _preprocess, opts) do
    {context, match_spec} = Query.match_spec(query, context, params)
    Logger.debug("Deleting all records by match specification `#{inspect match_spec}` with limit `#{inspect limit}`")

    table = table |> Table.get_name()
    Table.transaction(fn ->
      table
      |> Table.select(match_spec, limit)
      |> Enum.map(fn record ->
        {:ok, _} = Table.delete(table, List.first(record))
        record
      end)
      |> return_all(context, ordering_fn, opts)
    end)
  end

  # Update all records
  def execute(_repo, %{sources: {{table, _schema}}, fields: _fields, take: _take},
                      {:nocache, {:update_all, %Ecto.Query{updates: updates} = query, limit, context, ordering_fn}},
                      params, _preprocess, opts) do
    {context, match_spec} = Query.match_spec(query, context, params)
    Logger.debug("Updating all records by match specification `#{inspect match_spec}` with limit `#{inspect limit}`")

    table = table |> Table.get_name()
    Table.transaction(fn ->
      table
      |> Table.select(match_spec, limit)
      |> Enum.map(fn record ->
        update = record
        |> Update.update_record(updates, params, context)
        |> List.insert_at(0, table)
        |> List.to_tuple()

        {:ok, result} = Table.update(table, List.first(record), update)
        result
      end)
      |> return_all(context, ordering_fn, opts)
    end)
  end

  # Constructs return for `*_all` methods.
  defp return_all(records, context, ordering_fn, opts) do
    case Keyword.get(opts, :returning) do
      true ->
        result = records
        |> Record.to_query_result(context)
        |> ordering_fn.()

        {length(result), result}
      _ ->
        {length(records), nil}
    end
  end

  @doc false
  # Insert Ecto Schema struct to Mnesia database.
  # TODO: deal with `opts`: `on_conflict` and `returning`
  def insert(_repo, %{autogenerate_id: autogenerate_id, schema: schema, source: {_, table}}, params,
             _on_conflict, _returning, _opts) do
    do_insert(table, schema, autogenerate_id, params)
  end

  @doc false
  # Insert all
  def insert_all(_repo, %{autogenerate_id: autogenerate_id, schema: schema, source: {_, table}},
                 _header, rows, _on_conflict, _returning, _opts) do
    table = table |> Table.get_name()
    count = Table.transaction(fn ->
      rows
      |> Enum.reduce(0, fn params, acc ->
        do_insert(table, schema, autogenerate_id, params)
        acc + 1
      end)
    end)

    {count, nil}
  end

  # Insert schema without primary keys
  defp do_insert(table, schema, nil, params) do
    record = schema |> Record.new(params, table)
    case Table.insert(table, record) do
      {:ok, ^record} ->
        {:ok, params}
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Insert schema with auto-generating primary key value
  # TODO: Check that PK is unique, don't override record
  defp do_insert(table, schema, {pk_field, _pk_type}, params) do
    params = params |> put_new_pk(pk_field, table)
    record = schema |> Record.new(params, table)
    case Table.insert(table, record) do
      {:ok, ^record} ->
        {:ok, params}
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Generate new sequenced primary key for table
  defp put_new_pk(params, pk_field, table) when is_list(params) and is_atom(pk_field) do
    {_, params} = params
    |> Keyword.get_and_update(pk_field, fn
      nil -> {nil, Table.next_id(table)}
      val -> {val, val}
    end)

    params
  end

  @doc false
  # Repo.stream is not supported
  def stream(_, _, _, _, _, _),
    do: raise ArgumentError, "stream/6 is not supported by adapter, use Ecto.Mnesia.Table.Stream.new/2 instead"

  @doc false
  # Run `fun` inside a Mnesia transaction
  def transaction(_repo, _opts, fun) do
    Table.transaction(fun)
  end

  @doc false
  # Returns true when called inside a transaction.
  def in_transaction?(_repo), do: Mnesia.is_transaction()

  @doc false
  # Transaction rollbacks is not supported
  def rollback(_repo, _tid), do: Mnesia.abort(:rollback)

  @doc false
  # Deletes a record from a Mnesia database.
  def delete(_repo, %{schema: _schema, source: {_, table}, autogenerate_id: autogenerate_id}, filter, _opts) do
    pk = get_pk!(filter, autogenerate_id)
    case Table.delete(table, pk) do
      {:ok, ^pk} -> {:ok, []}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc false
  # Updates record stored in a Mnesia database.
  def update(_repo, %{schema: schema, source: {_, table}, autogenerate_id: autogenerate_id},
             params, filter, _autogen, _opts) do
    pk = get_pk!(filter, autogenerate_id)

    record = schema
    |> Record.new(params, table)

    case table |> Table.update(pk, record) do
      {:ok, _record} -> {:ok, params}
      error -> error
    end
  end

  # Extract primary key value or raise an error
  defp get_pk!(params, {pk_field, _pk_type}), do: get_pk!(params, pk_field)
  defp get_pk!(params, pk_field) do
    case Keyword.fetch(params, pk_field) do
      :error -> raise Ecto.NoPrimaryKeyValueError
      {:ok, pk} -> pk
    end
  end

  @doc false
  # Required methods for Ecto type casing
  def loaders(:binary_id, type), do: [Ecto.UUID, type]
  def loaders(primitive, _type), do: [primitive]

  def dumpers(:binary_id, type), do: [type, Ecto.UUID]
  def dumpers(primitive, _type), do: [primitive]

  defp get_limit(nil), do: nil
  defp get_limit(%Ecto.Query.QueryExpr{expr: limit}), do: limit

  # Storage behaviour for migrations
  @behaviour Ecto.Adapter.Storage

  def supports_ddl_transaction?, do: false

  defdelegate storage_up(config), to: Ecto.Mnesia.Storage
  defdelegate storage_down(config), to: Ecto.Mnesia.Storage
  defdelegate execute_ddl(repo, ddl, opts), to: Ecto.Mnesia.Storage.Migrator, as: :execute

  # @behaviour Ecto.Adapter.Structure
end
