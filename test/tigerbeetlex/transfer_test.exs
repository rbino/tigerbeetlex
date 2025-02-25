defmodule TigerBeetlex.TransferTest do
  use ExUnit.Case, async: true

  alias TigerBeetlex.Transfer
  alias TigerBeetlex.TransferFlags

  test "from_binary and to_binary round trip with minimal fields" do
    transfer = %Transfer{
      id: <<1234::128>>,
      debit_account_id: <<42::128>>,
      credit_account_id: <<43::128>>,
      ledger: 42,
      code: 99,
      amount: 7_000
    }

    assert transfer ==
             transfer
             |> Transfer.to_binary()
             |> Transfer.from_binary()
  end

  test "from_binary and to_binary round trip with full fields" do
    transfer = %Transfer{
      id: <<1234::128>>,
      debit_account_id: <<42::128>>,
      credit_account_id: <<43::128>>,
      amount: 7_000,
      pending_id: <<101::128>>,
      user_data_128: <<5678::128>>,
      user_data_64: 4321,
      user_data_32: 42,
      timeout: 6_000,
      ledger: 42,
      code: 99,
      flags: %TransferFlags{pending: true}
    }

    assert transfer ==
             transfer
             |> Transfer.to_binary()
             |> Transfer.from_binary()
  end
end
