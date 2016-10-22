# TODO: describe what is this and how to build it
Application.put_env(:ecto_mnesia, TestRepo,
  mnesia_metainfo: TestModel,
  mnesia_backend:  :ram_copies)

# Application.put_env(:ecto_mnesia, :ecto_repos, [TestRepo])

defmodule TestModel do
    @moduledoc """
    Marketplace Metainfo with configuration for `Ecto.Adapter.Mnesia`.
    """
    require Record

    @doc """
    keys contains custom compound keys, than differs from `:id`.
    """
    def keys, do: [id_seq:     [:thing],
                   config:     [:key]]

    @doc """
    meta contains `{table,fields}` pairs for fast `mnesia` bootstrap.
    """
    def meta, do: [id_seq:     [:thing, :id],
                   config:     [:key, :value],
                   buy_offer:  SampleApplicationTest.BuyOffer.__schema__(:fields),
                   sell_offer: SampleApplicationTest.SellOffer.__schema__(:fields)]

end


defmodule TestRepo do
    use Ecto.Repo,
      otp_app: :ecto_mnesia,
      adapter: Ecto.Mnesia.Adapter

    def start_link(_a, _b, _c) do
      Ecto.Mnesia.Storage.storage_up([])
      {:ok, self()}
    end
end

TestRepo.start_link("a", "b", "c")
