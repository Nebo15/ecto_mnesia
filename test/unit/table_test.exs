defmodule Ecto.Mnesia.TableTest do
  use ExUnit.Case
  require Logger
  alias Ecto.Mnesia.Table

  @test_table :sell_offer
  @test_record_key 1
  @test_record {:sell_offer, @test_record_key, 123, "loan-007", nil, nil, 9.23, nil, true,
                nil, nil, nil, 26, 1.0e3, 20, 30, "AB", nil, 100, "100", nil, nil, "ok", nil, true,
                {{2016, 11, 18}, {18, 43, 8, 496985}}, {{2016, 11, 18}, {18, 43, 8, 502628}}}

  setup do
    :mnesia.clear_table(:sell_offer)
    :mnesia.clear_table(:id_seq)
    :ok
  end

  test "insert record" do
    assert {:ok, @test_record} = Table.insert(@test_table, @test_record)
    assert 1 == :mnesia.table_info(@test_table, :size)
  end

  describe "read record" do
    test "existing" do
      Table.insert(@test_table, @test_record)
      assert @test_record == Table.get(@test_table, @test_record_key)
    end

    test "not existing" do
      assert nil == Table.get(@test_table, @test_record_key)
    end
  end

  describe "select record" do
    test "all" do
      Table.insert(@test_table, @test_record)
      assert [@test_record] == Table.select(@test_table,
        [{{:sell_offer, :"$1", :"$2", :"$3", :"$4", :"$5", :"$6", :"$7", :"$8", :"$9",
           :"$10", :"$11", :"$12", :"$13", :"$14", :"$15", :"$16", :"$17", :"$18",
           :"$19", :"$20", :"$21", :"$22", :"$23", :"$24", :"$25", :"$26"},
          [{:==, :"$1", @test_record_key}],
          [:"$_"]}
        ])
    end

    test "without results" do
      assert [] == Table.select(@test_table,
        [{{:sell_offer, :"$1", :"$2", :"$3", :"$4", :"$5", :"$6", :"$7", :"$8", :"$9",
           :"$10", :"$11", :"$12", :"$13", :"$14", :"$15", :"$16", :"$17", :"$18",
           :"$19", :"$20", :"$21", :"$22", :"$23", :"$24", :"$25", :"$26"},
          [{:==, :"$1", @test_record_key}],
          [:"$_"]}
        ])
    end

    test "with limit" do
      Table.insert(@test_table, @test_record)
      Table.insert(@test_table, @test_record)
      results = Table.select(@test_table,
        [{{:sell_offer, :"$1", :"$2", :"$3", :"$4", :"$5", :"$6", :"$7", :"$8", :"$9",
           :"$10", :"$11", :"$12", :"$13", :"$14", :"$15", :"$16", :"$17", :"$18",
           :"$19", :"$20", :"$21", :"$22", :"$23", :"$24", :"$25", :"$26"},
          [{:==, :"$1", @test_record_key}],
          [:"$_"]
        }], 1)
      assert 1 == length(results)
      assert [@test_record] == results
    end
  end

  describe "delete record" do
    test "existing" do
      Table.insert(@test_table, @test_record)
      assert {:ok, @test_record_key} = Table.delete(@test_table, @test_record_key)
      assert 0 == :mnesia.table_info(@test_table, :size)
    end

    test "not existing" do
      assert {:ok, @test_record_key} = Table.delete(@test_table, @test_record_key)
      assert 0 == :mnesia.table_info(@test_table, :size)
    end
  end

  describe "update record" do
    test "existing" do
      Table.insert(@test_table, @test_record)

      update = [{1, 345}]
      assert {:ok, _} = Table.update(@test_table, @test_record_key, update)

      assert 345 == @test_table
      |> Table.get(@test_record_key)
      |> elem(2)
    end

    test "existing with nil" do
      Table.insert(@test_table, @test_record)
      update = [{1, nil}]

      assert {:ok, _} = Table.update(@test_table, @test_record_key, update)

      assert nil ==
        @test_table
        |> Table.get(@test_record_key)
        |> elem(2)
    end

    test "not existing" do
      assert {:error, :not_found} == Table.update(@test_table, @test_record_key, [{1, 345}])
    end
  end

  describe "stream" do
    test "with Enum" do
      Table.insert(@test_table, @test_record)
      res = Table.transaction(fn ->
        :sell_offer
        |> Table.Stream.new()
        |> Enum.reduce([], fn so, acc -> [so] ++ acc end)
      end)

      assert 1 == length(res)
    end
  end

  test "count" do
    assert 0 == Table.count(@test_table)
    Table.insert(@test_table, @test_record)
    assert 1 == Table.count(@test_table)
  end

  test "id sequence increment" do
    assert 2 == Table.next_id(@test_table, 2)
    inc_fn = fn -> for _ <- 1..500, do: Table.next_id(@test_table) end

    [inc_fn, inc_fn]
    |> Enum.map(&Task.async/1)
    |> Enum.map(&Task.await/1)

    assert 1_003 == Table.next_id(@test_table)
  end
end
