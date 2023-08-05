defmodule Tigerbeetlex.IDBatchTest do
  use ExUnit.Case

  alias TigerBeetlex.IDBatch

  describe "IDBatch.new/1" do
    test "raises if argument is not an integer" do
      assert_raise FunctionClauseError, fn ->
        IDBatch.new("foo")
      end
    end

    test "succeeds if argument is an integer" do
      assert {:ok, %IDBatch{}} = IDBatch.new(10)
    end
  end

  describe "IDBatch.add_id/2" do
    setup do
      assert {:ok, batch} = IDBatch.new(32)

      {:ok, batch: batch}
    end

    test "succeeds with valid id", %{batch: batch} do
      assert {:ok, %IDBatch{}} = IDBatch.add_id(batch, <<1::128>>)
    end

    test "fails when exceeding capacity" do
      assert {:ok, batch} = IDBatch.new(1)

      assert {:ok, batch} = IDBatch.add_id(batch, <<1::128>>)
      assert {:error, :batch_full} = IDBatch.add_id(batch, <<2::128>>)
    end

    test "raises if id is invalid", %{batch: batch} do
      assert_raise ArgumentError, fn ->
        IDBatch.add_id(batch, 42)
      end
    end
  end

  describe "IDBatch.add_id!/2" do
    setup do
      {:ok, batch: IDBatch.new!(32)}
    end

    test "succeeds with valid id", %{batch: batch} do
      assert %IDBatch{} = IDBatch.add_id!(batch, <<1::128>>)
    end

    test "fails when exceeding capacity" do
      batch =
        IDBatch.new!(1)
        |> IDBatch.add_id!(<<1::128>>)

      assert_raise RuntimeError, fn -> IDBatch.add_id!(batch, <<2::128>>) end
    end
  end
end
