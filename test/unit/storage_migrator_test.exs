defmodule Ecto.Mnesia.Storage.MigratorTest do
  use ExUnit.Case, async: true
  require Logger

  alias :mnesia, as: Mnesia
  alias Ecto.Migration.{Table, Index}
  alias Ecto.Mnesia.Storage.Migrator
  alias Ecto.Mnesia.Table, as: MnesiaTable

  @test_table_name :migration_test_table
  @test_record_key 1

  defp run_migration(migration) do
    Migrator.execute(TestRepo, migration, [])
  end

  defp get_attributes do
    @test_table_name |> Mnesia.table_info(:attributes)
  end

  defp get_indexes do
    @test_table_name |> Mnesia.table_info(:index)
  end

  defp get_record do
    @test_table_name |> MnesiaTable.get(@test_record_key)
  end

  setup do
    Mnesia.delete_table(@test_table_name)
    :ok
  end

  describe "create table" do
    test "when table does not exist" do
      assert :ok == {:create,
        %Table{name: @test_table_name},
        [{:add, :id, :integer, []},
         {:add, :my_field, :integer, []}]
      }
      |> run_migration

      assert [:id, :my_field] == get_attributes()
    end

    test "when table exists" do
      migration = {:create,
        %Table{name: @test_table_name},
        [{:add, :id, :integer, []},
         {:add, :my_field, :integer, []}]
      }

      migration
      |> run_migration

      assert_raise RuntimeError, "Table migration_test_table already exists", fn ->
        migration
        |> run_migration
      end
    end
  end

  describe "create table if not exists" do
    test "when table does not exist" do
      assert :ok == {:create_if_not_exists,
        %Table{name: @test_table_name},
        [{:add, :id, :integer, []},
         {:add, :my_field, :integer, []}]
      }
      |> run_migration

      assert [:id, :my_field] == get_attributes()
    end

    test "when table exists" do
      migration = {:create_if_not_exists,
        %Table{name: @test_table_name},
        [{:add, :id, :integer, []},
         {:add, :my_field, :integer, []}]
      }

      assert :ok == migration
      |> run_migration

      assert :ok == migration
      |> run_migration

      assert [:id, :my_field] == get_attributes()
    end
  end

  describe "alter table" do
    test "when table does not exist" do
      migration = {:alter,
        %Table{name: @test_table_name},
        [{:add, :id, :integer, []},
         {:add, :my_field, :integer, []}]
      }

      assert_raise RuntimeError, "Table migration_test_table does not exists", fn ->
        migration
        |> run_migration
      end
    end

    test "when table exists" do
      migration = {:create,
        %Table{name: @test_table_name},
        [{:add, :id, :integer, []},
         {:add, :my_field, :integer, []}]
      }

      migration
      |> run_migration

      assert :ok == {:alter,
        %Table{name: @test_table_name},
        [{:add, :new_field, :integer, []},
         {:add, :my_second_field, :integer, []}]
      }
      |> run_migration

      assert [:id, :my_field, :new_field, :my_second_field] == get_attributes()
    end
  end

  describe "alter table fields" do
    setup do
      {:create,
        %Table{name: @test_table_name},
        [{:add, :id, :integer, []},
         {:add, :my_field, :integer, []}]
      }
      |> run_migration

      MnesiaTable.insert(@test_table_name, {@test_table_name, @test_record_key, 123})
      :ok
    end

    test "add field" do
      {:alter,
        %Table{name: @test_table_name},
        [{:add, :new_field, :integer, []}]
      }
      |> run_migration

      assert [:id, :my_field, :new_field] == get_attributes()
      assert {:migration_test_table, 1, 123, nil} == get_record()
    end

    test "add duplicate field" do
      assert_raise RuntimeError, "Duplicate field my_field", fn ->
        {:alter,
          %Table{name: @test_table_name},
          [{:add, :my_field, :integer, []}]
        }
        |> run_migration
      end

      assert [:id, :my_field] == get_attributes()
      assert {:migration_test_table, 1, 123} == get_record()
    end

    test "modify field" do
      assert :ok == {:alter,
        %Table{name: @test_table_name},
        [{:modify, :id, :string, []}]
      }
      |> run_migration

      assert [:id, :my_field] == get_attributes()
      assert {:migration_test_table, 1, 123} == get_record()
    end

    test "modify not existing field" do
      assert_raise RuntimeError, "Field unknown_field not found", fn ->
        assert :ok == {:alter,
          %Table{name: @test_table_name},
          [{:modify, :unknown_field, :string, []}]
        }
        |> run_migration
      end

      assert [:id, :my_field] == get_attributes()
      assert {:migration_test_table, 1, 123} == get_record()
    end

    test "delete field" do
      {:alter,
        %Table{name: @test_table_name},
        [{:add, :new_field, :integer, []}]
      }
      |> run_migration

      assert {:migration_test_table, 1, 123, nil} == get_record()

      assert :ok == {:alter,
        %Table{name: @test_table_name},
        [{:remove, :new_field}]
      }
      |> run_migration

      assert [:id, :my_field] == get_attributes()
      assert {:migration_test_table, 1, 123} == get_record()
    end

    test "delete not existing field" do
      assert_raise RuntimeError, "Field unknown_field not found", fn ->
        assert :ok == {:alter,
          %Table{name: @test_table_name},
          [{:remove, :unknown_field}]
        }
        |> run_migration
      end

      assert [:id, :my_field] == get_attributes()
      assert {:migration_test_table, 1, 123} == get_record()
    end
  end

  describe "drop table" do
    test "when table does not exist" do
      assert_raise RuntimeError, "Table migration_test_table does not exists", fn ->
        assert :ok == {:drop, %Table{name: @test_table_name}}
        |> run_migration
      end
    end

    test "when table exists" do
      migration = {:create,
        %Table{name: @test_table_name},
        [{:add, :id, :integer, []},
         {:add, :my_field, :integer, []}]
      }

      migration
      |> run_migration

      assert :ok == {:drop, %Table{name: @test_table_name}}
      |> run_migration
    end
  end

  describe "drop table if exists" do
    test "when table does not exist" do
      assert :ok == {:drop_if_exists, %Table{name: @test_table_name}}
      |> run_migration
    end

    test "when table exists" do
      migration = {:create,
        %Table{name: @test_table_name},
        [{:add, :id, :integer, []},
         {:add, :my_field, :integer, []}]
      }

      migration
      |> run_migration

      assert :ok == {:drop_if_exists, %Table{name: @test_table_name}}
      |> run_migration
    end
  end

  describe "create index" do
    setup do
      {:create,
        %Table{name: @test_table_name},
        [{:add, :id, :integer, []},
         {:add, :my_field, :integer, []}]
      }
      |> run_migration
    end

    test "when index does not exist" do
      assert [:ok] == {:create, %Index{table: @test_table_name, columns: [:my_field]}}
      |> run_migration

      assert [3] == get_indexes()
    end

    test "when index exists" do
      {:create, %Index{table: @test_table_name, columns: [:my_field]}}
      |> run_migration

      assert_raise RuntimeError, "Index for field my_field in table migration_test_table already exists", fn ->
        {:create, %Index{table: @test_table_name, columns: [:my_field]}}
        |> run_migration
      end

      assert [3] == get_indexes()
    end
  end

  describe "create index if not exists" do
    setup do
      {:create,
        %Table{name: @test_table_name},
        [{:add, :id, :integer, []},
         {:add, :my_field, :integer, []}]
      }
      |> run_migration
    end

    test "when index does not exist" do
      assert [:ok] == {:create_if_not_exists, %Index{table: @test_table_name, columns: [:my_field]}}
      |> run_migration

      assert [3] == get_indexes()
    end

    test "when index exists" do
      assert [:ok] == {:create_if_not_exists, %Index{table: @test_table_name, columns: [:my_field]}}
      |> run_migration

      assert [:ok] == {:create_if_not_exists, %Index{table: @test_table_name, columns: [:my_field]}}
      |> run_migration

      assert [3] == get_indexes()
    end
  end

  describe "drop index" do
    setup do
      {:create,
        %Table{name: @test_table_name},
        [{:add, :id, :integer, []},
         {:add, :my_field, :integer, []}]
      }
      |> run_migration
    end

    test "when index does not exist" do
      assert_raise RuntimeError, "Index for field my_field in table migration_test_table does not exists", fn ->
        {:drop, %Index{table: @test_table_name, columns: [:my_field]}}
        |> run_migration
      end
    end

    test "when index exists" do
      {:create, %Index{table: @test_table_name, columns: [:my_field]}}
      |> run_migration

      assert [:ok] = {:drop, %Index{table: @test_table_name, columns: [:my_field]}}
      |> run_migration

      assert [] == get_indexes()
    end
  end

  describe "drop index if exists" do
    setup do
      {:create,
        %Table{name: @test_table_name},
        [{:add, :id, :integer, []},
         {:add, :my_field, :integer, []}]
      }
      |> run_migration
    end

    test "when index does not exist" do
      assert [:ok] = {:drop_if_exists, %Index{table: @test_table_name, columns: [:my_field]}}
      |> run_migration
    end

    test "when index exists" do
      {:create, %Index{table: @test_table_name, columns: [:my_field]}}
      |> run_migration

      assert [:ok] = {:drop_if_exists, %Index{table: @test_table_name, columns: [:my_field]}}
      |> run_migration

      assert [] == get_indexes()
    end
  end
end
