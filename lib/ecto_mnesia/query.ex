defmodule Ecto.Mnesia.Query do
  @moduledoc """
  This module converts Ecto.Query AST to MatchSpec.
  """
  require Logger

  @bool_functions [:is_atom, :is_float, :is_integer, :is_list, :is_number, :is_pid,
                   :is_port, :is_reference, :is_tuple, :is_map, :is_binary, :is_function,
                   :is_record, :is_seq_trace, :and, :or, :not, :xor, :andalso, :orelse]

  @guard_functions [:abs, :element, :hd, :length, :node, :round, :size, :tl, :trunc, :+, :-, :*,
                   :div, :rem, :band, :bor, :bxor, :bnot, :bsl, :bsr, :>, :>=, :<, :"=<", :"=:=",
                   :==, :"=/=", :"/=", :self, :get_tcw] ++ @bool_functions

  def match_spec(model, table, fields, wheres, opts) do
    model = table |> String.to_atom |> :mnesia.table_info(:attributes)
    [{match_head(table), match_conditions(wheres, table, opts, []), [match_body(fields, model)]}]
  end

  def match_head(table) do
    table
    |> placeholders
    |> Dict.values
    |> Enum.into([String.to_atom(table)])
    |> List.to_tuple
  end

  def match_conditions([], _table, _opts, acc), do: acc
  def match_conditions([%{expr: expr} | tail], table, opts, acc) do
    condition = match_condition(expr, table, opts)
    match_conditions(tail, table, opts, [condition | acc])
  end

  def match_body([{:&, [], [0, fields, _fields_count]}], model) do
    fields
    |> List.foldl([], fn(field, acc) ->
      pos = model
        |> Enum.find_index(&(&1 == field))
        |> Kernel.+(1)
        |> Integer.to_string
        |> (&String.to_atom("$" <> &1)).()

      acc ++ [pos]
    end)
  end

  # :in a special case when we need to create special guard
  # http://stackoverflow.com/questions/2910393/erlang-mnesia-equivalent-of-sql-select-from-where-field-in-value1-value2-valu
  # def match_condition({:in, [], [{{:., [], [{:&, [], []}, field]}, [], []}, parameters]}, table, opts) do
  #   [{{'_', V}, [], ['$_']} || V <- parameters]

  #   IO.inspect [field, parameter]
  #   {:in, condition_expression(field, table, opts), condition_expression(parameter, table, opts)}
  # end

  def match_condition({op, [], [field, parameter]}, table, opts) do
    {guard_function_operation(op), condition_expression(field, table, opts), condition_expression(parameter, table, opts)}
  end

  def condition_expression({{:., [], [{:&, [], [0]}, name]}, _, []} = a, table, opts) do
    dict = placeholders(table)
    value = case List.keyfind(dict, name, 0) do
      {name, value} -> value;
      :undefined -> nil
    end
    # value = table |> placeholders |> Dict.get(name)
    # Logger.debug("Dot #{inspect value}")
    value
  end

  # Binded variable need to be casted to type that can be compared by Mnesia guard function
  def condition_expression({:^, [], [index]}, table, opts) do
    transmute(:lists.nth(index+1,opts))
  end

  # Recursively expand ecto query expressions and build conditions
  def condition_expression({op, [], [left, right]} = expr, table, opts) do
    {guard_function_operation(op), condition_expression(left, table, opts), condition_expression(right, table, opts)}
  end

  # Another part of this function is to use binded variables values
  def condition_expression(raw_value, _table, _opts) do
    raw_value
  end

  def placeholders(table) do
    fields =
      table |>
      String.to_atom |>
      :mnesia.table_info(:attributes)

    placeholders =
      1..length(fields)
      |> Enum.map(&"$#{&1}")
      |> Enum.map(&String.to_atom/1)

    fields
    |> Enum.zip(placeholders)
  end

  @doc """
  Convert Ecto.Query operations to MatchSpec analogs. (Only ones that doesn't match.)
  """
  def guard_function_operation(:!=), do: :'/='
  def guard_function_operation(:<=), do: :'=<'
  def guard_function_operation(op), do: op



  ###### Everything below need refactoring ######

  def  str(field, model),   do: Integer.to_string :string.str(model.__schema__(:fields),[field])
  def  str2(field, fields), do: Integer.to_string :string.str(fields,[field])

  def  resolve([], _, acc), do: acc
  def  resolve([{op, p, {:^, [], [idx]}} | t], par, acc) do
       resolve(t, par, [{op, p, Enum.at(par, idx)} | acc]) end
  def  resolve([{op, p, val} | t], par, acc) do
       resolve(t, par, [{op, p, val} | acc]) end

  def  transmute(%Decimal{coef: x, exp: y, sign: z}) do
       x * :math.pow(10, y)
  end
  def  transmute(x), do: x

  @doc """
  Transform Ecto Query `order_bys` AST to Mnesia ordering selector.
  """
  def ordering([], _), do: []
  def ordering(order_bys, table), do: ordering(order_bys, table, [])

  def ordering([], _, acc), do: acc |> Enum.reverse
  def ordering([%{expr: [asc: {{:., [], [{:&, [], [0]}, field]}, _,_}]} | t], table, acc) do
    placeholder = table
    |> placeholders
    |> Dict.get(field)

    ordering(t, table, [placeholder | acc])
  end
end
