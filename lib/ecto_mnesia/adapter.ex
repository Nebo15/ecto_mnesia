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

      config :ecto, :mnesia_metainfo, Sample.Model
      config :ecto, :mnesia_backend,  :ram_copies
  """

  require Logger
  alias :mnesia, as: Mnesia

  @behaviour Ecto.Adapter

  @required_apps [:mnesia]

  @doc false
  defmacro __before_compile__(_env), do: :ok

  @doc """
  This function tells Ecto that we don't support DDL transactions.
  """
  def supports_ddl_transaction? do
    false
  end

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
    Supervisor.Spec.worker(Ecto.Mnesia.Storage, opts)
  end

  @doc """
  Automatically generate next ID.
  """
  def autogenerate(:id),        do: :increment
  def autogenerate(:embed_id),  do: Ecto.UUID.generate()
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







  ##### TODO refactor everything above this line :)

  @doc """
  Convert Ecto Qeury to Erlang MatchSpec, include caching.
  """
  def  prepare(:all, %{from: {table, _model},
                       select: %{expr: _expr, fields: _fields, take: take},
                       wheres: wheres,
                       order_bys: ordering} = arg) do

       :io.format("Args: ~p~n",[arg])
       :io.format("Take: ~p~n",[take])

       # fields    = pre_fields(fields, model)
       # spec     = Ecto.Mnesia.Query.match_spec(model, table, fields: fields, wheres: wheres)
       spec      = wheres
       ordering  = Ecto.Mnesia.Query.ordering(ordering, table)

       {:cache, {:all, spec, ordering}}
  end

  def  prepare(:delete_all, %{from: {_table, _},
                              select: nil,
                              wheres: _wheres}) do
      raise "Not supported by adapter"
      # {:cache, {:delete_all, Ecto.Mnesia.Query.match_spec(table, nil, wheres, nil)}}
  end

  @doc """
  Perform `mnesia:select` on prepared query and convert the results to Ecto Schema.
  """
  def  execute(_repo, %{sources: {{table, model}}, fields: fields, take: take},
                      {:cache, _fun, {:all, wheres, _ordering}} = query,
                      params, preprocess, options) do


       :io.format("Params: ~p~n",[params])
       :io.format("Take: ~p~n",[take])
       :io.format("Query: ~p~n",[query])
       :io.format("Preprocess: ~p~n",[preprocess])
       :io.format("Options: ~p~n",[options])

       spec = Ecto.Mnesia.Query.match_spec(model, table, fields, wheres, params)

       :io.format("Spec: ~p~n",[spec])

       Logger.info("Prepare Query Params: #{inspect preprocess}")

       fields = pre_fields(fields, model)
       take   = pre_take(take, fields)
       rows   = table |> String.to_atom
                      |> Mnesia.dirty_select(spec)
                      |> Enum.map(fn row -> process_row(model.__struct__,
                                                        List.zip([take, row])) end)

       {length(rows), rows}
  end

  @doc """
  Insert Ecto Schema Instance to mnesia database.
  """
  def  insert(_repo, %{schema: schema, source: {_, table}}, params, _autogen, _opts) do

       rec = Ecto.Mnesia.Query.make_tuple(schema, params, String.to_atom table)
       Mnesia.dirty_write(rec)

       {:ok, []}
  end

  @doc """
  Delete Record of Ecto Schema Instace from mnesia database.
  """
  def  delete(_repo, %{schema: schema}, _, _) do
       {:ok, schema}
  end

  @doc """
  Update Record of Ecto Schema Instance in  mnesia database.
  """
  def  update(_repo, %{schema: schema, source: {_, table}} = _meta, params, _filter, _autogen, _opts) do

       rec = Ecto.Mnesia.Query.make_tuple(schema, params, String.to_atom table)
       Mnesia.dirty_write(rec)

       {:ok, []}
  end

  def  insert_all(_, _, _, _, _, _), do: raise "Not supported by adapter"

  @doc """
  Retrieve all records from the given table using `mnesia:all_keys`.
  """
  def  all(table) do
       many(fn -> Mnesia.all_keys(table)
               |> Enum.map(fn key
               -> Mnesia.read(table, key) end) end)
  end



  def  many(fun) do
       case Mnesia.activity(:async_dirty,fun) do
            {:aborted, error} -> {:error, error}
            {:atomic, r} -> r
            x -> x end end



  @doc """
  Stopping Mnesia Adapter.
  """
  def  stop(_, _),                   do: Mnesia.stop

  @doc false
  def  load(_, value),               do: {:ok, value}

  def  dumpers(primitive, _type),    do: [primitive]

  def  loaders(primitive, _type),    do: [primitive]

  defp process_row(row, zip),        do: [List.foldr(zip, row, fn ({k, v},acc) ->
                                           Map.update!(acc, k, fn _ -> v end) end)]

  defp pre_fields([{:&, [], [_, f, _]}], _), do: f
  defp pre_fields(fields, model),            do: Ecto.Mnesia.Query.result(fields, model, [])

  defp pre_take(%{0 => {:any, t}}, _),       do: t
  defp pre_take(_, fields),                  do: fields
end
