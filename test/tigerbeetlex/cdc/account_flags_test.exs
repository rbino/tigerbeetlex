defmodule TigerBeetlex.CDC.AccountFlagsTest do
  use ExUnit.Case, async: true

  alias TigerBeetlex.CDC.AccountFlags

  describe "AccountFlags.cast!/1" do
    test "casts 0 to all false flags" do
      assert %AccountFlags{
               linked: false,
               debits_must_not_exceed_credits: false,
               credits_must_not_exceed_debits: false,
               history: false,
               imported: false,
               closed: false
             } == AccountFlags.cast!(0)
    end

    test "correctly sets the flags if non-zero value is passed" do
      assert %AccountFlags{linked: true} = AccountFlags.cast!(1)
      assert %AccountFlags{debits_must_not_exceed_credits: true} = AccountFlags.cast!(2)
      assert %AccountFlags{credits_must_not_exceed_debits: true} = AccountFlags.cast!(4)
      assert %AccountFlags{history: true} = AccountFlags.cast!(8)
      assert %AccountFlags{imported: true} = AccountFlags.cast!(16)
      assert %AccountFlags{closed: true} = AccountFlags.cast!(32)
    end

    test "correctly handles multiple flags" do
      assert %AccountFlags{linked: true, history: true} = AccountFlags.cast!(9)
    end

    test "raises if non-integer is passed" do
      assert_raise FunctionClauseError, fn ->
        AccountFlags.cast!("foo")
      end
    end
  end
end
