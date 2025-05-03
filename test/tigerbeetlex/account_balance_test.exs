defmodule TigerBeetlex.AccountBalanceTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TigerBeetlex.AccountBalance

  property "from_binary and to_binary round trip" do
    check all account_balance <- account_balance_generator() do
      assert account_balance ==
               account_balance
               |> AccountBalance.to_binary()
               |> AccountBalance.from_binary()
    end
  end

  defp account_balance_generator do
    max_u128 = 2 ** 128 - 1
    max_u64 = 2 ** 64 - 1

    gen all debits_pending <- integer(0..max_u128),
            debits_posted <- integer(0..max_u128),
            credits_pending <- integer(0..max_u128),
            credits_posted <- integer(0..max_u128),
            timestamp <- integer(0..max_u64) do
      %AccountBalance{
        debits_pending: debits_pending,
        debits_posted: debits_posted,
        credits_pending: credits_pending,
        credits_posted: credits_posted,
        timestamp: timestamp
      }
    end
  end
end
