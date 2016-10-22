defmodule Ecto.Mnesia.Storage do
  require Logger
  @behaviour Ecto.Adapter.Storage

  def  storage_up(x) do
       host      = Kernel.node
       conf      = Confex.get(:ecto_mnesia, TestRepo)
       copy_type = conf[:mnesia_backend]
       model     = conf[:mnesia_metainfo]
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
       model = Confex.get(:ecto_mnesia, TestRepo)[:mnesia_metainfo]
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

  def start_link(_, _, _, _, _) do
    storage_up([])
    {:ok, self()}
  end
end
