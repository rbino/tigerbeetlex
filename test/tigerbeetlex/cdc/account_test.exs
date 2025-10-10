defmodule TigerBeetlex.CDC.AccountTest do
  use ExUnit.Case, async: true

  alias TigerBeetlex.CDC.Account

  @struct_fields Account.__struct__() |> Map.from_struct() |> Map.keys()

  @int_fields [
    :debits_pending,
    :debits_posted,
    :credits_pending,
    :credits_posted,
    :user_data_64,
    :user_data_32,
    :code,
    :timestamp
  ]

  @id_fields [:id, :user_data_128]

  describe "Account.cast!/1" do
    test "correctly casts the sample debit account on the TigerBeetle docs" do
      assert %Account{
               id: <<3750::unsigned-integer-size(128)>>,
               debits_pending: 0,
               debits_posted: 8_463_768,
               credits_pending: 0,
               credits_posted: 8_861_179,
               user_data_128: <<118_966_247_877_720_884_212_341_541_320_399_553_321::unsigned-128>>,
               user_data_64: 526_432_537_153_007_844,
               user_data_32: 4_157_247_332,
               code: 1,
               flags: flags,
               timestamp: 1_745_328_270_103_398_016
             } = Account.cast!(account_fixture())

      for field <- flags |> Map.from_struct() |> Map.keys() do
        assert Map.fetch!(flags, field) == false
      end
    end

    test "raises if field is missing" do
      for field <- @struct_fields do
        params = Map.delete(account_fixture(), to_string(field))

        assert_raise KeyError, fn ->
          Account.cast!(params)
        end
      end
    end

    test "correctly parses field as integer" do
      for field <- @int_fields do
        assert %{^field => 42} =
                 account_fixture()
                 |> Map.put(to_string(field), 42)
                 |> Account.cast!()
      end
    end

    test "correctly parses field as string" do
      for field <- @int_fields do
        assert %{^field => 42} =
                 account_fixture()
                 |> Map.put(to_string(field), "42")
                 |> Account.cast!()
      end
    end

    test "raises if field is not a parsable integer" do
      for field <- @int_fields do
        params = Map.put(account_fixture(), to_string(field), "foo")

        assert_raise ArgumentError, fn ->
          Account.cast!(params)
        end
      end
    end

    test "correctly parses field as integer into an ID" do
      for field <- @id_fields do
        assert %{^field => <<42_000_000::unsigned-integer-size(128)>>} =
                 account_fixture()
                 |> Map.put(to_string(field), 42_000_000)
                 |> Account.cast!()
      end
    end

    test "correctly parses field as string into an ID" do
      for field <- @id_fields do
        assert %{^field => <<42_000_000::unsigned-integer-size(128)>>} =
                 account_fixture()
                 |> Map.put(to_string(field), "42000000")
                 |> Account.cast!()
      end
    end

    test "raises if ID field is not a parsable integer" do
      for field <- @id_fields do
        params = Map.put(account_fixture(), to_string(field), "foo")

        assert_raise ArgumentError, fn ->
          Account.cast!(params)
        end
      end
    end
  end

  defp account_fixture do
    %{
      "id" => 3750,
      "debits_pending" => 0,
      "debits_posted" => 8_463_768,
      "credits_pending" => 0,
      "credits_posted" => 8_861_179,
      "user_data_128" => "118966247877720884212341541320399553321",
      "user_data_64" => "526432537153007844",
      "user_data_32" => 4_157_247_332,
      "code" => 1,
      "flags" => 0,
      "timestamp" => "1745328270103398016"
    }
  end
end
