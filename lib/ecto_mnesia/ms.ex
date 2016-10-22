defmodule Ecto.Query.MatchSpec do
  @type spec :: :ets.match_spec | :ets.compiled_match_spec

  @spec run(spec, tuple | [tuple]) :: { :ok, term } | { :error, term }
  def run(spec, what) when is_tuple(what) do
    if :ets.is_compiled_ms(spec) do
      run(spec, [what]) |> List.first
    else
      :ets.test_ms(what, spec)
    end
  end

  def run(spec, what) when what |> is_list do
    if :ets.is_compiled_ms(spec) do
      :ets.match_spec_run(what, spec)
    else
      case compile(spec) do
        { :ok, spec } ->
          :ets.match_spec_run(what, spec)

        { :error, _ } = e ->
          e
      end
    end
  end

  @spec run!(spec, tuple | [tuple]) :: term | no_return
  def run!(spec, what) when what |> is_tuple do
    case :ets.test_ms(what, spec) do
      { :ok, result } ->
        result

      { :error, reason } ->
        raise RuntimeError, message: reason
    end
  end

  def run!(spec, what) when what |> is_list do
    :ets.match_spec_run(what, :ets.match_spec_compile(spec))
  end

  @spec compile(:ets.match_spec) :: { :ok, :ets.compiled_match_spec } | { :error, term }
  def compile(spec) do
    case :ets.test_ms({}, spec) do
      { :ok, _ } ->
        { :ok, :ets.match_spec_compile(spec) }

      { :error, _ } = e ->
        e
    end
  end

  @spec compile!(:ets.match_spec) :: :ets.compiled_match_spec | no_return
  def compile!(spec) do
    case compile(spec) do
      { :ok, spec } ->
        spec

      { :error, reason } ->
        raise SyntaxError, message: reason
    end
  end

  defmacrop execute(desc, rest) do
    quote do
      descriptor(unquote(desc), __CALLER__) |> transform(unquote(rest), __CALLER__) |> Macro.escape(unquote: true)
    end
  end

  @doc """
  Generate a match_spec based on the passed query.
  """
  defmacro match(clause, rest \\ [])

  # Ecto.Query.MatchSpec.match a in { _, _, _ }, *
  defmacro match({ :in, _, [_, { :{}, _, _ }] } = desc, rest) do
    execute(desc, rest)
  end

  # Ecto.Query.MatchSpec.match a in { _, _ }, *
  defmacro match({ :in, _, [_, { _, _ }] } = desc, rest) do
    execute(desc, rest)
  end

  # Ecto.Query.MatchSpec.match { a, b, c }, *
  defmacro match({ :{}, _, _ } = desc, rest) do
    execute(desc, rest)
  end

  # Ecto.Query.MatchSpec.match { a, b }, *
  defmacro match({ _, _ } = desc, rest) do
    execute(desc, rest)
  end

  defp descriptor({ :{}, _, desc }, __CALLER__) do
    Enum.map desc, &descriptor(&1, __CALLER__)
  end

  defp descriptor({ a, b }, __CALLER__) do
    [descriptor(a, __CALLER__), descriptor(b, __CALLER__)]
  end

  defp descriptor({ :in, _, [{ name, _, _ }, { :in, _, _ } = desc] }, __CALLER__) do
    { name, descriptor(desc, __CALLER__) }
  end

  defp descriptor({ :in, _, [{ name, _, _ }, { :{}, _, _ } = desc] }, __CALLER__) do
    { name, descriptor(desc, __CALLER__) }
  end

  defp descriptor({ :in, _, [{ name, _, _ }, { a, b }] }, __CALLER__) do
    { name, [descriptor(a, __CALLER__), descriptor(b, __CALLER__)] }
  end

  defp descriptor({ name, _, _ }, _) do
    name
  end

  defp descriptor(value, _) do
    { value }
  end

  defp transform(descriptor, clauses, __CALLER__) do
    { head, table } = head(descriptor)

    condition = if where = clauses[:where] do
      condition(where, table, __CALLER__)
    else
      []
    end

    body = if select = clauses[:select] do
      body(select, table, __CALLER__)
    else
      [:'$_']
    end

    [{ head, condition, body }]
  end

  defp head(descriptor) do
    case head(descriptor, %{}, [], 1) do
      { result, table, _ } ->
        { result, table }
    end
  end

  defp head(descriptor, table, name, last) when descriptor |> is_list do
    { result, table, last } = Enum.reduce descriptor, { [], table, last }, fn(desc, { results, table, last }) ->
      case head(desc, table, name, last) do
        { result, table, last } ->
          { [result | results], table, last }
      end
    end

    { Enum.reverse(result) |> List.to_tuple, table, last }
  end

  defp head(:_, table, _, last) do
    { :_, table, last }
  end

  defp head(descriptor, table, name, last) when descriptor |> is_atom do
    reference = :"$#{last}"

    { reference, Dict.put(table, name_for(descriptor, name), reference), last + 1 }
  end

  defp head({ atom, descriptor }, table, name, last) do
    cond do
      # it's a list of names
      descriptor |> is_list ->
        { result, table, last } = Enum.reduce descriptor, { [], table, last }, fn(desc, { results, table, last }) ->
          case head(desc, table, [Atom.to_string(atom) | name], last) do
            { result, table, last } ->
              { [result | results], table, last }
          end
        end

        result = Enum.reverse(result) |> List.to_tuple
        table  = Dict.put(table, name_for(atom, name), result)

        { result, table, last }

      # it's a named list of names
      descriptor |> is_tuple ->
        case head(descriptor, table, [Atom.to_string(atom) | name], last) do
          { result, table, last } ->
            table = Dict.put(table, name_for(atom, name), result)

            { result, table, last }
        end
    end
  end

  defp head({ value }, table, _name, last) do
    { value, table, last }
  end

  defp name_for(new, current) do
    [Atom.to_string(new) | current] |> Enum.reverse |> Enum.join(".")
  end

  defp condition(clause, table, __CALLER__) do
    [internal(Macro.expand(clause, __CALLER__), table, __CALLER__)]
  end

  defp body(clause, table, __CALLER__) do
    [internal(Macro.expand(clause, __CALLER__), table, __CALLER__)]
  end

  # operator destructuring
  defp internal({ :__op__, _, [name, left, right] }, table, __CALLER__) do
    internal({ name, [], [left, right] }, table, __CALLER__)
  end

  defp internal({ :__op__, _, [name, right] }, table, __CALLER__) do
    internal({ name, [], [right] }, table, __CALLER__)
  end

  defp internal({ { :., _, [:erlang, name]}, _, [left, right] }, table, __CALLER__) do
    internal({ name, [], [left, right] }, table, __CALLER__)
  end

  defp internal({ { :., _, [:erlang, name]}, _, [right] }, table, __CALLER__) do
    internal({ name, [], [right] }, table, __CALLER__)
  end

  # not
  defp internal({ :not, _, [a] }, table, __CALLER__) do
    { :not, internal(a, table, __CALLER__) }
  end

  # and, gets converted to andalso
  defp internal({ op, _, [left, right] }, table, __CALLER__) when op in [:and, :andalso] do
    { :andalso, internal(left, table, __CALLER__), internal(right, table, __CALLER__) }
  end

  # or, gets converted to orelse
  defp internal({ op, _, [left, right] }, table, __CALLER__) when op in [:or, :orelse] do
    { :orelse, internal(left, table, __CALLER__), internal(right, table, __CALLER__) }
  end

  # xor
  defp internal({ :xor, _, [left, right] }, table, __CALLER__) do
    { :xor, internal(left, table, __CALLER__), internal(right, table, __CALLER__) }
  end

  # >
  defp internal({ :>, _, [left, right] }, table, __CALLER__) do
    { :>, internal(left, table, __CALLER__), internal(right, table, __CALLER__) }
  end

  # >=
  defp internal({ :>=, _, [left, right] }, table, __CALLER__) do
    { :>=, internal(left, table, __CALLER__), internal(right, table, __CALLER__) }
  end

  # <
  defp internal({ :<, _, [left, right] }, table, __CALLER__) do
    { :<, internal(left, table, __CALLER__), internal(right, table, __CALLER__) }
  end

  # <=, gets converted to =<
  defp internal({ :<=, _, [left, right] }, table, __CALLER__) do
    { :'=<', internal(left, table, __CALLER__), internal(right, table, __CALLER__) }
  end

  # ==
  defp internal({ :==, _, [left, right] }, table, __CALLER__) do
    { :==, internal(left, table, __CALLER__), internal(right, table, __CALLER__) }
  end

  # ===, gets converted to =:=
  defp internal({ :===, _, [left, right] }, table, __CALLER__) do
    { :'=:=', internal(left, table, __CALLER__), internal(right, table, __CALLER__) }
  end

  # != gets converted to /=
  defp internal({ :!=, _, [left, right] }, table, __CALLER__) do
    { :'/=', internal(left, table, __CALLER__), internal(right, table, __CALLER__) }
  end

  # !== gets converted to =/=
  defp internal({ :!==, _, [left, right] }, table, __CALLER__) do
    { :'=/=', internal(left, table, __CALLER__), internal(right, table, __CALLER__) }
  end

  # +
  defp internal({ :+, _, [left, right] }, table, __CALLER__) do
    { :+, internal(left, table, __CALLER__), internal(right, table, __CALLER__) }
  end

  # -
  defp internal({ :-, _, [left, right] }, table, __CALLER__) do
    { :-, internal(left, table, __CALLER__), internal(right, table, __CALLER__) }
  end

  # *
  defp internal({ :*, _, [left, right] }, table, __CALLER__) do
    { :*, internal(left, table, __CALLER__), internal(right, table, __CALLER__) }
  end

  # /, gets converted to div
  defp internal({ :/, _, [left, right] }, table, __CALLER__) do
    { :div, internal(left, table, __CALLER__), internal(right, table, __CALLER__) }
  end

  # rem
  defp internal({ :rem, _, [left, right] }, table, __CALLER__) do
    { :rem, internal(left, table, __CALLER__), internal(right, table, __CALLER__) }
  end

  @function [ :is_atom, :is_float, :is_integer, :is_list, :is_number,
              :is_pid, :is_port, :is_reference, :is_tuple, :is_binary ]
  defp internal({ name, _, [ref] } = whole, table, __CALLER__) when name in @function do
    if id = identify(ref, table) do
      { name, id }
    else
      external(whole)
    end
  end

  # is_record(id, name)
  defp internal({ :is_record, _, [ref, name] } = whole, table, __CALLER__) do
    if id = identify(ref, table) do
      { :is_record, id, name }
    else
      external(whole)
    end
  end

  # is_record(id, name, size)
  defp internal({ :is_record, _, [ref, name, size] } = whole, table, __CALLER__) do
    if id = identify(ref, table) do
      { :is_record, id, name, size }
    else
      external(whole)
    end
  end

  # elem(id, index)
  defp internal({ :elem, _, [ref, index] } = whole, table, __CALLER__) do
    if id = identify(ref, table) do
      { :element, index + 1, id }
    else
      external(whole)
    end
  end

  @function [ :abs, :hd, :length, :round, :tl, :trunc ]
  defp internal({ name, _, [ref] } = whole, table, __CALLER__) when name in @function do
    if id = identify(ref, table) do
      { name, id }
    else
      external(whole)
    end
  end

  # bnot foo
  defp internal({ :bnot, _, [ref] } = whole, table, __CALLER__) do
    if id = identify(ref, table) do
      { :bnot, id }
    else
      external(whole)
    end
  end

  @function [ :band, :bor, :bxor, :bsl, :bsr ]
  defp internal({ name, _, [left, right] }, table, __CALLER__) when name in @function do
    { name, internal(left, table, __CALLER__), internal(right, table, __CALLER__) }
  end

  @function [ :node, :self ]
  defp internal({ name, _, [] }, _, _) when name in @function do
    { name }
  end

  # foo.bar
  defp internal({{ :., _, _ }, _, _ } = whole, table, __CALLER__) do
    if id = identify(whole, table) do
      id
    else
      external(whole)
    end
  end

  # { a, b }
  defp internal({ a, b }, table, __CALLER__) do
    {{ internal(a, table, __CALLER__), internal(b, table, __CALLER__) }}
  end

  # { a, b, c }
  defp internal({ :{}, _, desc }, table, __CALLER__) do
    { Enum.map(desc, &internal(&1, table, __CALLER__)) |> List.to_tuple }
  end

  # foo
  defp internal({ ref, _, _ } = whole, table, __CALLER__) do
    if id = identify(ref, table) do
      id
    else
      external(whole)
    end
  end

  # list
  defp internal(value, table, __CALLER__) when value |> is_list do
    Enum.map value, &internal(&1, table, __CALLER__)
  end

  # number or string
  defp internal(value, _, _) when value |> is_binary or value |> is_number do
    value
  end

  # otherwise just treat it as external
  defp internal(whole, _, _) do
    external(whole)
  end

  # identify a name from a table
  defp identify(name, table) do
    Dict.get(table, identify(name))
  end

  defp identify({{ :., _, [left, name] }, _, _ }) do
    identify(left) <> "." <> Atom.to_string(name)
  end

  defp identify({ name, _, _ }) do
    Atom.to_string(name)
  end

  defp identify(name) do
    Atom.to_string(name)
  end

  defp external(whole) do
    { :unquote, [], quote do: [Ecto.Query.MatchSpec.convert(unquote(whole))] }
  end

  @doc false
  def convert(data) when data |> is_tuple do
    { Tuple.to_list(data) |> Enum.map(&convert(&1)) |> List.to_tuple }
  end

  def convert(data) when data |> is_list do
    Enum.map data, &convert(&1)
  end

  def convert(data) do
    data
  end
end
