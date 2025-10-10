defmodule TigerBeetlex.CDC.EventTest do
  use ExUnit.Case, async: true

  alias TigerBeetlex.CDC.Account
  alias TigerBeetlex.CDC.Event
  alias TigerBeetlex.CDC.Transfer

  @struct_fields Event.__struct__() |> Map.from_struct() |> Map.keys()

  @int_fields [:ledger, :timestamp]

  describe "Event.cast!/1" do
    test "correctly casts the sample event on the TigerBeetle docs" do
      assert %Event{
               timestamp: 1_745_328_372_758_695_656,
               type: :single_phase,
               ledger: 2,
               transfer: %Transfer{
                 id: <<9_082_709::unsigned-integer-size(128)>>,
                 amount: 3794,
                 pending_id: <<0::128>>,
                 user_data_128: <<79_248_595_801_719_937_611_592_367_840_129_079_151::unsigned-128>>,
                 user_data_64: 13_615_171_707_598_273_871,
                 user_data_32: 3_229_992_513,
                 timeout: 0,
                 code: 20_295,
                 flags: transfer_flags,
                 timestamp: 1_745_328_372_758_695_656
               },
               debit_account: %Account{
                 id: <<3750::unsigned-integer-size(128)>>,
                 debits_pending: 0,
                 debits_posted: 8_463_768,
                 credits_pending: 0,
                 credits_posted: 8_861_179,
                 user_data_128: <<118_966_247_877_720_884_212_341_541_320_399_553_321::unsigned-128>>,
                 user_data_64: 526_432_537_153_007_844,
                 user_data_32: 4_157_247_332,
                 code: 1,
                 flags: debit_account_flags,
                 timestamp: 1_745_328_270_103_398_016
               },
               credit_account: %Account{
                 id: <<6765::unsigned-integer-size(128)>>,
                 debits_pending: 0,
                 debits_posted: 8_669_204,
                 credits_pending: 0,
                 credits_posted: 8_637_251,
                 user_data_128: <<43_670_023_860_556_310_170_878_798_978_091_998_141::unsigned-128>>,
                 user_data_64: 12_485_093_662_256_535_374,
                 user_data_32: 1_924_162_092,
                 code: 1,
                 flags: credit_account_flags,
                 timestamp: 1_745_328_270_103_401_031
               }
             } = Event.cast!(event_fixture())

      for flags <- [transfer_flags, debit_account_flags, credit_account_flags],
          field <- flags |> Map.from_struct() |> Map.keys() do
        assert Map.fetch!(flags, field) == false
      end
    end

    test "raises if field is missing" do
      for field <- @struct_fields do
        params = Map.delete(event_fixture(), to_string(field))

        assert_raise KeyError, fn ->
          Event.cast!(params)
        end
      end
    end

    test "correctly parses field as integer" do
      for field <- @int_fields do
        assert %{^field => 42} =
                 event_fixture()
                 |> Map.put(to_string(field), 42)
                 |> Event.cast!()
      end
    end

    test "correctly parses field as string" do
      for field <- @int_fields do
        assert %{^field => 42} =
                 event_fixture()
                 |> Map.put(to_string(field), "42")
                 |> Event.cast!()
      end
    end

    test "raises if field is not a parsable integer" do
      for field <- @int_fields do
        params = Map.put(event_fixture(), to_string(field), "foo")

        assert_raise ArgumentError, fn ->
          Event.cast!(params)
        end
      end
    end

    test "correctly parses type as type" do
      for type <- [:single_phase, :two_phase_pending, :two_phase_voided, :two_phase_posted, :two_phase_expired] do
        assert %{type: ^type} =
                 event_fixture()
                 |> Map.put("type", to_string(type))
                 |> Event.cast!()
      end
    end

    test "raises with invalid type" do
      params = Map.put(event_fixture(), "type", "foo")

      assert_raise FunctionClauseError, fn ->
        Event.cast!(params)
      end
    end
  end

  defp event_fixture do
    %{
      "credit_account" => %{
        "code" => 1,
        "credits_pending" => 0,
        "credits_posted" => 8_637_251,
        "debits_pending" => 0,
        "debits_posted" => 8_669_204,
        "flags" => 0,
        "id" => 6765,
        "timestamp" => "1745328270103401031",
        "user_data_128" => "43670023860556310170878798978091998141",
        "user_data_32" => 1_924_162_092,
        "user_data_64" => "12485093662256535374"
      },
      "debit_account" => %{
        "code" => 1,
        "credits_pending" => 0,
        "credits_posted" => 8_861_179,
        "debits_pending" => 0,
        "debits_posted" => 8_463_768,
        "flags" => 0,
        "id" => 3750,
        "timestamp" => "1745328270103398016",
        "user_data_128" => "118966247877720884212341541320399553321",
        "user_data_32" => 4_157_247_332,
        "user_data_64" => "526432537153007844"
      },
      "ledger" => 2,
      "timestamp" => "1745328372758695656",
      "transfer" => %{
        "amount" => 3794,
        "code" => 20_295,
        "flags" => 0,
        "id" => 9_082_709,
        "pending_id" => 0,
        "timeout" => 0,
        "timestamp" => "1745328372758695656",
        "user_data_128" => "79248595801719937611592367840129079151",
        "user_data_32" => 3_229_992_513,
        "user_data_64" => "13615171707598273871"
      },
      "type" => "single_phase"
    }
  end
end
