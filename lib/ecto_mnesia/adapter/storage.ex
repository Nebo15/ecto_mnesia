defmodule Ecto.Mnesia.Storage do
  @behaviour Ecto.Adapter.Storage
  require Logger

  def storage_up(x) do
       host      = Kernel.node
       copy_type = :application.get_env(:ecto, :mnesia_backend, :ram_copies)
       model     = :application.get_env(:ecto, :mnesia_metainfo, Ecto.Mnesia.Adapter)
       :mnesia.start
       :mnesia.change_table_copy_type(:schema, host, copy_type)
       :mnesia.create_schema([host])
       ok = Enum.map(model.meta, fn {table, fields} -> bootstrap_table(table, fields, copy_type, host) end)
       Logger.info("Storage up: #{inspect x}")
  end

  @doc """
  You may want to bring up table online without restarting.
  """
  def  bootstrap_table(table, fields, copy_type, host) do
       model = :application.get_env(:ecto, :mnesia_metainfo, Ecto.Adapter.Mnesia)
       :mnesia.create_table(table, [{:attributes, fields},{copy_type, [host]}])
       Enum.map(model.meta, fn {table, _} -> create_keys(model, table) end)
  end

  defp create_keys(model, table) do
       case List.keymember?(model.keys, table, 0) do
            false -> :mnesia.add_table_index(table, :id)
             true ->  process_keys(model, table) end
  end

  defp process_keys(model, table) do
       case List.keyfind(model.keys, table, 0) do
            {table, key_fields} -> key_fields
                                |> Enum.map(fn x -> :mnesia.add_table_index(table, x) end)
                              _ -> :skip end
  end

  def  storage_down(x) do
       :mnesia.stop
       :mnesia.delete_schema([Kernel.node])
       Logger.info("Storage up: #{inspect x}")
  end
end
