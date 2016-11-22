defmodule Ecto.Mnesia.QueryTest do
  use ExUnit.Case, async: true
  require Logger
  import Ecto.Query
  import Support.EvalHelpers
  alias Ecto.Mnesia.Record.Context

  @pk_field_id :"$1"
  @status_field_id :"$9"
  @age_field_id :"$12"

  defp ms({%Ecto.SubQuery{} = query, args}) do
    context = "sell_offer"
    |> Context.new(SellOffer)

    Ecto.Mnesia.Query.match_spec(query, context, args)
  end
  defp ms({%Ecto.Query{} = query, args}) do
    context = "sell_offer"
    |> Context.new(SellOffer)
    |> Context.update_selects(query.select)

    Ecto.Mnesia.Query.match_spec(query, context, args)
  end
  defp ms(query), do: ms({query, []})

  describe "query building" do
    test "in expression style" do
      status = "foo"
      age = 25

      query = from(so in "sell_offer") |> where(status: ^status)
      assert [{_, [{:==, @status_field_id, ^status}], _}] = ms(query)

      # Multiple bindings
      query = from(so in "sell_offer") |> where(status: ^status, age: ^age)
      assert [{_, [{:and, {:==, @status_field_id, ^status}, {:==, @age_field_id, ^age}}], _}] = ms(query)
    end

    test "in keyword style" do
      status = "foo"
      query = from(so in "sell_offer", where: so.status == ^status)
      assert [{_, [{:==, @status_field_id, ^status}], _}] = ms(query)

      # With map binding
      query = from(so in "sell_offer", where: [status: ^status])
      assert [{_, [{:==, @status_field_id, ^status}], _}] = ms(query)
    end
  end

  describe "from" do
    test "in expression style" do
      assert [{{:sell_offer, :"$1", :"$2", :"$3", :"$4", :"$5", :"$6", :"$7", :"$8", :"$9",
                :"$10", :"$11", :"$12", :"$13", :"$14", :"$15", :"$16", :"$17", :"$18",
                :"$19", :"$20", :"$21", :"$22", :"$23", :"$24", :"$25", :"$26"},
               [],
               [[:"$1", :"$2", :"$3", :"$4", :"$5", :"$6", :"$7", :"$8", :"$9",
               :"$10", :"$11", :"$12", :"$13", :"$14", :"$15", :"$16", :"$17",
               :"$18", :"$19", :"$20", :"$21", :"$22", :"$23", :"$24", :"$25",
               :"$26"]]}] == ms(quote_and_eval(from("sell_offer", [])))
    end

    test "in keyword style" do
      # With name binding
      assert [{{:sell_offer, :"$1", :"$2", :"$3", :"$4", :"$5", :"$6", :"$7", :"$8", :"$9",
                :"$10", :"$11", :"$12", :"$13", :"$14", :"$15", :"$16", :"$17", :"$18",
                :"$19", :"$20", :"$21", :"$22", :"$23", :"$24", :"$25", :"$26"},
               [],
               [[:"$1", :"$2", :"$3", :"$4", :"$5", :"$6", :"$7", :"$8", :"$9",
               :"$10", :"$11", :"$12", :"$13", :"$14", :"$15", :"$16", :"$17",
               :"$18", :"$19", :"$20", :"$21", :"$22", :"$23", :"$24", :"$25",
               :"$26"]]}] == ms(quote_and_eval(from so in SellOffer))

      # Without name binding
      assert [{{:sell_offer, :"$1", :"$2", :"$3", :"$4", :"$5", :"$6", :"$7", :"$8", :"$9",
                :"$10", :"$11", :"$12", :"$13", :"$14", :"$15", :"$16", :"$17", :"$18",
                :"$19", :"$20", :"$21", :"$22", :"$23", :"$24", :"$25", :"$26"},
               [],
               [[:"$1", :"$2", :"$3", :"$4", :"$5", :"$6", :"$7", :"$8", :"$9",
               :"$10", :"$11", :"$12", :"$13", :"$14", :"$15", :"$16", :"$17",
               :"$18", :"$19", :"$20", :"$21", :"$22", :"$23", :"$24", :"$25",
               :"$26"]]}] == ms(quote_and_eval(from SellOffer))
    end
  end

  describe "where" do
    test "in expression style" do
      query = from(so in "sell_offer") |> where(status: "foo")
      assert [{_, [{:==, @status_field_id, "foo"}], _}] = ms(query)
    end

    test "in keyword style" do
      query = from(so in "sell_offer", where: so.status == "foo")
      assert [{_, [{:==, @status_field_id, "foo"}], _}] = ms(query)

      # With map binding
      query = from(so in "sell_offer", where: [status: "foo"])
      assert [{_, [{:==, @status_field_id, "foo"}], _}] = ms(query)
    end

    test "by :id field" do
      query = from so in SellOffer, where: so.id == 11
      assert [{_, [{:==, @pk_field_id, 11}], _}] = ms(query)
    end

    test "with `>`" do
      query = from so in SellOffer, where: so.age > 25
      assert [{_, [{:>, @age_field_id, 25}], _}] = ms(query)
    end

    test "with `<`" do
      query = from so in SellOffer, where: so.age < 25
      assert [{_, [{:<, @age_field_id, 25}], _}] = ms(query)
    end

    test "with `>=`" do
      query = from so in SellOffer, where: so.age >= 26
      assert [{_, [{:>=, @age_field_id, 26}], _}] = ms(query)
    end

    test "with `<=`" do
      query = from so in SellOffer, where: so.age <= 23
      assert [{_, [{:"=<", @age_field_id, 23}], _}] = ms(query)
    end

    test "with `==`" do
      query = from so in SellOffer, where: so.age == 26
      assert [{_, [{:==, @age_field_id, 26}], _}] = ms(query)
    end

   test "with `!=`" do
      query = from so in SellOffer, where: so.age != 26
      assert [{_, [{:"/=", @age_field_id, 26}], _}] = ms(query)
    end

    test "with `and`" do
      query = from so in SellOffer, where: so.age != 26 and so.age != 21
      assert [{_, [{:and, {:"/=", @age_field_id, 26}, {:"/=", @age_field_id, 21}}], _}] = ms(query)
    end

    test "with `or`" do
      query = from so in SellOffer, where: so.age != 26 or so.age != 21
      assert [{_, [{:or, {:"/=", @age_field_id, 26}, {:"/=", @age_field_id, 21}}], _}] = ms(query)
    end

    test "with `not`" do
      query = from so in SellOffer, where: not (so.age == 26)
      assert [{_, [not: {:==, @age_field_id, 26}], _}] = ms(query)
    end

    test "with `or`, `and` and `(..)`" do
      query = from so in SellOffer, where: (so.age != 26 or so.age != 21) and so.age != 23
      assert [{_,
              [{:and, {:or, {:"/=", @age_field_id, 26}, {:"/=", @age_field_id, 21}}, {:"/=", @age_field_id, 23}}],
              _}] = ms(query)
    end

    test "with `in`" do
      query = from so in SellOffer, where: so.age in [23, 26]
      assert [{_, [{:or, {:==, @age_field_id, 23}, {:==, @age_field_id, 26}}], _}] = ms(query)
    end

    test "with `is_nil`" do
      query = from so in SellOffer, where: is_nil(so.age)
      assert [{_, [{:==, @age_field_id, nil}], _}] = ms(query)
    end
  end

  describe "subqueries" do
    test "is not supported" do
      assert_raise Ecto.Query.CompileError, "Subqueries is not supported by Mnesia adapter.", fn ->
        ms(subquery("sell_offer"))
      end
    end
  end

  describe "having" do
    test "is not supported" do
      assert_raise Ecto.Query.CompileError, "Havings is not supported by Mnesia adapter.", fn ->
        ms(from(p in "sell_offer") |> having(status: "foo"))
      end
    end
  end
end
