defmodule Ecto.Mnesia.Adapter do
  @moduledoc """
  Ecto.Adapter for `mnesia` Erlang term database.

  It supports compound `mnesia` indexes (aka secondary indexes) in database setup.
  The implementation relies directly on `mnesia` application.
  Supports partial Ecto.Query to MatchSpec conversion for `mnesia:select` (and, join).
  MatchSpec converion utilities could be found in `Ecto.Mnesia.Query`.

  ## Configuration Sample

      defmodule Sample.Model do
        require Record

        def keys, do: [id_seq:       [:thing],
                       topics:       [:whom,:who,:what],
                       config:       [:key]]

        def meta, do: [id_seq:       [:thing, :id],
                       config:       [:key, :value],
                       topics:       Model.Topics.__schema__(:fields)]
      end

  where `Model.Topics` is `Ecto.Schema` object.

  ## usage in `config.exs`

      config :ecto, :mnesia_meta_schema, Sample.Model
      config :ecto, :mnesia_backend,  :ram_copies
  """
  require Logger
  alias :mnesia, as: Mnesia
  alias Ecto.Mnesia.{Record, Ordering, Query, Table}
  alias Ecto.Mnesia.Query.Context

  @behaviour Ecto.Adapter

  @required_apps [:mnesia]

  @doc false
  defmacro __before_compile__(_env), do: :ok

  @doc """
  This function tells Ecto that we don't support DDL transactions.
  """
  def supports_ddl_transaction?, do: true
  def in_transaction?(_repo), do: Mnesia.is_transaction()

  @doc """
  Ensure all applications necessary to run the adapter are started.
  """
  def ensure_all_started(_repo, type), do: Application.ensure_all_started(@required_apps, type)

  @doc """
  Returns the childspec that starts the adapter process.
  This method is called from `Ecto.Repo.Supervisor.init/2`.
  """
  def child_spec(_repo, opts), do: Supervisor.Spec.worker(Ecto.Mnesia.Storage, [opts])

  @doc """
  Automatically generate next ID.
  """
  def autogenerate(:id), do: nil
  def autogenerate(:embed_id), do: Ecto.UUID.autogenerate()
  def autogenerate(:binary_id), do: Ecto.UUID.autogenerate()

  @doc """
  Return directory that stores Mnesia tables on local node.
  """
  def path, do: Mnesia.system_info(:local_tables)

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
    context = Context.update_selects(context, query)
    match_spec = Query.match_spec(query, context, params)
    Logger.debug("Selecting by match specification `#{inspect match_spec}` with limit `#{inspect limit}`")

    result = table
    |> Table.select(match_spec, limit)
    |> Record.to_schema(context)
    |> ordering_fn.()

    {length(result), result}
  end

  # Deletes all records that match Ecto.Query
  def execute(_repo, %{sources: {{table, _schema}}, fields: _fields, take: _take},
                      {:nocache, {:delete_all, %Ecto.Query{} = query, limit, context, ordering_fn}},
                      params, _preprocess, opts) do
    context = Context.update_selects(context, query)
    match_spec = Query.match_spec(query, context, params)
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
    context = Context.update_selects(context, query)
    match_spec = Query.match_spec(query, context, params)
    Logger.debug("Updating all records by match specification `#{inspect match_spec}` with limit `#{inspect limit}`")

    table = table |> Table.get_name()
    Table.transaction(fn ->
      table
      |> Table.select(match_spec, limit)
      |> Enum.map(fn record ->
        update = record
        |> Query.Update.update_record(updates, params, context)
        |> List.insert_at(0, table)
        |> List.to_tuple()

        {:ok, result} = Table.update(table, List.first(record), update)
        result
      end)
      |> return_all(context, ordering_fn, opts)
    end)
  end

  defp return_all(records, context, ordering_fn, opts) do
    case Keyword.get(opts, :returning) do
      true ->
        result = records
        |> Record.to_schema(context)
        |> ordering_fn.()

        {length(result), result}
      _ ->
        {length(records), nil}
    end
  end

  @doc """
  Insert Ecto Schema struct to Mnesia database.

  TODO:
  - Process `opts`.
  - Process `on_conflict`
  - Process `returning`
  """
  def insert(_repo, %{autogenerate_id: {pk_field, _pk_type}, schema: schema, source: {_, table}}, params,
             _on_conflict, _returning, _opts) do
    do_insert(table, schema, pk_field, params)
  end

  def insert_all(_repo, %{autogenerate_id: {pk_field, _pk_type}, schema: schema, source: {_, table}},
                 _header, rows, _on_conflict, _returning, _opts) do
    table = table |> Table.get_name()
    count = Table.transaction(fn ->
      rows
      |> Enum.reduce(0, fn params, acc ->
        do_insert(table, schema, pk_field, params)
        acc + 1
      end)
    end)

    {count, nil}
  end

  defp do_insert(table, schema, pk_field, params) do
    params = params |> put_new_pk(pk_field, table)
    record = schema |> Record.new(params, table)
    case Table.insert(table, record) do
      {:ok, ^record} ->
        {:ok, params}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp put_new_pk(params, pk_field, table) when is_list(params) and is_atom(pk_field) do
    {_, params} = params
    |> Keyword.get_and_update(pk_field, fn
      nil -> {nil, Table.next_id(table)}
      val -> {val, val}
    end)

    params
  end

  def stream(_, _, _, _, _, _),
    do: raise ArgumentError, "stream/6 is not supported by adapter, use Ecto.Mnesia.Table.Stream.new/2 instead"

  def transaction(_repo, _opts, fun) do
    Table.transaction(fun)
  end

  @doc false
  # Mnesia does not support transaction rollback
  def rollback(_repo, _tid),
    do: raise ArgumentError, "rollback/2 is not supported by the adapter"

  @doc """
  Deletes a record from a Mnesia database.
  """
  def delete(_repo, %{schema: _schema, source: {_, table}, autogenerate_id: autogenerate_id}, filter, _opts) do
    pk = get_pk!(filter, autogenerate_id)
    case Table.delete(table, pk) do
      {:ok, ^pk} -> {:ok, []}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Updates record stored in a Mnesia database.
  """
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
  def loaders(:binary_id, type), do: [Ecto.UUID, type]
  def loaders(primitive, _type), do: [primitive]

  def dumpers(:binary_id, type), do: [type, Ecto.UUID]
  def dumpers(primitive, _type), do: [primitive]

  defp get_limit(nil), do: nil
  defp get_limit(%Ecto.Query.QueryExpr{expr: limit}), do: limit
end
