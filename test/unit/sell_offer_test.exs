defmodule SellOfferTest do
  use ExUnit.Case, async: false
  require Logger
  import Ecto.Query

  @sell_offer %{
    loan_id: "my_loan_1",
    trader: "vivus.lv",
    book_value: Decimal.new(100.5),
    book_date: DateTime.utc_now(),
    end_date: DateTime.utc_now(),
    min_price_rate: Decimal.new(1.1345),
    max_shared_apr: Decimal.new(0.15),
    dividable: false,
    guaranteed: true,
    relative_flows: [%{
      date: DateTime.utc_now(),
      amount: Decimal.new(100.5)
    }],
    criteria: %{
      borrower_parameters: %{
        age_group: "18-22",
        income_amount: Decimal.new(1000),
        delinquent_payments: 0,
        max_dpd: 3
      },
      loan_parameters: %{
        product_type: "PDL",
        risk_class: "A",
        risk_subclass: "A",
        duration_group: "ANY",
        currency: "EUR",
        outstanding_principal: Decimal.new(105),
        status: "NEW",
        apr: Decimal.new(36.5),
        extended: false,
        is_additional_withdrawal: false
      }
    }
  }

  test "Select Fields" do
       TestRepo.insert(%SellOffer{age: 10}, [])
       TestRepo.insert(%SellOffer{age: 20}, [])
       query = from  SellOffer,
             select: [:id, :loan_id, :max_shared_apr, :min_price_rate]
       res = TestRepo.all(query, [])
       Logger.info("Res 1: #{inspect res}")
  end

  test "Select All" do
       TestRepo.insert(%SellOffer{age: 30},[])
       TestRepo.insert(%SellOffer{age: 40},[])
       query = from so in SellOffer,
            select: so
       res = TestRepo.all(query, [])
       Logger.info("Res 2: #{inspect res}")
  end

  test "Match Against Buy Offers" do

       # SO is Matching Against
       so = %{age: 26, income: 100.0, dpc: 20, dpd: 30, loan_risk_class: "AB",
                             trader_id: "123", loan_duration: 100, loan_product_type: "100",
                             loan_status: "ok", loan_is_prolonged: true, guaranteed: true}

       # BO template for data population
       bo = %BuyOffer{ port_id: "12", income: 1000.0, age: 12, dpc: 21, dpd: 31,
                             loan_originators: "123", loan_risk_class: "AB", loan_product_type: "100",
                             loan_status: "ok", loan_is_prolonged: true,
                             id: Ecto.Mnesia.Adapter.next_id(:buy_offer,1), guaranteed: true}

       TestRepo.insert(%{bo | income: 1000.0, age: 12}, [])
       TestRepo.insert(%{bo | income: 2000.0, age: 27}, [])
       TestRepo.insert(%{bo | income: 3000.0, age: 28}, [])

       query =   from   bo in BuyOffer,
                select: bo,
                where:  bo.income > ^so.income and # roll out in insert
                        ^so.age < bo.age and # roll out in insert
                        ^so.dpc < bo.dpc and
                        ^so.dpd < bo.dpd and
                        ^so.trader_id == bo.loan_originators and # roll out in insert
                        ^so.loan_risk_class == bo.loan_risk_class and
                        ^so.loan_duration < bo.loan_duration and
                        ^so.loan_product_type == bo.loan_product_type and
                        ^(so.loan_status) == bo.loan_status and # roll out in insert
                        ^(so.loan_is_prolonged) == bo.loan_is_prolonged and
                        ^so.guaranteed == bo.guaranteed

       Logger.info("Query: #{inspect query}")

       res = TestRepo.all(query)

       Logger.info("Res 3: #{inspect res}")
  end

  test "Join Query" do
       TestRepo.insert(%SellOffer{age: 10},[])
       TestRepo.insert(%BuyOffer {port_id: "12"}, [])
       TestRepo.insert(%BuyOffer {port_id: "13"}, [])
       query = from  bo in BuyOffer,
               join: so in SellOffer,
             select: bo
#       res = TestRepo.all(query, [])
#       Logger.info("Res 4: #{inspect res}")
  end

end
