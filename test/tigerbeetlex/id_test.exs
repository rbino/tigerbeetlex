defmodule TigerBeetlex.IDTest do
  use ExUnit.Case, async: true

  alias TigerBeetlex.ID

  describe "generate/0" do
    test "generates strictly monotonic IDs" do
      ids = Enum.map(1..10_000, fn _ -> ID.generate() end)

      assert_strictly_monotonic(ids)
    end

    test "parallel generates unique IDs" do
      n = 100
      owner = self()

      for i <- 1..n do
        spawn(fn ->
          ids =
            for _ <- 1..1000 do
              ID.generate()
            end

          send(owner, {:generated, i, ids})
        end)
      end

      for_result =
        for i <- 1..n do
          assert_receive {:generated, ^i, ids}, 15_000
          ids
        end

      received_unique_count =
        for_result
        |> Enum.concat()
        |> MapSet.new()
        |> MapSet.size()

      assert n * 1000 == received_unique_count
    end
  end

  describe "from_int/1" do
    test "encodes the integer" do
      assert ID.from_int(42) == <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 42>>
    end
  end

  defp assert_strictly_monotonic([_id | []]), do: :ok

  defp assert_strictly_monotonic([id1, id2 | rest]) do
    assert byte_size(id1) == byte_size(id2)
    assert id1 < id2
    assert_strictly_monotonic([id2 | rest])
  end
end
