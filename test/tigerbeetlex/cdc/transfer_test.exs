defmodule TigerBeetlex.CDC.TransferTest do
  use ExUnit.Case, async: true

  alias TigerBeetlex.CDC.Transfer

  @struct_fields Transfer.__struct__() |> Map.from_struct() |> Map.keys()

  @int_fields [
    :amount,
    :user_data_64,
    :user_data_32,
    :timeout,
    :code,
    :timestamp
  ]

  @id_fields [:id, :pending_id, :user_data_128]

  describe "Transfer.cast!/1" do
    test "correctly casts the sample transfer on the TigerBeetle docs" do
      assert %Transfer{
               id: <<9_082_709::unsigned-integer-size(128)>>,
               amount: 3794,
               pending_id: <<0::128>>,
               user_data_128: <<79_248_595_801_719_937_611_592_367_840_129_079_151::unsigned-128>>,
               user_data_64: 13_615_171_707_598_273_871,
               user_data_32: 3_229_992_513,
               timeout: 0,
               code: 20_295,
               flags: flags,
               timestamp: 1_745_328_372_758_695_656
             } = Transfer.cast!(transfer_fixture())

      for {field, _} <- Map.from_struct(flags) do
        assert Map.fetch!(flags, field) == false
      end
    end

    test "raises if field is missing" do
      for field <- @struct_fields do
        params = Map.delete(transfer_fixture(), to_string(field))

        assert_raise KeyError, fn ->
          Transfer.cast!(params)
        end
      end
    end

    test "correctly parses field as integer" do
      for field <- @int_fields do
        assert %{^field => 42} =
                 transfer_fixture()
                 |> Map.put(to_string(field), 42)
                 |> Transfer.cast!()
      end
    end

    test "correctly parses field as string" do
      for field <- @int_fields do
        assert %{^field => 42} =
                 transfer_fixture()
                 |> Map.put(to_string(field), "42")
                 |> Transfer.cast!()
      end
    end

    test "raises if field is not a parsable integer" do
      for field <- @int_fields do
        params = Map.put(transfer_fixture(), to_string(field), "foo")

        assert_raise ArgumentError, fn ->
          Transfer.cast!(params)
        end
      end
    end

    test "correctly parses field as integer into an ID" do
      for field <- @id_fields do
        assert %{^field => <<42_000_000::unsigned-integer-size(128)>>} =
                 transfer_fixture()
                 |> Map.put(to_string(field), 42_000_000)
                 |> Transfer.cast!()
      end
    end

    test "correctly parses field as string into an ID" do
      for field <- @id_fields do
        assert %{^field => <<42_000_000::unsigned-integer-size(128)>>} =
                 transfer_fixture()
                 |> Map.put(to_string(field), "42000000")
                 |> Transfer.cast!()
      end
    end

    test "raises if ID field is not a parsable integer" do
      for field <- @id_fields do
        params = Map.put(transfer_fixture(), to_string(field), "foo")

        assert_raise ArgumentError, fn ->
          Transfer.cast!(params)
        end
      end
    end
  end

  defp transfer_fixture do
    %{
      "id" => 9_082_709,
      "amount" => 3794,
      "pending_id" => 0,
      "user_data_128" => "79248595801719937611592367840129079151",
      "user_data_64" => "13615171707598273871",
      "user_data_32" => 3_229_992_513,
      "timeout" => 0,
      "code" => 20_295,
      "flags" => 0,
      "timestamp" => "1745328372758695656"
    }
  end
end
