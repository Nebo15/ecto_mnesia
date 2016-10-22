defmodule Ecto.Query.MatchSpecTest do
  require Ecto.Query.MatchSpec
  use ExUnit.Case

  test "tuples work" do
    s = Ecto.Query.MatchSpec.match { a, b },
      where:  a == { 1, 2 },
      select: b

    assert Ecto.Query.MatchSpec.run!(s, { { 1, 2 }, 3 }) == 3
  end

  test "works with tuples inside tuples" do
    s = Ecto.Query.MatchSpec.match { { a, b }, c },
      where:  a == b,
      select: c

    assert Ecto.Query.MatchSpec.run!(s, { { 1, 1 }, 2 }) == 2
  end

  test "works with tuples inside tuples as values" do
    from = {{2013,1,1},{1,1,1}}
    to   = {{2013,2,2},{1,1,1}}

    s = Ecto.Query.MatchSpec.match { a, b },
      where:  a >= from and b <= to,
      select: 2

    assert Ecto.Query.MatchSpec.run!(s, { from, to }) == 2
  end

  test "works with named tuple" do
    s = Ecto.Query.MatchSpec.match foo in { a, b },
      where:  foo.a == { 1, 2 },
      select: foo.b

    assert Ecto.Query.MatchSpec.run!(s, { { 1, 2 }, 3 }) == 3
  end

  test "works with named tuple inside tuple" do
    s = Ecto.Query.MatchSpec.match foo in { a in { a, b }, b },
      where:  foo.a.a == foo.a.b,
      select: foo.b

    assert Ecto.Query.MatchSpec.run!(s, { { 1, 1 }, 3 }) == 3
  end

  test "works with a value" do
    s = Ecto.Query.MatchSpec.match { a, 2 },
      where: a == 3


    assert Ecto.Query.MatchSpec.run!(s, { 3, 2 })
    refute Ecto.Query.MatchSpec.run!(s, { 3, 3 })
    refute Ecto.Query.MatchSpec.run!(s, { 2, 2 })
  end

  test "works elem specification" do
    s = Ecto.Query.MatchSpec.match foo in { a, b },
      where:  elem(foo.a, 0) == 1,
      select: foo.b

    assert Ecto.Query.MatchSpec.run!(s, { { 1, 2 }, 3 }) == 3
  end
end
