Application.put_env :ecto_mnesia, TestRepo,
  adapter: Ecto.Adapters.Mnesia

defmodule SellOffer do
  use Ecto.Schema

  schema "sell_offer" do
    field :trader_id,          :integer
    field :loan_id,            :string
    field :book_value,         :integer
    field :min_price_rate,     :decimal
    field :max_shared_apr,     :decimal
    field :dividable,          :boolean
    field :guaranteed,         :boolean
    field :status,             :string
    field :booked_at,          Ecto.DateTime
    field :ended_at,           Ecto.DateTime
    field :age,                :integer
    field :income,             :decimal
    field :dpc,                :integer
    field :dpd,                :integer
    field :loan_risk_class,    :string
    field :loan_risk_subclass, :string
    field :loan_duration,      :integer
    field :loan_product_type,  :string
    field :loan_currency,      :string
    field :loan_oap,           :decimal
    field :loan_status,        :string
    field :loan_apr,           :decimal
    field :loan_is_prolonged,  :boolean

    timestamps()
  end
end

defmodule MySchema do
  use Ecto.Schema

  schema "my_schema" do
    field :x, :string
    field :y, :binary
  end
end

defmodule MySchemaNoPK do
  use Ecto.Schema

  @primary_key false
  schema "my_schema" do
    field :x, :string
  end
end

defmodule TestRepoMigrations do
  use Ecto.Migration

  # Whenever you change this migration, don't forget to drop mnesia data directory to reset migrations history
  def change do
    create_if_not_exists table(:sell_offer) do
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

defmodule TestRepo do
  use Ecto.Repo,
    otp_app: :ecto_mnesia
end
