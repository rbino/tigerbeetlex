defmodule TigerBeetlex.AccountTest do
  use ExUnit.Case

  alias TigerBeetlex.Account

  test "from_binary and to_batch_item round trip with minimal fields" do
    account = %Account{
      id: <<1234::128>>,
      ledger: 42,
      code: 99
    }

    assert account ==
             account
             |> Account.to_batch_item()
             |> Account.from_binary()
  end

  test "from_binary and to_batch_item round trip with full fields" do
    account = %Account{
      id: <<1234::128>>,
      user_data_128: <<5678::128>>,
      user_data_64: <<1234::64>>,
      user_data_32: <<42::32>>,
      ledger: 42,
      code: 99,
      flags: %Account.Flags{credits_must_not_exceed_debits: true}
    }

    assert account ==
             account
             |> Account.to_batch_item()
             |> Account.from_binary()
  end

  test "to_batch_item/1 ignores server-controlled fields" do
    account = %Account{
      id: <<1234::128>>,
      ledger: 42,
      code: 99,
      debits_pending: 1,
      debits_posted: 2,
      credits_pending: 3,
      credits_posted: 4,
      timestamp: 5
    }

    assert %Account{
             debits_pending: 0,
             debits_posted: 0,
             credits_pending: 0,
             credits_posted: 0,
             timestamp: 0
           } =
             account
             |> Account.to_batch_item()
             |> Account.from_binary()
  end
end
