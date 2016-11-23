defmodule TestRepo.Migrations.CreateTestTables do
  use Ecto.Migration

  def change do
    create table(:sell_offer) do
      add :trader_id,          :integer
      add :loan_id,            :string
      add :book_value,         :integer
      add :min_price_rate,     :decimal
      add :max_shared_apr,     :decimal
      add :dividable,          :boolean
      add :guaranteed,         :boolean
      add :status,             :string
      add :booked_at,          :utc_datetime
      add :ended_at,           :utc_datetime
      add :age,                :integer
      add :income,             :decimal
      add :dpc,                :integer
      add :dpd,                :integer
      add :loan_risk_class,    :string
      add :loan_risk_subclass, :string
      add :loan_duration,      :integer
      add :loan_product_type,  :string
      add :loan_currency,      :string
      add :loan_oap,           :decimal
      add :loan_status,        :string
      add :loan_apr,           :decimal
      add :loan_is_prolonged,  :boolean

      timestamps()
    end
  end
end
