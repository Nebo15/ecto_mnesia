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
  alias Ecto.Mnesia.{Schema, Ordering, Query, Table}

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
  def autogenerate(:embed_id), do: Ecto.UUID.generate()
  def autogenerate(:binary_id), do: Ecto.UUID.bingenerate()

  @doc """
  Return directory that stores Mnesia tables on local node.
  """
  def path, do: Mnesia.system_info(:local_tables)

  @doc false
  # Prepares are called by Ecto before `execute/6` methods.
  def prepare(:all, %Ecto.Query{wheres: wheres, limit: limit, order_bys: order_bys}) do
    limit = limit |> get_limit()
    ordering_fn = order_bys |> Ordering.get_ordering_fn()
    {:cache, {:all, wheres, ordering_fn, limit}}
  end

  def prepare(:delete_all, %Ecto.Query{from: {_table, _}, select: nil, wheres: _wheres}) do
    raise "Not supported by adapter"
    # {:cache, {:delete_all, Query.match_spec(table, nil, wheres, nil)}}
  end

  @doc false
  # Perform `mnesia:select` on prepared query and convert the results to Ecto Schema.
  def execute(_repo, %{sources: {{table, schema}}, fields: fields, take: take},
                      {:cache, _fun, {:all, wheres, ordering_fn, limit}},
                      params, preprocess, _opts) do
    match_spec = Query.match_spec(schema, table, fields, wheres, params)
    Logger.debug("Selecting by match specification `#{inspect match_spec}` with limit `#{inspect limit}`")

    result = table
    |> Table.select(match_spec, limit)
    |> Schema.from_records(schema, fields, take, preprocess)
    |> ordering_fn.()

    {length(result), result}
  end

  @doc """
  Insert Ecto Schema struct to Mnesia database.

  TODO:
  - Process `opts`.
  - Process `on_conflict`
  - Process `returning`
  """
  def insert(_repo, %{autogenerate_id: {pk_field, _pk_type}, schema: schema, source: {_, table}}, params,
             {_kind, _conflict_params, _} = _on_conflict, _returning, _opts) do
    params = params
    |> Keyword.put_new(pk_field, Table.next_id(table)) # TODO: increment counter only when ID is not set

    record = schema
    |> Schema.to_record(params, table)

    case Table.insert(table, record) do
      {:ok, ^record} ->
        {:ok, params}
      {:error, reason} ->
        {:error, reason}
    end
  end

  def transaction(_repo, _opts, fun) do
    Table.transaction(fun)
  end

  def insert_all(repo, %{source: {prefix, source}}, _header, rows, {_, _conflict_params, _} = on_conflict, returning, opts) do
    # TODO: Insert everything in a single transaction
  end

  # TODO
  # def stream()

  @doc """
  Delete Record of Ecto Schema Instace from mnesia database.
  """
  def delete(_repo, %{schema: _schema} = arg1, _, _) do
    IO.inspect arg1
    # :mnesia.delete(name, key, case lock do
    #   :write  -> :write
    #   :write! -> :sticky_write
    # end)

    raise "Not supported by adapter"
    # {:ok, schema}
  end

  @doc """
  Update Record of Ecto Schema Instance in  mnesia database.
  """
  def update(_repo, %{schema: schema, source: {_, table}} = _meta, params, _filter, _autogen, _opts) do
    rec = Schema.to_record(schema, params, String.to_atom table)
    Mnesia.dirty_write(rec)

    {:ok, []}
  end

  @doc false
  def dumpers(primitive, _type),    do: [primitive]
  def loaders(primitive, _type),    do: [primitive]

  defp get_limit(nil), do: nil
  defp get_limit(%Ecto.Query.QueryExpr{expr: limit}), do: limit
end
