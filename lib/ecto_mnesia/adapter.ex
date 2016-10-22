defmodule Ecto.Mnesia.Adapter do
    @moduledoc """
    Ecto adapter for `mnesia` Erlang term database.

    It supports compound `mnesia` indexes (aka secondary indexes) in database setup.
    The implementation relies directly on `mnesia` application.
    Supports partial Ecto.Query to MatchSpec conversion for `mnesia:select` (and, join).
    MatchSpec converion utilities could be found in `Ecto.Query.Mnesia`.

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

    ## Usage in `config.exs`

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
    def  prepare(:all, %{from: {table, model},
                         select: %{expr: expr, fields: fields, take: take} = select,
                         wheres: wheres,
                         order_bys: ordering} = arg) do

         fields    = pre_fields(fields, model)
         condition = Ecto.Query.Mnesia.match_spec(model, table, fields: fields, wheres: wheres)
         ordering  = Ecto.Query.Mnesia.ordering(ordering, table)

         {:cache, {:all, condition, ordering}}
    end

    def  prepare(:delete_all, %{from: {table, _},
                                select: nil,
                                wheres: wheres} = arg) do

         {:cache, {:delete_all, Ecto.Query.Mnesia.match_spec(table, wheres: wheres)}}
    end

    @doc """
    Perform `mnesia:select` on prepared query and convert the results to Ecto Schema.
    """
    def  execute(repo, %{sources: {{table, model}}, fields: fields, take: take},
                        {:cache, fun, {:all, spec, ordering}} = query,
                        params, preprocess, options) do

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
    def  insert(_repo, %{schema: schema, source: {_, table}}, params, autogen, opts) do

         rec = Ecto.Query.Mnesia.make_tuple(schema, params, String.to_atom table)
         res = :mnesia.dirty_write(rec)

         {:ok, []}
    end

    @doc """
    Delete Record of Ecto Schema Instace from mnesia database.
    """
    def  delete(repo, %{schema: schema}, _, _) do
         {:ok, schema}
    end

    @doc """
    Update Record of Ecto Schema Instance in  mnesia database.
    """
    def  update(_repo, %{schema: schema, source: {_, table}} = _meta, params, filter, _autogen, _opts) do

         rec = Ecto.Query.Mnesia.make_tuple(schema, params, String.to_atom table)
         res = :mnesia.dirty_write(rec)

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
    Mnesia starting during Adapter boot.
    """
    def  start_link(_, _),             do: Application.start(:mnesia)

    @doc """
    Stopping Mnesia Adapter.
    """
    def  stop(_, _),                   do: :mnesia.stop

    @doc false
    def  load(_, value),               do: {:ok, value}

    @doc """
    The name of application is `:ecto_mnesia`.
    """
    def  application,                  do: :ecto

    def  dumpers(primitive, _type),    do: [primitive]

    def  loaders(primitive, _type),    do: [primitive]

    def  autogenerate(x),              do: next_id(x,1)

    def  child_spec(repo, opts),       do: Supervisor.Spec.worker(repo, opts)

    defp process_row(row, zip),        do: [List.foldr(zip, row, fn ({k, v},acc) ->
                                             Map.update!(acc, k, fn _ -> v end) end)]

    defp pre_fields([{:&, [], [_, f, _]}], _), do: f
    defp pre_fields(fields, model),            do: Ecto.Query.Mnesia.result(fields, model, [])

    defp pre_take(%{0 => {:any, t}}, _),       do: t
    defp pre_take(_, fields),                  do: fields

end
