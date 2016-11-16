# defmodule Ecto.Mnesia.Adapter.Result do
#   def struct(repo, conn, sql, values, on_conflict, returning, opts) do
#     case query(repo, sql, values, fn x -> x end, opts) do
#       {:ok, %{rows: nil, num_rows: 1}} ->
#         {:ok, []}
#       {:ok, %{rows: [values], num_rows: 1}} ->
#         {:ok, Enum.zip(returning, values)}
#       {:ok, %{num_rows: 0}} ->
#         if on_conflict == :nothing, do: {:ok, []}, else: {:error, :stale}
#       {:error, err} ->
#         case conn.to_constraints(err) do
#           []          -> raise err
#           constraints -> {:invalid, constraints}
#         end
#     end
#   end
# end

