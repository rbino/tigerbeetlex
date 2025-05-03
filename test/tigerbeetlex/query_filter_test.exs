defmodule TigerBeetlex.QueryFilterTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TigerBeetlex.QueryFilter
  alias TigerBeetlex.QueryFilterFlags

  property "from_binary and to_binary round trip" do
    check all account_filter <- account_filter_generator() do
      assert account_filter ==
               account_filter
               |> QueryFilter.to_binary()
               |> QueryFilter.from_binary()
    end
  end

  defp account_filter_generator do
    max_u64 = 2 ** 64 - 1
    max_u32 = 2 ** 32 - 1
    max_u16 = 2 ** 16 - 1

    gen all user_data_128 <- binary(length: 16),
            user_data_64 <- integer(0..max_u64),
            user_data_32 <- integer(0..max_u32),
            ledger <- integer(0..max_u32),
            code <- integer(0..max_u16),
            timestamp_min <- integer(0..max_u64),
            timestamp_max <- integer(0..max_u64),
            limit <- integer(0..max_u32),
            flags <- flags_generator() do
      %QueryFilter{
        user_data_128: user_data_128,
        user_data_64: user_data_64,
        user_data_32: user_data_32,
        ledger: ledger,
        code: code,
        timestamp_min: timestamp_min,
        timestamp_max: timestamp_max,
        limit: limit,
        flags: flags
      }
    end
  end

  defp flags_generator do
    gen all reversed <- boolean() do
      %QueryFilterFlags{
        reversed: reversed
      }
    end
  end
end
