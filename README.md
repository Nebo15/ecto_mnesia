# Ecto.Mnesia

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

## TODO

- [ ] Manually prefix names of table (namespaces), because all tables have global scope for all nodes and they can collide.
- [ ] Support Ecto-style migrations to create tables. Get rid from Model in configuration.
- [ ] Support most of replication and distribution options from configs.
- [ ] Refactor `Schema` module for disambiguation from Mnesia schemas `mnesia:create_schema(ListOfNodes)`.
- [ ] Support auto-clustering with skycluster.
- [ ] Set Mnesia data dir from conf
- [ ] Add `mnesia:wait_for_tables(TableList, TimeOut)` before start
- [ ] Support sync transaction type (that waits for all nodes to finish transaction, not only commit them)

## Usage in `config.exs`

    config :ecto, :mnesia_meta_schema, Sample.Model
    config :ecto, :mnesia_backend,  :ram_copies

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `ecto_mnesia` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:ecto_mnesia, "~> 0.1.0"}]
    end
    ```

  2. Ensure `ecto_mnesia` is started before your application:

    ```elixir
    def application do
      [applications: [:ecto_mnesia]]
    end
    ```

If [published on HexDocs](https://hex.pm/docs/tasks#hex_docs), the docs can
be found at [https://hexdocs.pm/ecto_mnesia](https://hexdocs.pm/ecto_mnesia)

