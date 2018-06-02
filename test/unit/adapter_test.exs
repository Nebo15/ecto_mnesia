defmodule EctoMnesia.AdapterTest do
  use ExUnit.Case
  require Logger
  import Ecto.Query, only: [from: 2]
  alias Ecto.Changeset
  alias EctoMnesia.Table

  setup do
    :mnesia.clear_table(:sell_offer)
    :mnesia.clear_table(:id_seq)
    :ok
  end

  describe "insert" do
    test "schema" do
      schema = %SellOffer{
        loan_id: "hello"
      }

      assert {:ok, res_schema} = TestRepo.insert(schema)

      assert %SellOffer{
        id: id,
        loan_id: "hello",
        inserted_at: inserted_at,
        updated_at: updated_at
      } = res_schema

      assert id
      assert inserted_at
      assert updated_at
    end

    test "schema with id" do
      schema = %SellOffer{
        id: 2,
        loan_id: "hello"
      }

      assert {:ok, res_schema} = TestRepo.insert(schema)

      assert %SellOffer{
        id: 2,
        loan_id: "hello",
        inserted_at: inserted_at,
        updated_at: updated_at
      } = res_schema

      assert inserted_at
      assert updated_at
    end

    test "duplicate record" do
      schema = %SellOffer{
        id: 2,
        loan_id: "hello"
      }

      assert {:ok, _res_schema} = TestRepo.insert(schema)

      assert_raise Ecto.ConstraintError, fn ->
        TestRepo.insert(schema)
      end
    end

    test "changeset" do
      changeset = Changeset.change(%SellOffer{}, [loan_id: "hello"])

      assert {:ok, schema} = TestRepo.insert(changeset)

      assert %SellOffer{
        id: id,
        loan_id: "hello",
        inserted_at: inserted_at,
        updated_at: updated_at
      } = schema

      assert id
      assert inserted_at
      assert updated_at
    end

    test "invalid changeset" do
      changeset =
        %SellOffer{}
        |> Changeset.change([loan_id: 123])
        |> Changeset.validate_required([:income])

      assert {:error, res_changeset} = TestRepo.insert(changeset)

      refute [] == res_changeset.errors
    end
  end

  describe "insert_all" do
    test "multiple records" do
      records = [
        [loan_id: "hello", age: 11],
        [loan_id: "hello", age: 15],
        [loan_id: "world", age: 21]
      ]

      assert {3, nil} == TestRepo.insert_all(SellOffer, records)
    end

    test "duplicate records" do
      records = [
        [id: 1, loan_id: "hello", age: 11],
        [id: 1, loan_id: "hello", age: 15]
      ]

      assert {0, nil} == TestRepo.insert_all(SellOffer, records)
    end

    # test "insert all with return" do
    #   records = [
    #     [loan_id: "hello", age: 11],
    #     [loan_id: "hello", age: 15],
    #     [loan_id: "world", age: 21]
    #   ]

    #   assert {3, nil} == TestRepo.insert_all(SellOffer, records, returning: true)
    # end
  end

  describe "update" do
    setup do
      {:ok, loan} =
        TestRepo.insert(%SellOffer{loan_id: "hello", loan_changes: ["old_application"], age: 11})

      %{loan: loan}
    end

    test "changeset", %{loan: loan} do
      changeset = Changeset.change(loan, [loan_id: "world"])

      assert {:ok, schema} = TestRepo.update(changeset)

      assert %SellOffer{
        id: id,
        loan_id: "world",
        inserted_at: inserted_at,
        updated_at: updated_at
      } = schema

      assert loan.id == id
      assert inserted_at
      assert loan.updated_at != updated_at
      assert updated_at > loan.updated_at
    end

    test "with nil value", %{loan: loan} do
      changeset = Changeset.change(loan, [age: nil])

      assert {:ok, schema} = TestRepo.update(changeset)

      assert %SellOffer{
        id: id,
        age: nil,
        inserted_at: inserted_at,
        updated_at: updated_at
      } = schema

      assert loan.id == id
      assert inserted_at
      assert loan.updated_at != updated_at
      assert updated_at > loan.updated_at

      query = from so in SellOffer, where: so.id == ^loan.id
      assert %SellOffer{age: nil} = TestRepo.one(query)
    end

    test "invalid changeset" do
      changeset =
        %SellOffer{}
        |> Changeset.change([loan_id: 123])
        |> Changeset.validate_required([:income])

      assert {:error, res_changeset} = TestRepo.insert(changeset)

      refute [] == res_changeset.errors
    end

    test "with :push" do
      query = from so in SellOffer, update: [push: [loan_changes: "new_application"]]

      assert {1, nil} == TestRepo.update_all(query, [])
      assert [%SellOffer{loan_changes: ["old_application", "new_application"]}] = TestRepo.all(SellOffer)
    end

    test "with :pull" do
      query = from so in SellOffer, update: [pull: [loan_changes: "old_application"]]

      assert {1, nil} == TestRepo.update_all(query, [])
      assert [%SellOffer{loan_changes: []}] = TestRepo.all(SellOffer)
    end
  end

  describe "select" do
    setup do
      {:ok, loan1} =
        TestRepo.insert(%SellOffer{loan_id: "hello", age: 11, loan_changes: ["old_application", "new_application"]})
      {:ok, loan2} =
        TestRepo.insert(%SellOffer{loan_id: "hello", age: 15})

      %{loan1: loan1, loan2: loan2}
    end

    test "query by id", %{loan1: loan1} do
      query = from so in SellOffer, where: so.id == ^loan1.id
      assert [%SellOffer{id: loan_id}] = TestRepo.all(query)
      assert loan1.id == loan_id
    end

    test "all by schema" do
      results = SellOffer |> TestRepo.all()
      assert 2 == length(results)
    end

    test "get_by/2", %{loan2: loan2} do
      assert %SellOffer{id: loan_id} = TestRepo.get_by(SellOffer, [id: loan2.id])
      assert loan2.id == loan_id
    end

    test "where item is in array" do
      change = "new_application"

      assert_raise RuntimeError, "Complex :in queries is not supported by the Mnesia adapter.", fn ->
        TestRepo.all from(so in SellOffer, where: ^change in so.loan_changes)
      end
    end

    test "structured" do
      assert [%SellOffer{} | _] =
        TestRepo.all from(so in SellOffer, select: so)

      assert ["hello", "hello"] ==
        TestRepo.all from(so in SellOffer, select: so.loan_id)

      assert [["hello", 11], ["hello", 15]] ==
        TestRepo.all from(so in SellOffer, select: [so.loan_id, so.age])

      assert [{"hello", 11}, {"hello", 15}] ==
        TestRepo.all from(so in SellOffer, select: {so.loan_id, so.age})

      assert [{"hello", "42", 43}, {"hello", "42", 43}] ==
        TestRepo.all from(so in SellOffer, select: {so.loan_id, ^to_string(40 + 2), 43})

      assert [%{answer: 42, n: "hello"}, %{answer: 42, n: "hello"}] ==
        TestRepo.all from(so in SellOffer, select: %{n: so.loan_id, answer: 42})
    end
  end

  describe "update_all" do
    setup do
      {:ok, loan1} = TestRepo.insert(%SellOffer{loan_id: "hello", age: 11})
      {:ok, loan2} = TestRepo.insert(%SellOffer{loan_id: "hello", age: 15})
      {:ok, loan3} = TestRepo.insert(%SellOffer{loan_id: "world", age: 21})

      %{loan1: loan1, loan2: loan2, loan3: loan3}
    end

    test "by query" do
      query = from so in SellOffer, update: [set: [status: "updated", guaranteed: true], inc: [age: 1]]

      assert {3, nil} == TestRepo.update_all(query, [])
      assert 3 == Table.count(:sell_offer)
      assert [
        %SellOffer{status: "updated", guaranteed: true, age: age1},
        %SellOffer{status: "updated", guaranteed: true, age: age2},
        %SellOffer{status: "updated", guaranteed: true, age: age3}] = TestRepo.all(SellOffer)

      assert age1 in [12, 16, 22]
      assert age2 in [12, 16, 22]
      assert age3 in [12, 16, 22]
    end

    test "with returning" do
      query = from so in SellOffer, update: [set: [status: "updated", guaranteed: true], inc: [age: 1]]

      assert {3, [%SellOffer{}, %SellOffer{}, %SellOffer{}]} = query |> TestRepo.update_all([], returning: true)
    end

    test "by struct" do
      assert {3, nil} == TestRepo.update_all SellOffer, set: [status: "updated", guaranteed: true], inc: [age: 1]
      assert 3 == Table.count(:sell_offer)
      assert [
        %SellOffer{status: "updated", guaranteed: true, age: age1},
        %SellOffer{status: "updated", guaranteed: true, age: age2},
        %SellOffer{status: "updated", guaranteed: true, age: age3}] = TestRepo.all(SellOffer)

      assert age1 in [12, 16, 22]
      assert age2 in [12, 16, 22]
      assert age3 in [12, 16, 22]
    end
  end

  describe "delete" do
    setup do
      {:ok, loan} = TestRepo.insert %SellOffer{loan_id: "hello"}

      %{loan: loan}
    end

    test "struct", %{loan: loan} do
      assert {:ok, %{id: loan_id}} = TestRepo.delete(loan)
      assert loan.id == loan_id
    end

    test "does not exist" do
      {:ok, _} = TestRepo.delete(%SellOffer{loan_id: "hello", id: 123})
    end

    test "changeset", %{loan: loan} do
      changeset = Changeset.change(loan, [loan_id: "world"])
      assert {:ok, %{id: loan_id}} = TestRepo.delete(changeset)
      assert loan.id == loan_id
    end
  end

  describe "delete_all" do
    setup do
      {:ok, loan1} = TestRepo.insert(%SellOffer{loan_id: "hello", age: 11})
      {:ok, loan2} = TestRepo.insert(%SellOffer{loan_id: "hello", age: 15})
      {:ok, loan3} = TestRepo.insert(%SellOffer{loan_id: "world", age: 21})

      %{loan1: loan1, loan2: loan2, loan3: loan3}
    end

    test "by query" do
      assert {2, nil} == TestRepo.delete_all from(so in SellOffer, where: so.age < 20)
      assert 1 == Table.count(:sell_offer)
    end

    test "return result" do
      # TODO: Return on delete
      assert {2, _} = TestRepo.delete_all from(so in SellOffer, where: so.age < 20), select: [:id, :age]
      assert 1 == Table.count(:sell_offer)
    end

    test "by struct" do
      assert {3, nil} == TestRepo.delete_all(SellOffer)
      assert 0 == Table.count(:sell_offer)
    end
  end

  describe "supports embeds" do
    setup do
      {:ok, loan1} =
        TestRepo.insert(%SellOffer{loan_id: "hello", age: 11, application: %SellOffer.Application{name: "John"}})

      %{loan1: loan1}
    end

    test "limits result" do
      result = TestRepo.all from so in SellOffer, limit: 1

      # TODO: reconstruct SellOffer.Application struct
      assert [%SellOffer{application: %{name: "John"}}] = result
      assert 1 == length(result)
    end
  end

  describe "query limit" do
    setup do
      {:ok, loan1} = TestRepo.insert(%SellOffer{loan_id: "hello", age: 11})
      {:ok, loan2} = TestRepo.insert(%SellOffer{loan_id: "hello", age: 15})
      {:ok, loan3} = TestRepo.insert(%SellOffer{loan_id: "world", age: 21})

      %{loan1: loan1, loan2: loan2, loan3: loan3}
    end

    test "limits result" do
      result = TestRepo.all from so in SellOffer, limit: 1
      assert 1 == length(result)
    end
  end

  test "stream is not supported" do
    assert_raise ArgumentError, "stream/6 is not supported by adapter, use EctoMnesia.Table.Stream.new/2 instead",
      fn ->
        TestRepo.stream SellOffer
      end
  end

  describe "order by" do
    setup do
      {:ok, loan1} = TestRepo.insert(%SellOffer{loan_id: "hello", age: 11})
      {:ok, loan2} = TestRepo.insert(%SellOffer{loan_id: "hello", age: 15})
      {:ok, loan3} = TestRepo.insert(%SellOffer{loan_id: "world", age: 21})

      %{loan1: loan1, loan2: loan2, loan3: loan3}
    end

    test "multiple rules" do
      [res1, res2, res3] =
        TestRepo.all from so in SellOffer,
          order_by: [asc: so.loan_id, asc: so.age]

      [^res1, ^res2, ^res3] =
        TestRepo.all from so in SellOffer,
          order_by: [so.loan_id, so.age],
          order_by: [so.loan_id, so.age]
    end

    test "field", %{loan1: loan1, loan2: loan2, loan3: loan3} do
      [res1, res2, res3] =
        TestRepo.all from so in SellOffer,
          order_by: [asc: so.loan_id, asc: so.age]

      assert res1.age < res2.age
      assert res2.age < res3.age
      assert loan1.id == res1.id
      assert loan2.id == res2.id
      assert loan3.id == res3.id
    end

    test "field asc", %{loan1: loan1, loan2: loan2, loan3: loan3} do
      [res1, res2, res3] =
        TestRepo.all from so in SellOffer,
          order_by: [asc: so.age]

      assert res1.age < res2.age
      assert res2.age < res3.age
      assert loan1.id == res1.id
      assert loan2.id == res2.id
      assert loan3.id == res3.id
    end

    test "field desc", %{loan1: loan1, loan2: loan2, loan3: loan3} do
      [res1, res2, res3] =
        TestRepo.all from so in SellOffer,
          order_by: [desc: so.age]

      assert res1.age > res2.age
      assert res2.age > res3.age
      assert loan1.id == res3.id
      assert loan2.id == res2.id
      assert loan3.id == res1.id
    end

    test "ordering with duplicated values" do
      result =
        TestRepo.all from so in SellOffer,
          order_by: [desc: so.loan_id]

      assert Enum.map(result, & &1.loan_id) == ["world", "hello", "hello"]
    end
  end
end
