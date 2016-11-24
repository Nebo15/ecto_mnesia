# ecto_mnesia

[![Deps Status](https://beta.hexfaktor.org/badge/all/github/Nebo15/ecto_mnesia.svg)](https://beta.hexfaktor.org/github/Nebo15/ecto_mnesia) [![Hex.pm Downloads](https://img.shields.io/hexpm/dw/ecto_mnesia.svg?maxAge=3600)](https://hex.pm/packages/ecto_mnesia) [![Latest Version](https://img.shields.io/hexpm/v/ecto_mnesia.svg?maxAge=3600)](https://hex.pm/packages/ecto_mnesia) [![License](https://img.shields.io/hexpm/l/ecto_mnesia.svg?maxAge=3600)](https://hex.pm/packages/ecto_mnesia) [![Build Status](https://travis-ci.org/Nebo15/ecto_mnesia.svg?branch=master)](https://travis-ci.org/Nebo15/ecto_mnesia) [![Coverage Status](https://coveralls.io/repos/github/Nebo15/ecto_mnesia/badge.svg?branch=master)](https://coveralls.io/github/Nebo15/ecto_mnesia?branch=master) [![Ebert](https://ebertapp.io/github/Nebo15/ecto_mnesia.svg)](https://ebertapp.io/github/Nebo15/ecto_mnesia)

Ecto 2.X adapter for Mnesia Erlang Term database. In most cases it can be used as drop-in replacement for other adapters.

Supported features:

- Compatible `Ecto.Repo` API.
- Automatically converts `Ecto.Query` structs to Erlang `match_spec`. Also adapter emulates `query.select` and `query.order_bys` behaviors, even trough Mnesia itself does not support them.
- Auto-generated (via sequence table) `:id` primary keys.
- Migrations and database setup via `Ecto.Migrations`.
- Transactions in dirty context.

Planned features:

- Secondary indexes
- Native primary key and unique index constraints.
- Custom primary keys.
- Other transactional contexts.

Not supported features (create issue and vote if you need them):

- Type casting. Mnesia can store any data in any field, including strings, numbers, atoms, tuples, floats or even PID's. **All types in your migrations will be silently ignored**.
- Mnesia clustering and auto-clustering.

## Why Mnesia?

We have production task that needs low read-latency database and our data fits in RAM, so Mnesia is a best choice: it's part of OTP, shares same space as our app does, work fast in RAM and supports transactions (it's critical for fintech projects).

Why do we need adapter? We don't want to lock us to any specific database, since requirements can change. Ecto allows to switch databases by simply modifying config, and we might want to go back to Postres or another DB.

### Clustering

We don't recommend to use distributed Mnesia, because it's neither AP, nor CP database. (And there are no such thing as AC DB.) **Mnesia requires you to handle network partitions (split brains) manually.**

So clustering should be an option only when you absolutely sure how you will recover from split-brains. In general, if you don't sure what is network splits, don`t use it.

### Mnesia configuration from `config.exs`

    config :ecto, :mnesia_meta_schema, Sample.Model
    config :ecto, :mnesia_backend,  :ram_copies

## Installation

It is [available in Hex](https://hexdocs.pm/ecto_mnesia), the package can be installed as:

  1. Add `ecto_mnesia` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:ecto_mnesia, "~> 0.3.0"}]
    end
    ```

  2. Ensure `ecto_mnesia` is started before your application:

    ```elixir
    def application do
      [applications: [:ecto_mnesia]]
    end
    ```

The docs can be found at [https://hexdocs.pm/ecto_mnesia](https://hexdocs.pm/ecto_mnesia).

## Thanks

We want to thank [meh](https://github.com/meh) for his [Amnesia](https://github.com/meh/amnesia) package that helped a loot in initial Mnesia investigations. Some pieces of code was copied from hes repo.

Also big thanks to [josevalim](https://github.com/josevalim) for Elixir, Ecto and active help while this adapter was developed.
