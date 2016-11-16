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
  alias Ecto.Mnesia.Adapter.Schema
  alias Ecto.Mnesia.Query

  @behaviour Ecto.Adapter

  @required_apps [:mnesia]

  @doc false
  defmacro __before_compile__(_env), do: :ok

  @doc """
  This function tells Ecto that we don't support DDL transactions.
  """
  def supports_ddl_transaction?, do: false
  def in_transaction?(_repo), do: supports_ddl_transaction?()

  @doc """
  Ensure all applications necessary to run the adapter are started.
  """
  def ensure_all_started(_repo, type) do
    Application.ensure_all_started(@required_apps, type)
  end

  @doc """
  Returns the childspec that starts the adapter process.
  This method is called from `Ecto.Repo.Supervisor.init/2`.
  """
  def child_spec(_repo, opts) do
    Supervisor.Spec.worker(Ecto.Mnesia.Storage, [opts])
  end

  @doc """
  Automatically generate next ID.
  """
  def autogenerate(:id), do: nil
  def autogenerate(:embed_id), do: Ecto.UUID.generate()
  def autogenerate(:binary_id), do: Ecto.UUID.bingenerate()

  @doc """
  Returns auto-incremented integer ID for table in Mnesia.

  Sequence auto-generation is implemented as `mnesia:dirty_update_counter`.
  """
  def next_id(table, inc \\ 1) when is_atom(table), do: Mnesia.dirty_update_counter({:id_seq, table}, inc)

  @doc """
  Return directory that stores `mnesia` tables on local node.
  """
  def path, do: Mnesia.system_info(:local_tables)

  @doc """
  Returns count of elements in Mnesia talbe.
  """
  def count(table) when is_atom(table), do: Mnesia.table_info(table, :size)

  @doc """
  Prepares are called by Ecto before `execute/6` methods.
  """






  ##### TODO refactor everything above this line :)

  @doc """
  Convert Ecto Query to Erlang MatchSpec, include caching.
  """
  def  prepare(:all, %{from: {table, _schema},
                       select: %{expr: _expr, fields: _fields, take: take},
                       wheres: wheres,
                       order_bys: ordering} = arg) do

       # :io.format("Args: ~p~n",[arg])
       # :io.format("Take: ~p~n",[take])
       # :io.format("Expr: ~p~n",[expr])
       # :io.format("Field: ~p~n",[fields])

       # fields    = pre_fields(fields, schema)
       # spec     = Query.match_spec(schema, table, fields: fields, wheres: wheres)
       spec      = wheres
       ordering  = Query.ordering(ordering, table)

       {:cache, {:all, spec, ordering}}
  end

  def  prepare(:delete_all, %{from: {_table, _}, select: nil, wheres: _wheres}) do
      raise "Not supported by adapter"
      # {:cache, {:delete_all, Query.match_spec(table, nil, wheres, nil)}}
  end

  @doc """
  Perform `mnesia:select` on prepared query and convert the results to Ecto Schema.
  """
  def execute(_repo, %{sources: {{table, schema}}, fields: fields, take: take},
                      {:cache, _fun, {:all, wheres, _ordering}} = query,
                      params, preprocess, options) do
    match_spec = Query.match_spec(schema, table, fields, wheres, params)

    Logger.debug("Executing Mnesia match_spec #{inspect match_spec}")

    result = table
    |> String.to_atom
    |> Mnesia.dirty_select(match_spec)
    |> Schema.from_records(schema, fields, take, preprocess)

    {length(result), result}
  end

  @doc """
  Insert Ecto Schema struct to Mnesia database.

  TODO:
  - Process `opts`.
  - Process `on_conflict`
  - Process `returning`
  """
  def insert(_repo, %{autogenerate_id: {pk_field, pk_type}, schema: schema, source: {_, table}}, params,
             {_kind, _conflict_params, _} = _on_conflict, _returning, _opts) do

    table = String.to_atom(table)
    params = params
    |> Keyword.put_new(pk_field, next_id(table, 1))

    record = schema
    |> Schema.to_record(params, table)

    case Mnesia.dirty_write(record) do
      :ok -> {:ok, params}
      error -> {:error, error}
    end
  end

  @doc """
  Delete Record of Ecto Schema Instace from mnesia database.
  """
  def delete(_repo, %{schema: schema}, _, _) do
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

  def  insert_all(_, _, _, _, _, _, _), do: raise "Not supported by adapter"

  @doc """
  Retrieve all records from the given table using `mnesia:all_keys`.
  """
  def all(table) do
    many(fn ->
      table
      |> Mnesia.all_keys()
      |> Enum.map(fn
        key -> Mnesia.read(table, key)
      end)
    end)
  end

  def many(fun) do
    case Mnesia.activity(:async_dirty, fun) do
      {:aborted, error} -> {:error, error}
      {:atomic, r} -> r
      x -> x
    end
  end

  @doc false
  def  load(_, value),               do: {:ok, value}

  def  dumpers(primitive, _type),    do: [primitive]

  def  loaders(primitive, _type),    do: [primitive]
end
