defmodule TigerBeetlex.AccountFilterTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TigerBeetlex.AccountFilter
  alias TigerBeetlex.AccountFilterFlags

  property "from_binary and to_binary round trip" do
    check all account_filter <- account_filter_generator() do
      assert account_filter ==
               account_filter
               |> AccountFilter.to_binary()
               |> AccountFilter.from_binary()
    end
  end

  defp account_filter_generator do
    max_u64 = 2 ** 64 - 1
    max_u32 = 2 ** 32 - 1
    max_u16 = 2 ** 16 - 1

    gen all account_id <- binary(length: 16),
            user_data_128 <- binary(length: 16),
            user_data_64 <- integer(0..max_u64),
            user_data_32 <- integer(0..max_u32),
            code <- integer(0..max_u16),
            timestamp_min <- integer(0..max_u64),
            timestamp_max <- integer(0..max_u64),
            limit <- integer(0..max_u32),
            flags <- flags_generator() do
      %AccountFilter{
        account_id: account_id,
        user_data_128: user_data_128,
        user_data_64: user_data_64,
        user_data_32: user_data_32,
        code: code,
        timestamp_min: timestamp_min,
        timestamp_max: timestamp_max,
        limit: limit,
        flags: flags
      }
    end
  end

  defp flags_generator do
    gen all debits <- boolean(),
            credits <- boolean(),
            reversed <- boolean() do
      %AccountFilterFlags{
        debits: debits,
        credits: credits,
        reversed: reversed
      }
    end
  end
end
