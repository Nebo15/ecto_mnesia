defmodule Support.EvalHelpers do
  @moduledoc false

  @doc """
  Delay the evaluation of the code snippet so
  we can verify compile time behaviour via eval.
  """
  defmacro quote_and_eval(quoted, source \\ []) do
    quoted = Macro.escape(quoted)
    quote do
      Code.eval_quoted(unquote(quoted), unquote(source), __ENV__)
    end
  end
end
