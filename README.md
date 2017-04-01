# Ecto adapter for Mnesia Erlang term database

[![Deps Status](https://beta.hexfaktor.org/badge/all/github/Nebo15/ecto_mnesia.svg)](https://beta.hexfaktor.org/github/Nebo15/ecto_mnesia) [![Hex.pm Downloads](https://img.shields.io/hexpm/dw/ecto_mnesia.svg?maxAge=3600)](https://hex.pm/packages/ecto_mnesia) [![Latest Version](https://img.shields.io/hexpm/v/ecto_mnesia.svg?maxAge=3600)](https://hex.pm/packages/ecto_mnesia) [![License](https://img.shields.io/hexpm/l/ecto_mnesia.svg?maxAge=3600)](https://hex.pm/packages/ecto_mnesia) [![Build Status](https://travis-ci.org/Nebo15/ecto_mnesia.svg?branch=master)](https://travis-ci.org/Nebo15/ecto_mnesia) [![Coverage Status](https://coveralls.io/repos/github/Nebo15/ecto_mnesia/badge.svg?branch=master)](https://coveralls.io/github/Nebo15/ecto_mnesia?branch=master) [![Ebert](https://ebertapp.io/github/Nebo15/ecto_mnesia.svg)](https://ebertapp.io/github/Nebo15/ecto_mnesia)

Ecto 2.X adapter for Mnesia Erlang term database. In most cases it can be used as drop-in replacement for other adapters.

Supported features:

- Compatible `Ecto.Repo` API.
- Automatically converts `Ecto.Query` structs to Erlang `match_spec`. Also adapter emulates `query.select` and `query.order_bys`, `select .. in [..]` behaviours, even though Mnesia itself does not support them.
- Auto-generated (via sequence table) `:id` primary keys.
- Migrations and database setup via `Ecto.Migrations`.
- Transactions.
- Secondary indexes.

Planned features:

- Native primary key and unique index constraints.
- Custom primary keys.
- Other transactional contexts.

Not supported features (create issue and vote if you need them):

- Type casting. Mnesia can store any data in any field, including strings, numbers, atoms, tuples, floats or even PID's. **All types in your migrations will be silently ignored**.
- Mnesia clustering and auto-clustering.
- Lookups in `json` fields.
- Schemaless queries.
- Composite primary keys.
- Unique/all other constraints (including associations).
- JOINs.
- min, max, avg and other aggregation functions.
- Intevals.

**In general**. This adapter is still not passing all Ecto integration tests and in active development. But it already can be helpful in simple use-cases.

## Why Mnesia?

We have a production task that needs low read-latency database and our data fits in RAM, so Mnesia is the best choice: it's part of OTP, shares same space as our app does, work fast in RAM and supports transactions (it's critical for fintech projects).

Why do we need an adapter? We don't want to lock us to any specific database, since requirements can change. Ecto allows to switch databases by simply modifying the config, and we might want to go back to Postres or another DB.

### Clustering

We don't recommend to use distributed Mnesia, because it's neither AP, nor CP database. (And there are no such thing as AC DB.) **Mnesia requires you to handle network partitions (split brains) manually.**

So clustering should be an option only when you absolutely sure how you will recover from split-brains. In general, if you don't sure what is network splits, don't use it.

### Mnesia configuration from `config.exs`

    config :ecto_mnesia,
      host: {:system, :atom, "MNESIA_HOST", Kernel.node()},
      storage_type: {:system, :atom, "MNESIA_STORAGE_TYPE", :disc_copies}

    config :mnesia,
      dir: 'priv/data/mnesia' # Make sure this directory exists

Notice that `{:system, [TYPE], ENV_NAME, default_value}` tuples can be replaced with any raw values.

They tell adapter to read configuration from environment in run-time, so you will be able to set `MNESIA_HOST` and `MNESIA_STORAGE_TYPE` environment variables, which is very useful when you releasing app in production and don't want to rebuild all code on each config change.

If you want to know more how this tool works take look at [Confex](https://github.com/Nebo15/confex) package.

#### Storage Types

  - `:disc_copies` - store data in both RAM and on dics. Recommended value for most cases.
  - `:ram_copies` - store data only in RAM. Data will be lost on node restart. Useful when working with large datasets that don't need to be persisted.
  - `:disc_only_copies` - store data only on disc. This will limit database size to 2GB and affect adapter performance.

#### Table Types (Engines)

  In migrations you can select which kind of table you want to use:

  ```elixir
  create_if_not_exists table(:my_table, engine: :set) do
    # ...
  end
  ```

  Supported types:

  - `:set` - expected your records to have at least one unique primary key that **should be in first column**.
  - `:ordered_set` - default type. Same as `:set`, but Mnesia will store data in a table will be ordered by primary key.
  - `:bag` - expected all records to be unique, but no primary key is required. (Internally, it will use first field as a primary key).

##### Ordered Set Performance

  Ordered set comes in a cost of increased complexity of write operations:

  **Set**

  Operation | Average | Worst Case
  ----------|---------|----------
  Space     | O(n)    | O(n)
  Search    | O(1)    | O(n)
  Insert    | O(1)    | O(n)
  Delete    | O(1)    | O(n)

  **Ordered Set**

  Operation | Average  | Worst Case
  ----------|----------|----------
  Space     | O(n)     | O(n)
  Search    | O(log n) | O(n)
  Insert    | O(log n) | O(n)
  Delete    | O(log n) | O(n)

## Installation

It is [available in Hex](https://hexdocs.pm/ecto_mnesia), the package can be installed as:

  1. Add `ecto_mnesia` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:ecto_mnesia, "~> 0.9.0"}]
    end
    ```

  2. Ensure `ecto_mnesia` is started before your application:

    ```elixir
    def application do
      [applications: [:ecto_mnesia]]
    end
    ```

  3. Use `EctoMnesia.Adapter` as your `Ecto.Repo` adapter:

    ```elixir
    config :my_app, MyRepo,
      adapter: EctoMnesia.Adapter
    ```

  4. Optionally set custom Mnesia data dir (don't forget to create it):

    ```elixir
    config :mnesia, :dir, 'priv/data/mnesia'
    ```

The docs can be found at [https://hexdocs.pm/ecto_mnesia](https://hexdocs.pm/ecto_mnesia).

## Thanks

We want to thank [meh](https://github.com/meh) for his [Amnesia](https://github.com/meh/amnesia) package that helped a loot in initial Mnesia investigations. Some pieces of code was copied from his repo.

Also big thanks to [josevalim](https://github.com/josevalim) for Elixir, Ecto and active help while this adapter was developed.
