defmodule Tigerbeetlex.TransferBatchTest do
  use ExUnit.Case

  alias TigerBeetlex.Transfer
  alias TigerBeetlex.TransferBatch

  describe "TransferBatch.new/1" do
    test "raises if argument is not an integer" do
      assert_raise FunctionClauseError, fn ->
        TransferBatch.new("foo")
      end
    end

    test "succeeds if argument is an integer" do
      assert {:ok, %TransferBatch{}} = TransferBatch.new(10)
    end
  end

  describe "TransferBatch.append/2" do
    setup do
      valid_transfer = %Transfer{
        id: <<1::128>>,
        debit_account_id: <<1::128>>,
        credit_account_id: <<2::128>>,
        code: 1,
        ledger: 1,
        amount: 42
      }

      {:ok, valid_transfer: valid_transfer}
    end

    test "succeeds with valid transfer", %{valid_transfer: transfer} do
      batch = TransferBatch.new!(32)
      assert {:ok, %TransferBatch{}} = TransferBatch.append(batch, transfer)
      assert {:ok, transfer} == TransferBatch.fetch(batch, 0)
    end

    test "fails when exceeding capacity", %{valid_transfer: transfer} do
      assert {:ok, batch} = TransferBatch.new(1)

      assert {:ok, batch} = TransferBatch.append(batch, transfer)
      assert {:error, :batch_full} = TransferBatch.append(batch, transfer)
    end
  end

  describe "TransferBatch.append!/2" do
    setup do
      valid_transfer = %Transfer{
        id: <<1::128>>,
        debit_account_id: <<1::128>>,
        credit_account_id: <<2::128>>,
        code: 1,
        ledger: 1,
        amount: 42
      }

      {:ok, valid_transfer: valid_transfer}
    end

    test "succeeds with valid transfer", %{valid_transfer: transfer} do
      batch = TransferBatch.new!(32)

      assert %TransferBatch{} = TransferBatch.append!(batch, transfer)
      assert {:ok, transfer} == TransferBatch.fetch(batch, 0)
    end

    test "fails when exceeding capacity", %{valid_transfer: transfer} do
      batch =
        TransferBatch.new!(1)
        |> TransferBatch.append!(transfer)

      assert_raise RuntimeError, fn -> TransferBatch.append!(batch, transfer) end
    end
  end

  describe "TransferBatch.fetch/1" do
    setup do
      {:ok, batch: TransferBatch.new!(32)}
    end

    test "returns item if it exists", %{batch: batch} do
      transfer = %Transfer{
        id: <<1_999::128>>,
        debit_account_id: <<2_001::128>>,
        credit_account_id: <<2_002::128>>,
        code: 555,
        ledger: 666,
        amount: 20_782
      }

      TransferBatch.append!(batch, transfer)

      assert {:ok, transfer} == TransferBatch.fetch(batch, 0)
    end

    test "returns {:error, :out_of_bounds} if index is out of bounds", %{batch: batch} do
      assert {:error, :out_of_bounds} == TransferBatch.fetch(batch, 10)
    end
  end
end
