defmodule Tigerbeetlex.TransferBatchTest do
  use ExUnit.Case

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

  describe "TransferBatch.add_transfer/2" do
    setup do
      valid_transfer_opts = [
        id: <<1::128>>,
        debit_account_id: <<1::128>>,
        credit_account_id: <<2::128>>,
        code: 1,
        ledger: 1,
        amount: 42
      ]

      assert {:ok, batch} = TransferBatch.new(32)

      {:ok, valid_opts: valid_transfer_opts, batch: batch}
    end

    test "succeeds with valid_opts", %{batch: batch, valid_opts: opts} do
      assert {:ok, %TransferBatch{}} = TransferBatch.add_transfer(batch, opts)
    end

    test "fails when exceeding capacity", %{valid_opts: opts} do
      assert {:ok, batch} = TransferBatch.new(1)

      assert {:ok, batch} = TransferBatch.add_transfer(batch, opts)
      assert {:error, :batch_full} = TransferBatch.add_transfer(batch, opts)
    end

    test "raises if id is invalid", %{batch: batch, valid_opts: opts} do
      assert_raise FunctionClauseError, fn ->
        TransferBatch.add_transfer(batch, Keyword.put(opts, :id, 42))
      end
    end

    test "raises if debit_account_id is invalid", %{batch: batch, valid_opts: opts} do
      assert_raise FunctionClauseError, fn ->
        TransferBatch.add_transfer(batch, Keyword.put(opts, :debit_account_id, 42))
      end
    end

    test "raises if credit_account_id is invalid", %{batch: batch, valid_opts: opts} do
      assert_raise FunctionClauseError, fn ->
        TransferBatch.add_transfer(batch, Keyword.put(opts, :credit_account_id, 42))
      end
    end

    test "raises if user_data is invalid", %{batch: batch, valid_opts: opts} do
      assert_raise FunctionClauseError, fn ->
        TransferBatch.add_transfer(batch, Keyword.put(opts, :user_data, "foo"))
      end
    end

    test "raises if pending_id is invalid", %{batch: batch, valid_opts: opts} do
      assert_raise FunctionClauseError, fn ->
        TransferBatch.add_transfer(batch, Keyword.put(opts, :pending_id, "AAAAA"))
      end
    end

    test "raises if timeout is invalid", %{batch: batch, valid_opts: opts} do
      assert_raise FunctionClauseError, fn ->
        TransferBatch.add_transfer(batch, Keyword.put(opts, :timeout, -1000))
      end
    end

    test "raises if ledger is invalid", %{batch: batch, valid_opts: opts} do
      assert_raise FunctionClauseError, fn ->
        TransferBatch.add_transfer(batch, Keyword.put(opts, :ledger, -1))
      end
    end

    test "raises if code is invalid", %{batch: batch, valid_opts: opts} do
      assert_raise FunctionClauseError, fn ->
        TransferBatch.add_transfer(batch, Keyword.put(opts, :code, "foo"))
      end
    end

    test "raises if flags is invalid", %{batch: batch, valid_opts: opts} do
      assert_raise FunctionClauseError, fn ->
        TransferBatch.add_transfer(batch, Keyword.put(opts, :flags, "bar"))
      end
    end

    test "raises if amount is invalid", %{batch: batch, valid_opts: opts} do
      assert_raise FunctionClauseError, fn ->
        TransferBatch.add_transfer(batch, Keyword.put(opts, :amount, "tiger"))
      end
    end
  end

  describe "TransferBatch.add_transfer!/2" do
    setup do
      valid_transfer_opts = [
        id: <<1::128>>,
        debit_account_id: <<1::128>>,
        credit_account_id: <<2::128>>,
        code: 1,
        ledger: 1,
        amount: 42
      ]

      {:ok, valid_opts: valid_transfer_opts, batch: TransferBatch.new!(32)}
    end

    test "succeeds with valid_opts", %{batch: batch, valid_opts: opts} do
      assert %TransferBatch{} = TransferBatch.add_transfer!(batch, opts)
    end

    test "fails when exceeding capacity", %{valid_opts: opts} do
      batch =
        TransferBatch.new!(1)
        |> TransferBatch.add_transfer!(opts)

      assert_raise RuntimeError, fn -> TransferBatch.add_transfer!(batch, opts) end
    end
  end
end
