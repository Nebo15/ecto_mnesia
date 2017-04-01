defmodule EctoMnesia.Table.Stream do
  @moduledoc """
  Stream implementation for Mnesia table.
  """
  alias __MODULE__, as: Stream
  alias EctoMnesia.Table

  defstruct table: nil

  def new(table) do
    table = Table.get_name(table)
    stream = %Stream{table: table}

    case first(stream) do
      [] -> []
      _ -> stream
    end
  end

  defp first(%Stream{table: table}) do
    Table.first(table)
  end

  defp next(%Stream{table: table}, key) do
    Table.next(table, key)
  end

  defp read(%Stream{table: table}, key) do
    Table.get(table, key)
  end

  @doc false
  def reduce(stream, acc, fun) do
    reduce(stream, first(stream), acc, fun)
  end

  defp reduce(_stream, _key, {:halt, acc}, _fun) do
    {:halted, acc}
  end

  defp reduce(stream, key, {:suspend, acc}, fun) do
    {:suspended, acc, &reduce(stream, key, &1, fun)}
  end

  defp reduce(_stream, nil, {:cont, acc}, _fun) do
    {:done, acc}
  end

  defp reduce(stream, key, {:cont, acc}, fun) do
    reduce(stream, next(stream, key), fun.(read(stream, key), acc), fun)
  end

  defimpl Enumerable do
    def reduce(stream, acc, fun) do
      EctoMnesia.Table.Stream.reduce(stream, acc, fun)
    end

    def count(_) do
      {:error, __MODULE__}
    end

    def member?(_, _) do
      {:error, __MODULE__}
    end
  end
end
