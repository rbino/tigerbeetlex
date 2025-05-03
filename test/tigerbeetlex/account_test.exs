defmodule TigerBeetlex.AccountTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TigerBeetlex.Account
  alias TigerBeetlex.AccountFlags

  property "from_binary and to_binary round trip" do
    check all account <- account_generator() do
      assert account ==
               account
               |> Account.to_binary()
               |> Account.from_binary()
    end
  end

  defp account_generator do
    max_u128 = 2 ** 128 - 1
    max_u64 = 2 ** 64 - 1
    max_u32 = 2 ** 32 - 1
    max_u16 = 2 ** 16 - 1

    gen all id <- binary(length: 16),
            debits_pending <- integer(0..max_u128),
            debits_posted <- integer(0..max_u128),
            credits_pending <- integer(0..max_u128),
            credits_posted <- integer(0..max_u128),
            user_data_128 <- binary(length: 16),
            user_data_64 <- integer(0..max_u64),
            user_data_32 <- integer(0..max_u32),
            ledger <- integer(0..max_u32),
            code <- integer(0..max_u16),
            flags <- flags_generator(),
            timestamp <- integer(0..max_u64) do
      %Account{
        id: id,
        debits_pending: debits_pending,
        debits_posted: debits_posted,
        credits_pending: credits_pending,
        credits_posted: credits_posted,
        user_data_128: user_data_128,
        user_data_64: user_data_64,
        user_data_32: user_data_32,
        ledger: ledger,
        code: code,
        flags: flags,
        timestamp: timestamp
      }
    end
  end

  defp flags_generator do
    gen all linked <- boolean(),
            debits_must_not_exceed_credits <- boolean(),
            credits_must_not_exceed_debits <- boolean(),
            history <- boolean(),
            imported <- boolean(),
            closed <- boolean() do
      %AccountFlags{
        linked: linked,
        debits_must_not_exceed_credits: debits_must_not_exceed_credits,
        credits_must_not_exceed_debits: credits_must_not_exceed_debits,
        history: history,
        imported: imported,
        closed: closed
      }
    end
  end
end
