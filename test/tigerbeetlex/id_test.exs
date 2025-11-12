defmodule TigerBeetlex.IDTest do
  use ExUnit.Case, async: true

  alias TigerBeetlex.ID

  describe "generate/0" do
    test "generates strictly monotonic IDs when called serially" do
      ids = Enum.map(1..100, fn _ -> ID.generate() end)

      assert_strictly_monotonic(ids)
    end

    test "generates unique IDs when called concurrently" do
      expected_count = 10_000

      unique_count =
        1..expected_count
        |> Enum.map(fn _ -> Task.async(fn -> ID.generate() end) end)
        |> Task.await_many()
        |> Enum.uniq()
        |> Enum.count()

      assert expected_count == unique_count
    end
  end

  describe "from_int/1" do
    test "encodes the integer in little endian" do
      assert ID.from_int(42) == <<42, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
    end
  end

  defp assert_strictly_monotonic([_id | []]), do: :ok

  defp assert_strictly_monotonic([id1, id2 | rest]) do
    <<id1_as_uint128::unsigned-integer-little-size(128)>> = id1
    <<id2_as_uint128::unsigned-integer-little-size(128)>> = id2

    assert id1_as_uint128 < id2_as_uint128

    assert_strictly_monotonic([id2 | rest])
  end
end
