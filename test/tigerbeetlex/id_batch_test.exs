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

  describe "IDBatch.append/2" do
    setup do
      assert {:ok, batch} = IDBatch.new(32)

      {:ok, batch: batch}
    end

    test "succeeds with valid id", %{batch: batch} do
      assert {:ok, %IDBatch{}} = IDBatch.append(batch, <<1::128>>)
    end

    test "fails when exceeding capacity" do
      assert {:ok, batch} = IDBatch.new(1)

      assert {:ok, batch} = IDBatch.append(batch, <<1::128>>)
      assert {:error, :batch_full} = IDBatch.append(batch, <<2::128>>)
    end

    test "raises if id is invalid", %{batch: batch} do
      assert_raise ArgumentError, fn ->
        IDBatch.append(batch, 42)
      end
    end
  end

  describe "IDBatch.append!/2" do
    setup do
      {:ok, batch: IDBatch.new!(32)}
    end

    test "succeeds with valid id", %{batch: batch} do
      assert %IDBatch{} = IDBatch.append!(batch, <<1::128>>)
    end

    test "fails when exceeding capacity" do
      batch =
        IDBatch.new!(1)
        |> IDBatch.append!(<<1::128>>)

      assert_raise RuntimeError, fn -> IDBatch.append!(batch, <<2::128>>) end
    end
  end
end
