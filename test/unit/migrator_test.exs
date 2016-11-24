defmodule Ecto.Mnesia.MigratorTest do
  use ExUnit.Case, async: true
  require Logger

  # TODO: Support all commands
  # @type command ::
  #   raw :: String.t |
  #   {:create, Table.t, [table_subcommand]} |
  #   {:create_if_not_exists, Table.t, [table_subcommand]} |
  #   {:alter, Table.t, [table_subcommand]} |
  #   TODO: {:drop, Table.t} |
  #   TODO: {:drop_if_exists, Table.t} |
  #   {:create, Index.t} |
  #   TODO: {:create_if_not_exists, Index.t} |
  #   TODO: {:drop, Index.t} |
  #   TODO: {:drop_if_exists, Index.t}

  # @typedoc "All commands allowed within the block passed to `table/2`"
  # @type table_subcommand ::
  #   {:add, field :: atom, type :: Ecto.Type.t | Reference.t, Keyword.t} |
  #   TODO: {:modify, field :: atom, type :: Ecto.Type.t | Reference.t, Keyword.t} |
  #   {:remove, field :: atom}

  describe "create table" do
    test "when table exists" do

    end

    test "when table does not exist" do

    end
  end

  describe "create table if not exists" do
    test "when table exists" do

    end

    test "when table does not exist" do

    end
  end

  describe "alter table" do
    test "when table exists" do

    end

    test "when table does not exist" do

    end
  end

  describe "drop table" do
    test "when table exists" do

    end

    test "when table does not exist" do

    end
  end

  describe "drop table if exists" do
    test "add field" do

    end

    test "add duplicate field" do

    end

    test "modify field" do

    end

    test "modify not existing field" do

    end

    test "delete field" do

    end

    test "delete not existing field" do

    end
  end

  describe "migrate table field" do
    test "when table exists" do

    end

    test "when table does not exist" do

    end
  end

  describe "create index" do
    test "when index exists" do

    end

    test "when index does not exist" do

    end
  end

  describe "alter index" do
    test "when index exists" do

    end

    test "when index does not exist" do

    end
  end

  describe "drop index" do
    test "when index exists" do

    end

    test "when index does not exist" do

    end
  end

  describe "drop index if exists" do
    test "when index exists" do

    end

    test "when index does not exist" do

    end
  end
end
