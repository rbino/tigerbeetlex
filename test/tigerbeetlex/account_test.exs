defmodule TigerBeetlex.AccountTest do
  use ExUnit.Case, async: true

  alias TigerBeetlex.Account
  alias TigerBeetlex.AccountFlags

  test "from_binary and to_binary round trip with minimal fields" do
    account = %Account{
      id: <<1234::128>>,
      ledger: 42,
      code: 99
    }

    assert account ==
             account
             |> Account.to_binary()
             |> Account.from_binary()
  end

  test "from_binary and to_binary round trip with full fields" do
    account = %Account{
      id: <<1234::128>>,
      user_data_128: <<5678::128>>,
      user_data_64: 1234,
      user_data_32: 42,
      ledger: 42,
      code: 99,
      flags: %AccountFlags{credits_must_not_exceed_debits: true}
    }

    assert account ==
             account
             |> Account.to_binary()
             |> Account.from_binary()
  end
end
