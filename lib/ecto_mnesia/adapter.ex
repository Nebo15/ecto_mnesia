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

    @behaviour Ecto.Adapter

    require Logger

    defmacro __before_compile__(_env), do: :ok

    @doc """
    Sequence autogeneration is implemented as `mnesia:update_counter`.
    """
    def  next_id(record, inc),         do: :mnesia.dirty_update_counter({:id_seq, record}, inc)

    @doc """
    Print directory of `mnesia` tables on local node.
    """
    def  dir,                          do: :mnesia.system_info(:local_tables)


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
                        |> :mnesia.dirty_select(spec)
                        |> Enum.map(fn row -> process_row(model.__struct__,
                                                          List.zip([take, row])) end)

         {length(rows), rows}
    end

    @doc """
    Insert Ecto Schema Instance to mnesia database.
    """
    def  insert(_repo, %{schema: schema, source: {_, table}}, params, _autogen, _opts) do

         rec = Ecto.Mnesia.Query.make_tuple(schema, params, String.to_atom table)
         :mnesia.dirty_write(rec)

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
         :mnesia.dirty_write(rec)

         {:ok, []}
    end

    def  insert_all(_, _, _, _, _, _), do: raise "Not supported by adapter"

    @doc """
    Default list of tables available for storage up: `{table,fields}`.
    """
    def  meta, do: []

    @doc """
    List of tables with compound (aka secondary indexes) keys: `{table,keys}`.
    """
    def  keys, do: []

    @doc """
    Retrieve all records from the given table using `mnesia:all_keys`.
    """
    def  all(table) do
         many(fn -> :mnesia.all_keys(table)
                 |> Enum.map(fn key
                 -> :mnesia.read(table, key) end) end)
    end

    def  count(table), do: :mnesia.table_info(table, :size)

    def  many(fun) do
         case :mnesia.activity(:async_dirty,fun) do
              {:aborted, error} -> {:error, error}
              {:atomic, r} -> r
              x -> x end end

    def  storage_down(x) do
         :mnesia.stop
         :mnesia.delete_schema([Kernel.node])
         Logger.info("Storage up: #{inspect x}")
    end

    @doc """
    Mnesia starting during Adapter boot.
    """
    def ensure_all_started(_, _),     do: Application.ensure_all_started(:mnesia)

    @doc """
    Stopping Mnesia Adapter.
    """
    def  stop(_, _),                   do: :mnesia.stop

    @doc false
    def  load(_, value),               do: {:ok, value}

    @doc """
    The name of the application is `:ecto`.
    """
    def  application,                  do: :ecto_mnesia

    def  dumpers(primitive, _type),    do: [primitive]

    def  loaders(primitive, _type),    do: [primitive]

    def  autogenerate(x),              do: next_id(x,1)

    def  child_spec(_repo, opts) do
      Supervisor.Spec.worker(Ecto.Mnesia.Storage, opts)
    end

    defp process_row(row, zip),        do: [List.foldr(zip, row, fn ({k, v},acc) ->
                                             Map.update!(acc, k, fn _ -> v end) end)]

    defp pre_fields([{:&, [], [_, f, _]}], _), do: f
    defp pre_fields(fields, model),            do: Ecto.Mnesia.Query.result(fields, model, [])

    defp pre_take(%{0 => {:any, t}}, _),       do: t
    defp pre_take(_, fields),                  do: fields

end
