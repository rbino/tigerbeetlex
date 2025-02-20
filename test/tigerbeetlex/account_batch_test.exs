defmodule TigerBeetlex.AccountBatchTest do
  use ExUnit.Case, async: true

  alias TigerBeetlex.Account
  alias TigerBeetlex.AccountBatch
  alias TigerBeetlex.BatchFullError
  alias TigerBeetlex.OutOfBoundsError

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

  describe "AccountBatch.append/2" do
    setup do
      valid_account = %Account{
        id: <<1::128>>,
        code: 1,
        ledger: 1
      }

      {:ok, valid_account: valid_account}
    end

    test "succeeds with valid account", %{valid_account: account} do
      batch = AccountBatch.new!(32)

      assert {:ok, %AccountBatch{}} = AccountBatch.append(batch, account)
      assert {:ok, account} == AccountBatch.fetch(batch, 0)
    end

    test "fails when exceeding capacity", %{valid_account: account} do
      assert {:ok, batch} = AccountBatch.new(1)

      assert {:ok, batch} = AccountBatch.append(batch, account)
      assert {:error, :batch_full} = AccountBatch.append(batch, account)
    end
  end

  describe "AccountBatch.append!/2" do
    setup do
      valid_account = %Account{
        id: <<1::128>>,
        code: 1,
        ledger: 1
      }

      {:ok, valid_account: valid_account}
    end

    test "succeeds with valid account", %{valid_account: account} do
      batch = AccountBatch.new!(32)

      assert %AccountBatch{} = AccountBatch.append!(batch, account)
      assert {:ok, account} == AccountBatch.fetch(batch, 0)
    end

    test "fails when exceeding capacity", %{valid_account: account} do
      batch =
        AccountBatch.new!(1)
        |> AccountBatch.append!(account)

      assert_raise BatchFullError, fn -> AccountBatch.append!(batch, account) end
    end
  end

  describe "AccountBatch.fetch/1" do
    setup do
      {:ok, batch: AccountBatch.new!(32)}
    end

    test "returns item if it exists", %{batch: batch} do
      account = %Account{
        id: <<1_001::128>>,
        code: 42,
        ledger: 45
      }

      AccountBatch.append!(batch, account)

      assert {:ok, account} == AccountBatch.fetch(batch, 0)
    end

    test "returns {:error, :out_of_bounds} if index is out of bounds", %{batch: batch} do
      assert {:error, :out_of_bounds} == AccountBatch.fetch(batch, 10)
    end
  end

  describe "AccountBatch.fetch!/1" do
    setup do
      {:ok, batch: AccountBatch.new!(32)}
    end

    test "returns item if it exists", %{batch: batch} do
      account = %Account{
        id: <<1_001::128>>,
        code: 42,
        ledger: 45
      }

      AccountBatch.append!(batch, account)

      assert account == AccountBatch.fetch!(batch, 0)
    end

    test "raises if index is out of bounds", %{batch: batch} do
      assert_raise OutOfBoundsError, fn -> AccountBatch.fetch!(batch, 10) end
    end
  end

  describe "AccountBatch.replace/1" do
    setup do
      {:ok, batch: AccountBatch.new!(32)}
    end

    test "replaces item if it exists", %{batch: batch} do
      account = %Account{id: <<1_001::128>>, code: 42, ledger: 45}

      AccountBatch.append!(batch, account)
      assert account == AccountBatch.fetch!(batch, 0)

      new_account = %Account{id: <<2_001::128>>, code: 11, ledger: 12}
      assert {:ok, batch} = AccountBatch.replace(batch, 0, new_account)
      assert new_account == AccountBatch.fetch!(batch, 0)
    end

    test "returns {:error, :out_of_bounds} if index is out of bounds", %{batch: batch} do
      new_account = %Account{id: <<2_001::128>>, code: 11, ledger: 12}
      assert {:error, :out_of_bounds} == AccountBatch.replace(batch, 10, new_account)
    end
  end

  describe "AccountBatch.replace!/1" do
    setup do
      {:ok, batch: AccountBatch.new!(32)}
    end

    test "replaces item if it exists", %{batch: batch} do
      account = %Account{id: <<1_001::128>>, code: 42, ledger: 45}

      AccountBatch.append!(batch, account)
      assert account == AccountBatch.fetch!(batch, 0)

      new_account = %Account{id: <<2_001::128>>, code: 11, ledger: 12}
      assert batch = AccountBatch.replace!(batch, 0, new_account)
      assert new_account == AccountBatch.fetch!(batch, 0)
    end

    test "raises if index is out of bounds", %{batch: batch} do
      new_account = %Account{id: <<2_001::128>>, code: 11, ledger: 12}
      assert_raise OutOfBoundsError, fn -> AccountBatch.replace!(batch, 10, new_account) end
    end
  end
end
