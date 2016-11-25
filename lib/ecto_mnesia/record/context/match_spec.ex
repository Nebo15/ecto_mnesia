defmodule Ecto.Mnesia.Record.Context.MatchSpec do
  @moduledoc false
  alias Ecto.Mnesia.Record.Context

  defstruct head: [], conditions: [], body: []

  def dump(%Context{match_spec: match_spec}), do: dump(match_spec)
  def dump(%Context.MatchSpec{head: head, conditions: conditions, body: body}) do
    [{head, conditions, [body]}]
  end
end
