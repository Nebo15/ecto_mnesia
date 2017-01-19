Code.require_file "support/test_repo.exs", __DIR__
ExUnit.start(exclude: [
  :composite_pk,
  :unique_constraint,
  :join,
  :foreign_key_constraint,
  :returning,
  :with_conflict_target,
  :without_conflict_target,
  :invalid_prefix,
])

# Configure Ecto for support and tests
Application.put_env(:ecto, :primary_key_type, :id)

# Load support files
Code.require_file "../deps/ecto/integration_test/support/file_helpers.exs", __DIR__
Code.require_file "../deps/ecto/integration_test/support/migration.exs", __DIR__
Code.require_file "../deps/ecto/integration_test/support/repo.exs", __DIR__
Code.require_file "../deps/ecto/integration_test/support/schemas.exs", __DIR__
Code.require_file "../deps/ecto/integration_test/support/types.exs", __DIR__

Application.put_env(:ecto, Ecto.Integration.TestRepo,
  adapter: Ecto.Adapters.Mnesia)

defmodule Ecto.Integration.TestRepo do
  use Ecto.Integration.Repo, otp_app: :ecto
end

Application.put_env(:ecto, Ecto.Integration.PoolRepo,
  adapter: Ecto.Adapters.Mnesia)

defmodule Ecto.Integration.PoolRepo do
  use Ecto.Integration.Repo, otp_app: :ecto

  def create_prefix(prefix) do
    "create schema #{prefix}"
  end

  def drop_prefix(prefix) do
    "drop schema #{prefix}"
  end
end

defmodule Ecto.Integration.Case do
  use ExUnit.CaseTemplate

  setup _ do
    :mnesia.clear_table(:posts)
    :mnesia.clear_table(:comments)
    :mnesia.clear_table(:permalinks)
    :mnesia.clear_table(:posts_users_pk)
    :mnesia.clear_table(:users)
    :mnesia.clear_table(:customs)
    :mnesia.clear_table(:barebones)
    :mnesia.clear_table(:tags)
    :mnesia.clear_table(:orders)
    :mnesia.clear_table(:composite_pk)
    :mnesia.clear_table(:posts_users_composite_pk)
    :ok
  end
end

{:ok, _} = Ecto.Adapters.Mnesia.ensure_all_started(Ecto.Integration.TestRepo, :temporary)

# Load up the repository, start it, and run migrations
_ = Ecto.Adapters.Mnesia.storage_down(Ecto.Integration.TestRepo.config)
_ = Ecto.Adapters.Mnesia.storage_up(Ecto.Integration.TestRepo.config)
_ = Ecto.Mnesia.Storage.storage_up(TestRepo.config)

{:ok, _pid} = Ecto.Integration.TestRepo.start_link
{:ok, _pid} = Ecto.Integration.PoolRepo.start_link
{:ok, _pid} = TestRepo.start_link()

Ecto.Migrator.up(Ecto.Integration.TestRepo, 0, Ecto.Integration.Migration, log: false)
Ecto.Migrator.up(TestRepo, 1, TestRepoMigrations)

Process.flag(:trap_exit, true)
