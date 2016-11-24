Code.require_file "support/test_repo.exs", __DIR__
Ecto.Mnesia.Storage.storage_up([dir: "priv/data/mnesia"])
TestRepo.start_link
Ecto.Migrator.up(TestRepo, 1, TestRepoMigrations)
ExUnit.start()
