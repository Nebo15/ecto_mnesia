defmodule Ecto.Mnesia.AdapterTest do
  use ExUnit.Case, async: true
  require Logger
  import Ecto.Query, only: [from: 2]

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

      assert {:ok, res_schema} = schema
      |> TestRepo.insert

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

      assert {:ok, res_schema} = schema
      |> TestRepo.insert

      assert %SellOffer{
        id: 2,
        loan_id: "hello",
        inserted_at: inserted_at,
        updated_at: updated_at
      } = res_schema

      assert inserted_at
      assert updated_at
    end

    test "changeset" do
      changeset = %SellOffer{}
      |> Ecto.Changeset.change([loan_id: "hello"])

      assert {:ok, schema} = changeset
      |> TestRepo.insert

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
      changeset = %SellOffer{}
      |> Ecto.Changeset.change([loan_id: 123])
      |> Ecto.Changeset.validate_required([:income])

      assert {:error, res_changeset} = changeset
      |> TestRepo.insert

      refute [] == res_changeset.errors
    end
  end

  test "insert all" do
    records = [
      [loan_id: "hello", age: 11],
      [loan_id: "hello", age: 15],
      [loan_id: "world", age: 21]
    ]

    assert {3, nil} == TestRepo.insert_all(SellOffer, records)
  end

  describe "update" do
    setup do
      {:ok, loan} = %SellOffer{loan_id: "hello"}
      |> TestRepo.insert

      %{loan: loan}
    end

    test "changeset", %{loan: loan} do
      changeset = loan
      |> Ecto.Changeset.change([loan_id: "world"])

      assert {:ok, schema} = changeset
      |> TestRepo.update

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

    test "invalid changeset" do
      changeset = %SellOffer{}
      |> Ecto.Changeset.change([loan_id: 123])
      |> Ecto.Changeset.validate_required([:income])

      assert {:error, res_changeset} = changeset
      |> TestRepo.insert

      refute [] == res_changeset.errors
    end
  end

  describe "delete" do
    setup do
      {:ok, loan} = %SellOffer{loan_id: "hello"}
      |> TestRepo.insert

      %{loan: loan}
    end

    test "struct", %{loan: loan} do
      assert {:ok, %{id: loan_id}} = loan
      |> TestRepo.delete

      assert loan.id == loan_id
    end

    test "does not exist" do
      {:ok, _} = %SellOffer{loan_id: "hello", id: 123}
      |> TestRepo.delete
    end

    test "changeset", %{loan: loan} do
      changeset = loan
      |> Ecto.Changeset.change([loan_id: "world"])

      assert {:ok, %{id: loan_id}} = changeset
      |> TestRepo.delete

      assert loan.id == loan_id
    end
  end

  describe "delete_all" do
    setup do
      {:ok, loan1} = %SellOffer{loan_id: "hello", age: 11}
      |> TestRepo.insert

      {:ok, loan2} = %SellOffer{loan_id: "hello", age: 15}
      |> TestRepo.insert

      {:ok, loan3} = %SellOffer{loan_id: "world", age: 21}
      |> TestRepo.insert

      %{loan1: loan1, loan2: loan2, loan3: loan3}
    end

    test "by query" do
      assert {2, nil} == TestRepo.delete_all from(so in SellOffer, where: so.age < 20)
      assert 1 == Ecto.Mnesia.Table.count(:sell_offer)
    end

    test "return result" do
      # TODO: Return on delete
      assert {2, _} = TestRepo.delete_all from(so in SellOffer, where: so.age < 20), select: [:id, :age]
      assert 1 == Ecto.Mnesia.Table.count(:sell_offer)
    end

    test "by struct" do
      assert {3, nil} == TestRepo.delete_all(SellOffer)
      assert 0 == Ecto.Mnesia.Table.count(:sell_offer)
    end
  end

  describe "query limit" do
    setup do
      {:ok, loan1} = %SellOffer{loan_id: "hello", age: 11}
      |> TestRepo.insert

      {:ok, loan2} = %SellOffer{loan_id: "hello", age: 15}
      |> TestRepo.insert

      {:ok, loan3} = %SellOffer{loan_id: "world", age: 21}
      |> TestRepo.insert

      %{loan1: loan1, loan2: loan2, loan3: loan3}
    end

    test "limits result" do
      result = TestRepo.all from so in SellOffer,
        limit: 1

      assert 1 == length(result)
    end
  end

  describe "order by" do
    setup do
      {:ok, loan1} = %SellOffer{loan_id: "hello", age: 11}
      |> TestRepo.insert

      {:ok, loan2} = %SellOffer{loan_id: "hello", age: 15}
      |> TestRepo.insert

      {:ok, loan3} = %SellOffer{loan_id: "world", age: 21}
      |> TestRepo.insert

      %{loan1: loan1, loan2: loan2, loan3: loan3}
    end

    test "field", %{loan1: loan1, loan2: loan2, loan3: loan3} do
      [res1, res2, res3] = TestRepo.all from so in SellOffer,
        order_by: so.age

      assert res1.age < res2.age
      assert res2.age < res3.age
      assert loan1.id == res1.id
      assert loan2.id == res2.id
      assert loan3.id == res3.id
    end

    test "field asc", %{loan1: loan1, loan2: loan2, loan3: loan3} do
      [res1, res2, res3] = TestRepo.all from so in SellOffer,
        order_by: [asc: so.age]

      assert res1.age < res2.age
      assert res2.age < res3.age
      assert loan1.id == res1.id
      assert loan2.id == res2.id
      assert loan3.id == res3.id
    end

    test "field desc", %{loan1: loan1, loan2: loan2, loan3: loan3} do
      [res1, res2, res3] = TestRepo.all from so in SellOffer,
        order_by: [desc: so.age]

      assert res1.age > res2.age
      assert res2.age > res3.age
      assert loan1.id == res3.id
      assert loan2.id == res2.id
      assert loan3.id == res1.id
    end
  end
end
