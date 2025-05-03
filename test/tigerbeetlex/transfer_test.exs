defmodule TigerBeetlex.TransferTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TigerBeetlex.Transfer
  alias TigerBeetlex.TransferFlags

  property "from_binary and to_binary round trip" do
    check all transfer <- transfer_generator() do
      assert transfer ==
               transfer
               |> Transfer.to_binary()
               |> Transfer.from_binary()
    end
  end

  defp transfer_generator do
    max_u128 = 2 ** 128 - 1
    max_u64 = 2 ** 64 - 1
    max_u32 = 2 ** 32 - 1
    max_u16 = 2 ** 16 - 1

    gen all id <- binary(length: 16),
            debit_account_id <- binary(length: 16),
            credit_account_id <- binary(length: 16),
            amount <- integer(0..max_u128),
            pending_id <- binary(length: 16),
            user_data_128 <- binary(length: 16),
            user_data_64 <- integer(0..max_u64),
            user_data_32 <- integer(0..max_u32),
            timeout <- integer(0..max_u32),
            ledger <- integer(0..max_u32),
            code <- integer(0..max_u16),
            flags <- flags_generator(),
            timestamp <- integer(0..max_u64) do
      %Transfer{
        id: id,
        debit_account_id: debit_account_id,
        credit_account_id: credit_account_id,
        amount: amount,
        pending_id: pending_id,
        user_data_128: user_data_128,
        user_data_64: user_data_64,
        user_data_32: user_data_32,
        timeout: timeout,
        ledger: ledger,
        code: code,
        flags: flags,
        timestamp: timestamp
      }
    end
  end

  defp flags_generator do
    gen all linked <- boolean(),
            pending <- boolean(),
            post_pending_transfer <- boolean(),
            void_pending_transfer <- boolean(),
            balancing_debit <- boolean(),
            balancing_credit <- boolean(),
            closing_debit <- boolean(),
            closing_credit <- boolean(),
            imported <- boolean() do
      %TransferFlags{
        linked: linked,
        pending: pending,
        post_pending_transfer: post_pending_transfer,
        void_pending_transfer: void_pending_transfer,
        balancing_debit: balancing_debit,
        balancing_credit: balancing_credit,
        closing_debit: closing_debit,
        closing_credit: closing_credit,
        imported: imported
      }
    end
  end
end
