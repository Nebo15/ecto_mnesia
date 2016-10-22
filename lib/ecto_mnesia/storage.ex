defmodule Ecto.Mnesia.Storage do
  @doc """
  This module provides interface to manage Mnesia state and records data structure.
  """
  require Logger
  alias :mnesia, as: Mnesia

  @behaviour Ecto.Adapter.Storage

  @doc """
  Start the Mnesia database.
  """
  def start do
    Mnesia.start
  end

  @doc """
  Stop the Mnesia database.
  """
  def stop do
    Mnesia.stop
  end

  def storage_up(conf) do
       host = Kernel.node
       copy_type = conf[:mnesia_backend]
       model = conf[:mnesia_metainfo]
       Mnesia.change_table_copy_type(:schema, host, copy_type)
       Mnesia.create_schema([host])
       ok = Enum.map(model.meta, fn {table, fields} -> bootstrap_table(table, fields, copy_type, host) end)
       Logger.info("Storage up: #{inspect conf}")
  end

  @doc """
  You may want to bring up table online without restarting.
  """
  def  bootstrap_table(table, fields, copy_type, host) do
       model = Confex.get(:ecto_mnesia, TestRepo)[:mnesia_metainfo]
       Mnesia.create_table(table, [{:attributes, fields},{copy_type, [host]}])
       Enum.map(model.meta, fn {table, _} -> create_keys(model, table) end)
  end

  defp create_keys(model, table) do
       case List.keymember?(model.keys, table, 0) do
            false -> Mnesia.add_table_index(table, :id)
             true ->  process_keys(model, table) end
  end

  defp process_keys(model, table) do
       case List.keyfind(model.keys, table, 0) do
            {table, key_fields} -> key_fields
                                |> Enum.map(fn x -> Mnesia.add_table_index(table, x) end)
                              _ -> :skip end
  end

  def  storage_down(x) do
   stop()
   Mnesia.delete_schema([Kernel.node])
   start()
   Logger.info("Storage up: #{inspect x}")
  end

  def start_link(_, _, _, _, _) do
    conf = Confex.get(:ecto_mnesia, TestRepo)
    storage_up(conf)
    {:ok, self()}
  end
end
