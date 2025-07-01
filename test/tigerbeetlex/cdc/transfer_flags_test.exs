defmodule TigerBeetlex.CDC.TransferFlagsTest do
  use ExUnit.Case, async: true

  alias TigerBeetlex.CDC.TransferFlags

  describe "TransferFlags.cast!/1" do
    test "casts 0 to all false flags" do
      assert %TransferFlags{
               linked: false,
               pending: false,
               post_pending_transfer: false,
               void_pending_transfer: false,
               balancing_debit: false,
               balancing_credit: false,
               closing_debit: false,
               closing_credit: false,
               imported: false
             } == TransferFlags.cast!(0)
    end

    test "correctly sets the flags if non-zero value is passed" do
      assert %TransferFlags{linked: true} = TransferFlags.cast!(1)
      assert %TransferFlags{pending: true} = TransferFlags.cast!(2)
      assert %TransferFlags{post_pending_transfer: true} = TransferFlags.cast!(4)
      assert %TransferFlags{void_pending_transfer: true} = TransferFlags.cast!(8)
      assert %TransferFlags{balancing_debit: true} = TransferFlags.cast!(16)
      assert %TransferFlags{balancing_credit: true} = TransferFlags.cast!(32)
      assert %TransferFlags{closing_debit: true} = TransferFlags.cast!(64)
      assert %TransferFlags{closing_credit: true} = TransferFlags.cast!(128)
      assert %TransferFlags{imported: true} = TransferFlags.cast!(256)
    end

    test "correctly handles multiple flags" do
      assert %TransferFlags{linked: true, balancing_debit: true} = TransferFlags.cast!(17)
    end

    test "raises if non-integer is passed" do
      assert_raise FunctionClauseError, fn ->
        TransferFlags.cast!("foo")
      end
    end
  end
end
