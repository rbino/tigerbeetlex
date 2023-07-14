defmodule Tigerbeetlex.AccountBatchTest do
  use ExUnit.Case

  alias TigerBeetlex.AccountBatch

  describe "AccountBatch.new/1" do
    test "raises if argument is not an integer" do
      assert_raise FunctionClauseError, fn ->
        AccountBatch.new("foo")
      end
    end

    test "succeeds if argument is an integer" do
      assert {:ok, %AccountBatch{}} = AccountBatch.new(10)
    end
  end

  describe "AccountBatch.add_account/2" do
    setup do
      valid_account_opts = [
        id: <<1::128>>,
        code: 1,
        ledger: 1
      ]

      assert {:ok, batch} = AccountBatch.new(32)

      {:ok, valid_opts: valid_account_opts, batch: batch}
    end

    test "succeeds with valid_opts", %{batch: batch, valid_opts: opts} do
      assert {:ok, %AccountBatch{}} = AccountBatch.add_account(batch, opts)
    end

    test "fails when exceeding capacity", %{valid_opts: opts} do
      assert {:ok, batch} = AccountBatch.new(1)

      assert {:ok, batch} = AccountBatch.add_account(batch, opts)
      assert {:error, :batch_full} = AccountBatch.add_account(batch, opts)
    end

    test "raises if id is invalid", %{batch: batch, valid_opts: opts} do
      assert_raise FunctionClauseError, fn ->
        AccountBatch.add_account(batch, Keyword.put(opts, :id, 42))
      end
    end

    test "raises if user_data is invalid", %{batch: batch, valid_opts: opts} do
      assert_raise FunctionClauseError, fn ->
        AccountBatch.add_account(batch, Keyword.put(opts, :user_data, "foo"))
      end
    end

    test "raises if flags is invalid", %{batch: batch, valid_opts: opts} do
      assert_raise FunctionClauseError, fn ->
        AccountBatch.add_account(batch, Keyword.put(opts, :flags, "bar"))
      end
    end

    test "raises if ledger is invalid", %{batch: batch, valid_opts: opts} do
      assert_raise FunctionClauseError, fn ->
        AccountBatch.add_account(batch, Keyword.put(opts, :ledger, -1))
      end
    end

    test "raises if code is invalid", %{batch: batch, valid_opts: opts} do
      assert_raise FunctionClauseError, fn ->
        AccountBatch.add_account(batch, Keyword.put(opts, :code, "foo"))
      end
    end
  end

  describe "AccountBatch.add_account!/2" do
    setup do
      valid_account_opts = [
        id: <<1::128>>,
        code: 1,
        ledger: 1
      ]

      {:ok, valid_opts: valid_account_opts, batch: AccountBatch.new!(32)}
    end

    test "succeeds with valid_opts", %{batch: batch, valid_opts: opts} do
      assert %AccountBatch{} = AccountBatch.add_account!(batch, opts)
    end

    test "fails when exceeding capacity", %{valid_opts: opts} do
      batch =
        AccountBatch.new!(1)
        |> AccountBatch.add_account!(opts)

      assert_raise RuntimeError, fn -> AccountBatch.add_account!(batch, opts) end
    end
  end
end
