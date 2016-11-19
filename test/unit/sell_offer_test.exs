defmodule SellOfferTest do
  use ExUnit.Case, async: true
  require Logger
  import Ecto.Query

  setup_all do
    TestRepo.insert(%SellOffer{
      age: 26,
      loan_id: "loan-007",
      income: 1000.0, dpc: 20, dpd: 30, loan_risk_class: "AB",
      trader_id: 123, loan_duration: 100, loan_product_type: "100",
      max_shared_apr: Decimal.new(9.23), loan_status: "ok",
      loan_is_prolonged: true, guaranteed: true
    })

    TestRepo.insert(%SellOffer{
      age: 23,
      loan_id: "loan-008"
    })

    :ok
  end

  describe "schema selector" do
    test "select all" do
      [rec1, rec2] = result = TestRepo.all(SellOffer)

      assert 2 == length(result)
      assert %SellOffer{
        age: 26,
        loan_id: "loan-007",
        income: 1000.0,
        dpc: 20,
        dpd: 30,
        loan_risk_class: "AB",
        trader_id: 123,
        loan_duration: 100,
        loan_product_type: "100",
        max_shared_apr: 9.23,
        loan_status: "ok",
        loan_is_prolonged: true,
        guaranteed: true,
        min_price_rate: nil
      } = rec1

      assert %SellOffer{
        age: 23,
        loan_id: "loan-008",
        max_shared_apr: nil,
        min_price_rate: nil
      } = rec2
    end
  end

  describe "query selector" do
    test "select all" do
      [rec1, rec2] = result = TestRepo.all from SellOffer

      assert 2 == length(result)
      assert %SellOffer{
        age: 26,
        loan_id: "loan-007",
        income: 1000.0,
        dpc: 20,
        dpd: 30,
        loan_risk_class: "AB",
        trader_id: 123,
        loan_duration: 100,
        loan_product_type: "100",
        max_shared_apr: 9.23,
        loan_status: "ok",
        loan_is_prolonged: true,
        guaranteed: true,
        min_price_rate: nil
      } = rec1

      assert %SellOffer{
        age: 23,
        loan_id: "loan-008",
        max_shared_apr: nil,
        min_price_rate: nil
      } = rec2
    end

    test "select by fields list" do
      [rec1, rec2] = result = TestRepo.all from SellOffer,
        select: [:id, :loan_id, :max_shared_apr, :min_price_rate]

      assert 2 == length(result)
      assert %SellOffer{
        loan_id: "loan-007",
        max_shared_apr: 9.23,
        min_price_rate: nil
      } = rec1

      assert %SellOffer{
        loan_id: "loan-008",
        max_shared_apr: nil,
        min_price_rate: nil
      } = rec2
    end
  end

  describe "query wheres" do
    # test "with binded variable" do
    #   binded_age = 26

    #   [result] = TestRepo.all from so in SellOffer,
    #     select: so,
    #     where: so.age == ^binded_age

    #   assert %SellOffer{
    #     loan_id: "loan-007",
    #     max_shared_apr: 9.23,
    #     min_price_rate: nil
    #   } = result
    # end

    test "with `>`" do
      [result] = TestRepo.all from so in SellOffer,
        select: so,
        where: so.age > 25

      assert %SellOffer{
        loan_id: "loan-007",
        max_shared_apr: 9.23,
        min_price_rate: nil
      } = result
    end

    test "with `<`" do
      [result] = TestRepo.all from so in SellOffer,
        select: so,
        where: so.age < 25

      assert %SellOffer{
        loan_id: "loan-008"
      } = result
    end

    test "with `>=`" do
      [result] = TestRepo.all from so in SellOffer,
        select: so,
        where: so.age >= 26

      assert %SellOffer{
        loan_id: "loan-007",
        max_shared_apr: 9.23,
        min_price_rate: nil
      } = result
    end

    test "with `<=`" do
      [result] = TestRepo.all from so in SellOffer,
        select: so,
        where: so.age <= 23

      assert %SellOffer{
        loan_id: "loan-008"
      } = result
    end

    test "with `==`" do
      [result] = TestRepo.all from so in SellOffer,
        select: so,
        where: so.age == 26

      assert %SellOffer{
        loan_id: "loan-007",
        max_shared_apr: 9.23,
        min_price_rate: nil
      } = result
    end

   test "with `!=`" do
      [result] = TestRepo.all from so in SellOffer,
        select: so,
        where: so.age != 26

      assert %SellOffer{
        loan_id: "loan-008"
      } = result
    end

    test "with `and`" do
      [result] = TestRepo.all from so in SellOffer,
        select: so,
        where: so.age != 26 and so.age != 21

      assert %SellOffer{
        loan_id: "loan-008"
      } = result
    end

    test "with `or`" do
      [rec1,rec2] = TestRepo.all from so in SellOffer,
        select: so,
        where: so.age != 26 or so.age != 21

      assert %SellOffer{
        loan_id: "loan-007"
      } = rec1

      assert %SellOffer{
        loan_id: "loan-008"
      } = rec2
    end

    test "with `not`" do
      [result] = TestRepo.all from so in SellOffer,
        select: so,
        where: not (so.age == 26)

      assert %SellOffer{
        loan_id: "loan-008"
      } = result
    end

    test "with `or`, `and` and `(..)`" do
      [result] = TestRepo.all from so in SellOffer,
        select: so,
        where: (so.age != 26 or so.age != 21) and so.age != 23

      assert %SellOffer{
        loan_id: "loan-007"
      } = result

      result = TestRepo.all from so in SellOffer,
        select: so,
        where: so.age != 26 or (so.age != 21 and so.age != 23)

      assert 2 == length(result)
    end

    test "with `in`" do
      [rec1, rec2] = TestRepo.all from so in SellOffer,
        select: so,
        where: so.age in [23, 26]

      assert %SellOffer{
        loan_id: "loan-007"
      } = rec1

      assert %SellOffer{
        loan_id: "loan-008"
      } = rec2
    end

    test "with `is_nil`" do
      result = TestRepo.all from so in SellOffer,
        select: so,
        where: is_nil(so.min_price_rate)

      assert 2 == length(result)
    end
  end

  describe "query limit" do
    test "limits result" do
      result = TestRepo.all from so in SellOffer,
        limit: 1

      assert 1 == length(result)
    end
  end

  describe "order by" do
    test "field" do
      [rec1, rec2] = TestRepo.all from so in SellOffer,
        order_by: so.age

      assert rec1.age > rec2.age
    end

    test "field asc" do
      [rec1, rec2] = TestRepo.all from so in SellOffer,
        order_by: [asc: so.age]

      assert rec1.age > rec2.age
    end

    test "field desc" do
      [rec1, rec2] = TestRepo.all from so in SellOffer,
        order_by: [desc: so.age]

      assert rec1.age < rec2.age
    end
  end

  describe "delete" do
    test "by id" do
      # %{id: id} = TestRepo.insert(%SellOffer{loan_id: "loan-009"})
      # IO.inspect id

      # TestRepo.delete(SellOffer, id)
    end
  end
end
