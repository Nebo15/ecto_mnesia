# TODO: describe what is this and how to build it
Application.put_env(:ecto_mnesia, TestRepo,
  mnesia_meta_schema: TestModel,
  adapter: Ecto.Adapters.Mnesia,
  mnesia_backend:  :ram_copies)

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

defmodule BuyOffer do
  use Ecto.Schema

  schema "buy_offer" do
    field :trader_id,                :string
    field :port_id,                  :string
    field :started_at,               Ecto.DateTime
    field :ended_at,                 Ecto.DateTime
    field :volume,                   :decimal
    field :apr,                      :decimal
    field :intermediary_apr,         :decimal
    field :loan_invest_whole,        :boolean
    field :loan_investment_max,      :decimal
    field :loan_investment_min,      :decimal
    field :guaranteed,               :boolean
    field :etc,                      :binary
    field :age,                      :integer
    field :income,                   :decimal
    field :dpc,                      :integer
    field :dpd,                      :integer
    field :loan_risk_class,          :string
    field :loan_risk_subclass,       :string
    field :loan_duration,            :integer
    field :loan_product_type,        :string
    field :loan_currencies,          :string
    field :loan_originators,         :string
    field :loan_oap,                 :decimal
    field :loan_status,              :string
    field :loan_apr,                 :decimal
    field :loan_is_prolonged,        :boolean
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

defmodule TestModel do
    @moduledoc """
    Marketplace Metainfo with configuration for `Ecto.Adapter.Mnesia`.
    """
    require Record

    @doc """
    keys contains custom compound keys, than differs from `:id`.
    """
    def keys, do: [id_seq:     [:thing]]

    @doc """
    meta contains `{table,fields}` pairs for fast `mnesia` bootstrap.
    """
    def meta, do: [id_seq:     [:thing, :id],
                   buy_offer:  BuyOffer.__schema__(:fields),
                   sell_offer: SellOffer.__schema__(:fields),
                   my_schema:  MySchema.__schema__(:fields),
                   my_schema_no_pk:  MySchemaNoPK.__schema__(:fields)]

end

defmodule TestRepo do
  use Ecto.Repo,
    otp_app: :ecto_mnesia,
    adapter: Ecto.Adapters.Mnesia
end

TestRepo.start_link
