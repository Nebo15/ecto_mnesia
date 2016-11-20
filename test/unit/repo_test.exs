defmodule Ecto.RepoTest do
  use ExUnit.Case, async: true

  import Ecto.Query
  # import Ecto, only: [put_meta: 2]

  test "needs schema with primary key field" do
    schema = %MySchemaNoPK{x: "abc"}

    assert_raise Ecto.NoPrimaryKeyFieldError, fn ->
      TestRepo.update!(schema |> Ecto.Changeset.change, force: true)
    end

    assert_raise Ecto.NoPrimaryKeyFieldError, fn ->
      TestRepo.delete!(schema)
    end
  end

  # test "works with unknown schema" do
  #   TestRepo.get(MySchema, 123) # TODO: MySchema does not exist
  # end

  test "works with primary key value" do
    TestRepo.get(SellOffer, 11111)
    TestRepo.get(SellOffer, 123)
    TestRepo.get_by(SellOffer, loan_id: "abc")

    # schema = %SellOffer{id: 1, loan_id: "abc"}
    # TestRepo.update!(schema |> Ecto.Changeset.change(), force: true)
    # TestRepo.delete!(schema)
  end

  # test "works with custom source schema" do
  #   schema = %SellOffer{id: 1, loan_id: "abc"} |> put_meta(source: "custom_schema")
  #   TestRepo.update!(schema |> Ecto.Changeset.change, force: true)
  #   TestRepo.delete!(schema)

  #   to_insert = %SellOffer{loan_id: "abc"} |> put_meta(source: "custom_schema")
  #   TestRepo.insert!(to_insert)
  # end

  test "fails without primary key value" do
    schema = %SellOffer{loan_id: "abc"}

    assert_raise Ecto.NoPrimaryKeyValueError, fn ->
      TestRepo.update!(schema |> Ecto.Changeset.change, force: true)
    end

    assert_raise Ecto.NoPrimaryKeyValueError, fn ->
      TestRepo.delete!(schema)
    end
  end

  test "validates schema types" do
    schema = %SellOffer{loan_id: 123}

    assert_raise Ecto.ChangeError, fn ->
      TestRepo.insert!(schema)
    end
  end

  test "validates get" do
    TestRepo.get(SellOffer, 123)

    message = "cannot perform TestRepo.get/2 because the given value is nil"
    assert_raise ArgumentError, message, fn ->
      TestRepo.get(SellOffer, nil)
    end

    message = ~r"value `:atom` in `where` cannot be cast to type :id in query"
    assert_raise Ecto.Query.CastError, message, fn ->
      TestRepo.get(SellOffer, :atom)
    end

    message = ~r"expected a from expression with a schema in query"
    assert_raise Ecto.QueryError, message, fn ->
      TestRepo.get(%Ecto.Query{}, :atom)
    end
  end

  test "validates get_by" do
    TestRepo.get_by(SellOffer, id: 123)
    TestRepo.get_by(SellOffer, %{id: 123})

    message = ~r"value `:atom` in `where` cannot be cast to type :id in query"
    assert_raise Ecto.Query.CastError, message, fn ->
      TestRepo.get_by(SellOffer, id: :atom)
    end
  end

  # test "validates update_all" do
  #   # Success
  #   TestRepo.update_all(SellOffer, set: [loan_id: "321"])

  #   query = from(e in SellOffer, where: e.x == "123", update: [set: [loan_id: "321"]])
  #   TestRepo.update_all(query, [])

  #   # Failures
  #   assert_raise ArgumentError, ~r/:returning expects at least one field to be given/, fn ->
  #     TestRepo.update_all SellOffer, [set: [loan_id: "321"]], returning: []
  #   end

  #   assert_raise Ecto.QueryError, fn ->
  #     TestRepo.update_all from(e in SellOffer, select: e), set: [loan_id: "321"]
  #   end

  #   assert_raise Ecto.QueryError, fn ->
  #     TestRepo.update_all from(e in SellOffer, order_bstatus: e.x), set: [loan_id: "321"]
  #   end
  # end

  test "validates delete_all" do
    # Success
    TestRepo.delete_all(SellOffer)

    query = from(e in SellOffer, where: e.status == "123")
    TestRepo.delete_all(query)

    # Failures
    assert_raise ArgumentError, ~r/:returning expects at least one field to be given/, fn ->
      TestRepo.delete_all SellOffer, returning: []
    end

    assert_raise Ecto.QueryError, fn ->
      TestRepo.delete_all from(e in SellOffer, select: e)
    end

    assert_raise Ecto.QueryError, fn ->
      TestRepo.delete_all from(e in SellOffer, order_by: e.status)
    end
  end

  # ## Changesets

  test "insert, update, insert_or_update and delete accepts changesets" do
    valid = Ecto.Changeset.cast(%SellOffer{id: 1}, %{}, [])
    assert {:ok, %SellOffer{}} = TestRepo.insert(valid)
    assert {:ok, %SellOffer{}} = TestRepo.update(valid)
    assert {:ok, %SellOffer{}} = TestRepo.insert_or_update(valid)
    assert {:ok, %SellOffer{}} = TestRepo.delete(valid)
  end

  test "insert, update, insert_or_update and delete errors on invalid changeset" do
    invalid = %Ecto.Changeset{valid?: false, data: %SellOffer{}}

    insert = %{invalid | action: :insert, repo: TestRepo}
    assert {:error, ^insert} = TestRepo.insert(invalid)

    update = %{invalid | action: :update, repo: TestRepo}
    assert {:error, ^update} = TestRepo.update(invalid)

    update = %{invalid | action: :insert, repo: TestRepo}
    assert {:error, ^update} = TestRepo.insert_or_update(invalid)

    delete = %{invalid | action: :delete, repo: TestRepo}
    assert {:error, ^delete} = TestRepo.delete(invalid)
  end

  test "insert!, update! and delete! accepts changesets" do
    valid = Ecto.Changeset.cast(%SellOffer{id: 1}, %{}, [])
    assert %SellOffer{} = TestRepo.insert!(valid)
    assert %SellOffer{} = TestRepo.update!(valid)
    assert %SellOffer{} = TestRepo.insert_or_update!(valid)
    assert %SellOffer{} = TestRepo.delete!(valid)
  end

  test "insert!, update!, insert_or_update! and delete! fail on invalid changeset" do
    invalid = %Ecto.Changeset{valid?: false, data: %SellOffer{}}

    assert_raise Ecto.InvalidChangesetError,
                 ~r"could not perform insert because changeset is invalid", fn ->
      TestRepo.insert!(invalid)
    end

    assert_raise Ecto.InvalidChangesetError,
                 ~r"could not perform update because changeset is invalid", fn ->
      TestRepo.update!(invalid)
    end

    assert_raise Ecto.InvalidChangesetError,
                 ~r"could not perform insert because changeset is invalid", fn ->
      TestRepo.insert_or_update!(invalid)
    end

    assert_raise Ecto.InvalidChangesetError,
                 ~r"could not perform delete because changeset is invalid", fn ->
      TestRepo.delete!(invalid)
    end
  end

  test "insert!, update! and delete! fail on changeset without data" do
    invalid = %Ecto.Changeset{valid?: true, data: nil}

    assert_raise ArgumentError, "cannot insert a changeset without :data", fn ->
      TestRepo.insert!(invalid)
    end

    assert_raise ArgumentError, "cannot update a changeset without :data", fn ->
      TestRepo.update!(invalid)
    end

    assert_raise ArgumentError, "cannot delete a changeset without :data", fn ->
      TestRepo.delete!(invalid)
    end
  end

  test "insert!, update!, insert_or_update! and delete! fail on changeset with wrong action" do
    invalid = %Ecto.Changeset{valid?: true, data: %SellOffer{}, action: :other}

    assert_raise ArgumentError, "a changeset with action :other was given to TestRepo.insert/2", fn ->
      TestRepo.insert!(invalid)
    end

    assert_raise ArgumentError, "a changeset with action :other was given to TestRepo.update/2", fn ->
      TestRepo.update!(invalid)
    end

    assert_raise ArgumentError, "a changeset with action :other was given to TestRepo.insert/2", fn ->
      TestRepo.insert_or_update!(invalid)
    end

    assert_raise ArgumentError, "a changeset with action :other was given to TestRepo.delete/2", fn ->
      TestRepo.delete!(invalid)
    end
  end

  test "insert_or_update fails on invalid states" do
    deleted =
      %SellOffer{status: "deleted"}
      |> TestRepo.insert!
      |> TestRepo.delete!
      |> Ecto.Changeset.cast(%{status: "updated"}, [:status])

    assert_raise ArgumentError, ~r/the changeset has an invalid state/, fn ->
      TestRepo.insert_or_update deleted
    end
  end

  test "insert_or_update fails when being passed a struct" do
    assert_raise ArgumentError, ~r/giving a struct to .* is not supported/, fn ->
      TestRepo.insert_or_update %SellOffer{}
    end
  end

  # defp prepare_changeset() do
  #   %SellOffer{id: 1}
  #   |> Ecto.Changeset.cast(%{loan_id: "one"}, [:x])
  #   |> Ecto.Changeset.prepare_changes(fn %{repo: repo} = changeset ->
  #         Process.put(:ecto_repo, repo)
  #         Process.put(:ecto_counter, 1)
  #         changeset
  #       end)
  #   |> Ecto.Changeset.prepare_changes(fn changeset ->
  #         Process.put(:ecto_counter, 2)
  #         changeset
  #       end)
  # end

  describe "changeset constraints" do
    # test "are mapped to repo constraint violations" do
    #   my_schema = %SellOffer{id: 1}
    #   changeset =
    #     put_in(my_schema.__meta__.context, {:invalid, [unique: "custom_loan_id_index"]})
    #     |> Ecto.Changeset.change(loan_id: "foo")
    #     |> Ecto.Changeset.unique_constraint(:loan_id, name: "custom_foo_index")
    #   assert {:error, changeset} = TestRepo.insert(changeset)
    #   refute changeset.valid?
    # end

    # test "are mapped to repo constraint violation using suffix match" do
    #   my_schema = %SellOffer{id: 1}
    #   changeset =
    #     put_in(my_schema.__meta__.context, {:invalid, [unique: "foo_table_custom_foo_index"]})
    #     |> Ecto.Changeset.change(loan_id: "foo")
    #     |> Ecto.Changeset.unique_constraint(:foo, name: "custom_foo_index", match: :suffix)
    #   assert {:error, changeset} = TestRepo.insert(changeset)
    #   refute changeset.valid?
    # end

    # test "may fail to map to repo constraint violation on name" do
    #   my_schema = %SellOffer{id: 1}
    #   changeset =
    #     put_in(my_schema.__meta__.context, {:invalid, [unique: "foo_table_custom_foo_index"]})
    #     |> Ecto.Changeset.change(loan_id: "foo")
    #     |> Ecto.Changeset.unique_constraint(:foo, name: "custom_foo_index")
    #   assert_raise Ecto.ConstraintError, fn ->
    #     TestRepo.insert(changeset)
    #   end
    # end

    # test "may fail to map to repo constraint violation on index type" do
    #   my_schema = %SellOffer{id: 1}
    #   changeset =
    #     put_in(my_schema.__meta__.context, {:invalid, [invalid_constraint_type: "my_schema_foo_index"]})
    #     |> Ecto.Changeset.change(loan_id: "foo")
    #     |> Ecto.Changeset.unique_constraint(:foo)
    #   assert_raise Ecto.ConstraintError, fn ->
    #     TestRepo.insert(changeset)
    #   end
    # end
  end

  describe "on conflict" do
    test "raises on unknown on_conflict value" do
      assert_raise ArgumentError, "unknown value for :on_conflict, got: :who_knows", fn ->
        TestRepo.insert(%SellOffer{id: 1}, on_conflict: :who_knows)
      end
    end

    test "raises on non-empty conflict_target with on_conflict raise" do
      assert_raise ArgumentError, ":conflict_target option is forbidden when :on_conflict is :raise", fn ->
        TestRepo.insert(%SellOffer{id: 1}, on_conflict: :raise, conflict_target: :oops)
      end
    end

    test "raises on query mismatch" do
      assert_raise ArgumentError, ~r"cannot run on_conflict: query", fn ->
        query = from p in "posts"
        TestRepo.insert(%SellOffer{id: 1}, on_conflict: query)
      end
    end
  end
end
