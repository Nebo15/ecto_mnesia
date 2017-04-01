defmodule EctoMnesia.Storage.MigratorTest do
  use ExUnit.Case, async: true
  require Logger

  alias :mnesia, as: Mnesia
  alias Ecto.Migration.{Table, Index}
  alias EctoMnesia.Storage.Migrator
  alias EctoMnesia.Table, as: MnesiaTable

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
      assert :ok ==
        run_migration({
          :create,
          %Table{name: @test_table_name},
          [{:add, :id, :integer, []},
           {:add, :my_field, :integer, []}]
        })

      assert [:id, :my_field] == get_attributes()
    end

    test "when table exists" do
      migration =
        {:create,
          %Table{name: @test_table_name},
          [{:add, :id, :integer, []},
           {:add, :my_field, :integer, []}]
        }

      run_migration(migration)

      assert_raise RuntimeError, "Table migration_test_table already exists", fn ->
        run_migration(migration)
      end
    end
  end

  describe "create table if not exists" do
    test "when table does not exist" do
      assert :ok ==
        run_migration({
          :create_if_not_exists,
          %Table{name: @test_table_name},
          [{:add, :id, :integer, []},
           {:add, :my_field, :integer, []}]
        })

      assert [:id, :my_field] == get_attributes()
    end

    test "when table exists" do
      migration =
        {:create_if_not_exists,
          %Table{name: @test_table_name},
          [{:add, :id, :integer, []},
           {:add, :my_field, :integer, []}]
        }

      assert :ok == run_migration(migration)
      assert :ok == run_migration(migration)

      assert [:id, :my_field] == get_attributes()
    end
  end

  describe "alter table" do
    test "when table does not exist" do
      migration =
        {:alter,
          %Table{name: @test_table_name},
          [{:add, :id, :integer, []},
           {:add, :my_field, :integer, []}]
        }

      assert_raise RuntimeError, "Table migration_test_table does not exists", fn ->
        run_migration(migration)
      end
    end

    test "when table exists" do
      migration =
        {:create,
          %Table{name: @test_table_name},
          [{:add, :id, :integer, []},
           {:add, :my_field, :integer, []}]
        }

      run_migration(migration)

      assert :ok ==
        run_migration({
          :alter,
          %Table{name: @test_table_name},
          [{:add, :new_field, :integer, []},
           {:add, :my_second_field, :integer, []}]
        })

      assert [:id, :my_field, :new_field, :my_second_field] == get_attributes()
    end
  end

  describe "alter table fields" do
    setup do
      run_migration({
        :create,
        %Table{name: @test_table_name},
        [{:add, :id, :integer, []},
         {:add, :my_field, :integer, []}]
      })

      MnesiaTable.insert(@test_table_name, {@test_table_name, @test_record_key, 123})
      :ok
    end

    test "add field" do
      run_migration({
        :alter,
        %Table{name: @test_table_name},
        [{:add, :new_field, :integer, []}]
      })

      assert [:id, :my_field, :new_field] == get_attributes()
      assert {:migration_test_table, 1, 123, nil} == get_record()
    end

    test "add duplicate field" do
      assert_raise RuntimeError, "Duplicate field my_field", fn ->
        run_migration({
          :alter,
          %Table{name: @test_table_name},
          [{:add, :my_field, :integer, []}]
        })
      end

      assert [:id, :my_field] == get_attributes()
      assert {:migration_test_table, 1, 123} == get_record()
    end

    test "modify field" do
      assert :ok ==
        run_migration({:alter,
          %Table{name: @test_table_name},
          [{:modify, :id, :string, []}]
        })

      assert [:id, :my_field] == get_attributes()
      assert {:migration_test_table, 1, 123} == get_record()
    end

    test "modify not existing field" do
      assert_raise RuntimeError, "Field unknown_field not found", fn ->
        assert :ok ==
          run_migration({
            :alter,
            %Table{name: @test_table_name},
            [{:modify, :unknown_field, :string, []}]
          })
      end

      assert [:id, :my_field] == get_attributes()
      assert {:migration_test_table, 1, 123} == get_record()
    end

    test "rename field" do
      assert :ok ==
        run_migration({:rename,
          %Table{name: @test_table_name},
          :id,
          :new_id
        })

      assert [:new_id, :my_field] == get_attributes()
      assert {:migration_test_table, 1, 123} == get_record()
    end

    test "rename not existing field" do
      assert_raise RuntimeError, "Field unknown_field not found", fn ->
        assert :ok ==
          run_migration({
            :alter,
            %Table{name: @test_table_name},
            [{:modify, :unknown_field, :string, []}]
          })
      end

      assert [:id, :my_field] == get_attributes()
      assert {:migration_test_table, 1, 123} == get_record()
    end

    test "delete field" do
      run_migration({:alter,
        %Table{name: @test_table_name},
        [{:add, :new_field, :integer, []}]
      })

      assert {:migration_test_table, 1, 123, nil} == get_record()

      assert :ok ==
        run_migration({
          :alter,
          %Table{name: @test_table_name},
          [{:remove, :new_field}]
        })

      assert [:id, :my_field] == get_attributes()
      assert {:migration_test_table, 1, 123} == get_record()
    end

    test "delete not existing field" do
      assert_raise RuntimeError, "Field unknown_field not found", fn ->
        assert :ok ==
          run_migration({:alter,
            %Table{name: @test_table_name},
            [{:remove, :unknown_field}]
          })
      end

      assert [:id, :my_field] == get_attributes()
      assert {:migration_test_table, 1, 123} == get_record()
    end
  end

  describe "drop table" do
    test "when table does not exist" do
      assert_raise RuntimeError, "Table migration_test_table does not exists", fn ->
        assert :ok == run_migration({:drop, %Table{name: @test_table_name}})
      end
    end

    test "when table exists" do
      migration =
        {:create,
          %Table{name: @test_table_name},
          [{:add, :id, :integer, []},
           {:add, :my_field, :integer, []}]
        }

      run_migration(migration)

      assert :ok == run_migration({:drop, %Table{name: @test_table_name}})
    end
  end

  describe "drop table if exists" do
    test "when table does not exist" do
      assert :ok == run_migration({:drop_if_exists, %Table{name: @test_table_name}})
    end

    test "when table exists" do
      migration = {:create,
        %Table{name: @test_table_name},
        [{:add, :id, :integer, []},
         {:add, :my_field, :integer, []}]
      }

      run_migration(migration)

      assert :ok == run_migration({:drop_if_exists, %Table{name: @test_table_name}})
    end
  end

  describe "create index" do
    setup do
      run_migration({:create,
        %Table{name: @test_table_name},
        [{:add, :id, :integer, []},
         {:add, :my_field, :integer, []}]
      })
    end

    test "when index does not exist" do
      assert [:ok] == run_migration({:create, %Index{table: @test_table_name, columns: [:my_field]}})
      assert [3] == get_indexes()
    end

    test "when index exists" do
      run_migration({:create, %Index{table: @test_table_name, columns: [:my_field]}})

      assert_raise RuntimeError, "Index for field my_field in table migration_test_table already exists", fn ->
        run_migration({:create, %Index{table: @test_table_name, columns: [:my_field]}})
      end

      assert [3] == get_indexes()
    end
  end

  describe "create index if not exists" do
    setup do
      run_migration({:create,
        %Table{name: @test_table_name},
        [{:add, :id, :integer, []},
         {:add, :my_field, :integer, []}]
      })
    end

    test "when index does not exist" do
      assert [:ok] == run_migration({:create_if_not_exists, %Index{table: @test_table_name, columns: [:my_field]}})
      assert [3] == get_indexes()
    end

    test "when index exists" do
      assert [:ok] == run_migration({:create_if_not_exists, %Index{table: @test_table_name, columns: [:my_field]}})
      assert [:ok] == run_migration({:create_if_not_exists, %Index{table: @test_table_name, columns: [:my_field]}})
      assert [3] == get_indexes()
    end
  end

  describe "drop index" do
    setup do
      run_migration({:create,
        %Table{name: @test_table_name},
        [{:add, :id, :integer, []},
         {:add, :my_field, :integer, []}]
      })
    end

    test "when index does not exist" do
      assert_raise RuntimeError, "Index for field my_field in table migration_test_table does not exists", fn ->
        run_migration({:drop, %Index{table: @test_table_name, columns: [:my_field]}})
      end
    end

    test "when index exists" do
      run_migration({:create, %Index{table: @test_table_name, columns: [:my_field]}})
      assert [:ok] = run_migration({:drop, %Index{table: @test_table_name, columns: [:my_field]}})
      assert [] == get_indexes()
    end
  end

  describe "drop index if exists" do
    setup do
      run_migration({:create,
        %Table{name: @test_table_name},
        [{:add, :id, :integer, []},
         {:add, :my_field, :integer, []}]
      })
    end

    test "when index does not exist" do
      assert [:ok] = run_migration({:drop_if_exists, %Index{table: @test_table_name, columns: [:my_field]}})
    end

    test "when index exists" do
      run_migration({:create, %Index{table: @test_table_name, columns: [:my_field]}})
      assert [:ok] = run_migration({:drop_if_exists, %Index{table: @test_table_name, columns: [:my_field]}})
      assert [] == get_indexes()
    end
  end
end
