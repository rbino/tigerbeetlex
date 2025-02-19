defmodule TigerBeetlex.TransferBatchTest do
  use ExUnit.Case, async: true

  alias TigerBeetlex.BatchFullError
  alias TigerBeetlex.OutOfBoundsError
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

      assert_raise BatchFullError, fn -> TransferBatch.append!(batch, transfer) end
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

  describe "TransferBatch.fetch!/1" do
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

      assert transfer == TransferBatch.fetch!(batch, 0)
    end

    test "raises if index is out of bounds", %{batch: batch} do
      assert_raise OutOfBoundsError, fn -> TransferBatch.fetch!(batch, 10) end
    end
  end

  describe "TransferBatch.replace/1" do
    setup do
      {:ok, batch: TransferBatch.new!(32)}
    end

    test "replaces item if it exists", %{batch: batch} do
      transfer = %Transfer{
        id: <<1_999::128>>,
        debit_account_id: <<2_001::128>>,
        credit_account_id: <<2_002::128>>,
        code: 555,
        ledger: 666,
        amount: 20_782
      }

      TransferBatch.append!(batch, transfer)
      assert transfer == TransferBatch.fetch!(batch, 0)

      new_transfer = %{transfer | amount: 9_999}
      assert {:ok, batch} = TransferBatch.replace(batch, 0, new_transfer)
      assert new_transfer == TransferBatch.fetch!(batch, 0)
    end

    test "returns {:error, :out_of_bounds} if index is out of bounds", %{batch: batch} do
      new_transfer = %Transfer{id: <<2_001::128>>, pending_id: <<1::128>>}
      assert {:error, :out_of_bounds} == TransferBatch.replace(batch, 10, new_transfer)
    end
  end

  describe "TransferBatch.replace!/1" do
    setup do
      {:ok, batch: TransferBatch.new!(32)}
    end

    test "replaces item if it exists", %{batch: batch} do
      transfer = %Transfer{
        id: <<1_999::128>>,
        debit_account_id: <<2_001::128>>,
        credit_account_id: <<2_002::128>>,
        code: 555,
        ledger: 666,
        amount: 20_782
      }

      TransferBatch.append!(batch, transfer)
      assert transfer == TransferBatch.fetch!(batch, 0)

      new_transfer = %{transfer | amount: 9_999}
      assert batch = TransferBatch.replace!(batch, 0, new_transfer)
      assert new_transfer == TransferBatch.fetch!(batch, 0)
    end

    test "raises if index is out of bounds", %{batch: batch} do
      new_transfer = %Transfer{id: <<2_001::128>>, pending_id: <<1::128>>}
      assert_raise OutOfBoundsError, fn -> TransferBatch.replace!(batch, 10, new_transfer) end
    end
  end
end
