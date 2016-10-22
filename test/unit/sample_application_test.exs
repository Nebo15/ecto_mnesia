defmodule SampleApplicationTest do
  use ExUnit.Case, async: false
  require Logger
  import Ecto.Query

  defmodule SellOffer do
    use Ecto.Schema

    schema "sell_offer" do
      # @primary_key {:id, :integer, autogenerate: true}
      field :trader_id, :integer
      field :loan_id, :integer
      field :book_value, :integer
      field :min_price_rate, :decimal
      field :max_shared_apr, :decimal
      field :dividable, :boolean
      field :guaranteed, :boolean
      field :status, :string
      field :booked_at, Ecto.DateTime
      field :ended_at, Ecto.DateTime
      field :created_at, Ecto.DateTime
      field :updated_at, Ecto.DateTime
      field :age, :integer
      field :income, :decimal
      field :dpc, :integer
      field :dpd, :integer
      field :loan_risk_class, :string
      field :loan_risk_subclass, :string
      field :loan_duration, :integer
      field :loan_product_type, :string
      field :loan_currency, :string
      field :loan_oap, :decimal
      field :loan_status, :string
      field :loan_apr, :decimal
      field :loan_is_prolonged, :boolean
    end
  end

  defmodule BuyOffer do
      use Ecto.Schema

      schema "buy_offer" do
        @primary_key {:id, :integer, autogenerate: true}
        field :trader_id, :string
        field :port_id, :string
        field :started_at, Ecto.DateTime
        field :ended_at, Ecto.DateTime
        field :volume, :decimal
        field :apr, :decimal
        field :intermediary_apr, :decimal
        field :loan_invest_whole, :boolean
        field :loan_investment_max, :decimal
        field :loan_investment_min, :decimal
        field :guaranted, :binary
        field :etc, :binary
        field :ages, {:array, :integer}
        field :incomes, {:array, :decimal}
        field :dpcs, :integer
        field :dpds, :integer
        field :loan_risk_class, :string
        field :loan_risk_subclass, :string
        field :loan_duration, :integer
        field :loan_product_type, :string
        field :loan_currencies, :string
        field :loan_originators, :string
        field :loan_oap, :decimal
        field :loan_status, :string
        field :loan_apr, :decimal
        field :loan_is_prolonged, :boolean
     end
  end


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
       TestRepo.insert(%SellOffer{age: 30, id: Ecto.Mnesia.Adapter.next_id(:sell_offer,1)},[])
       TestRepo.insert(%SellOffer{age: 40, id: Ecto.Mnesia.Adapter.next_id(:sell_offer,1)},[])
       query = from so in SellOffer,
            select: so
       res = TestRepo.all(query, [])
       Logger.info("Res 2: #{inspect res}")
  end

  test "And Query" do
       query =   from  bo in BuyOffer,
                 join: so in SellOffer,
               select: [bo, so],
                where: so.age in bo.ages and
                       so.income in bo.incomes and
                       so.dpc < bo.dpcs and
                       so.dpd < bo.dpds and
                       so.trader_id in bo.loan_originators and
                       so.loan_risk_class == bo.risk_class and
                       so.loan_duration < bo.loan_duration and
                       so.loan_product_type == bo.loan_product_type and
                       so.loan_status in bo.loan_status and
                       so.loan_is_prolonged == bo.loan_is_prolonged and
                       so.guaranteed == bo.guaranteed
#       res = TestRepo.all(query, [])
#       Logger.info("Res 3: #{inspect res}")
  end

  test "Join Query" do
       TestRepo.insert(%SellOffer{age: 10,       id: Ecto.Mnesia.Adapter.next_id(:sell_offer,1)},[])
       TestRepo.insert(%BuyOffer {port_id: "12", id: Ecto.Mnesia.Adapter.next_id(:buy_offer,1)}, [])
       TestRepo.insert(%BuyOffer {port_id: "13", id: Ecto.Mnesia.Adapter.next_id(:buy_offer,1)}, [])
       query = from  bo in BuyOffer,
               join: so in SellOffer,
             select: {bo.id, so.id}
#       res = TestRepo.all(query, [])
#       Logger.info("Res 4: #{inspect res}")
  end

end
