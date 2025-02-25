defmodule TigerBeetlex.IDBatchTest do
  use ExUnit.Case, async: true

  alias TigerBeetlex.BatchFullError
  alias TigerBeetlex.IDBatch
  alias TigerBeetlex.OutOfBoundsError

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
      assert {:ok, <<1::128>>} = IDBatch.fetch(batch, 0)
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
      assert {:ok, <<1::128>>} = IDBatch.fetch(batch, 0)
    end

    test "fails when exceeding capacity" do
      batch =
        IDBatch.new!(1)
        |> IDBatch.append!(<<1::128>>)

      assert_raise BatchFullError, fn -> IDBatch.append!(batch, <<2::128>>) end
    end
  end

  describe "IDBatch.fetch/1" do
    setup do
      {:ok, batch: IDBatch.new!(32)}
    end

    test "returns item if it exists", %{batch: batch} do
      IDBatch.append!(batch, <<1234::128>>)

      assert {:ok, <<1234::128>>} == IDBatch.fetch(batch, 0)
    end

    test "returns {:error, :out_of_bounds} if index is out of bounds", %{batch: batch} do
      assert {:error, :out_of_bounds} == IDBatch.fetch(batch, 10)
    end
  end

  describe "IDBatch.fetch!/1" do
    setup do
      {:ok, batch: IDBatch.new!(32)}
    end

    test "returns item if it exists", %{batch: batch} do
      IDBatch.append!(batch, <<1234::128>>)

      assert <<1234::128>> == IDBatch.fetch!(batch, 0)
    end

    test "raises if index is out of bounds", %{batch: batch} do
      assert_raise OutOfBoundsError, fn -> IDBatch.fetch!(batch, 10) end
    end
  end

  describe "IDBatch.replace/1" do
    setup do
      {:ok, batch: IDBatch.new!(32)}
    end

    test "replaces item if it exists", %{batch: batch} do
      IDBatch.append!(batch, <<1234::128>>)
      assert <<1234::128>> == IDBatch.fetch!(batch, 0)

      assert {:ok, batch} = IDBatch.replace(batch, 0, <<5678::128>>)
      assert <<5678::128>> == IDBatch.fetch!(batch, 0)
    end

    test "returns {:error, :out_of_bounds} if index is out of bounds", %{batch: batch} do
      assert {:error, :out_of_bounds} == IDBatch.replace(batch, 10, <<5678::128>>)
    end
  end

  describe "IDBatch.replace!/1" do
    setup do
      {:ok, batch: IDBatch.new!(32)}
    end

    test "returns item if it exists", %{batch: batch} do
      IDBatch.append!(batch, <<1234::128>>)
      assert <<1234::128>> == IDBatch.fetch!(batch, 0)

      assert batch = IDBatch.replace!(batch, 0, <<5678::128>>)
      assert <<5678::128>> == IDBatch.fetch!(batch, 0)
    end

    test "raises if index is out of bounds", %{batch: batch} do
      assert_raise OutOfBoundsError, fn -> IDBatch.replace!(batch, 10, <<5678::128>>) end
    end
  end
end
