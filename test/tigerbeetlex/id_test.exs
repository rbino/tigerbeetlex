defmodule TigerBeetlex.IDTest do
  use ExUnit.Case, async: true

  alias TigerBeetlex.ID

  describe "generate/0" do
    test "generates strictly monotonic IDs" do
      ids = Enum.map(1..100, fn _ -> ID.generate() end)

      assert_strictly_monotonic(ids)
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
