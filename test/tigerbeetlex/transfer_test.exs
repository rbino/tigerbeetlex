defmodule TigerBeetlex.TransferTest do
  use ExUnit.Case

  alias TigerBeetlex.Transfer

  test "from_binary and to_batch_item round trip with minimal fields" do
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
             |> Transfer.to_batch_item()
             |> Transfer.from_binary()
  end

  test "from_binary and to_batch_item round trip with full fields" do
    transfer = %Transfer{
      id: <<1234::128>>,
      debit_account_id: <<42::128>>,
      credit_account_id: <<43::128>>,
      amount: 7_000,
      pending_id: <<101::128>>,
      user_data_128: <<5678::128>>,
      user_data_64: <<4321::64>>,
      user_data_32: <<42::32>>,
      timeout: 6_000,
      ledger: 42,
      code: 99,
      flags: %Transfer.Flags{pending: true}
    }

    assert transfer ==
             transfer
             |> Transfer.to_batch_item()
             |> Transfer.from_binary()
  end

  test "to_batch_item/1 ignores server-controlled fields" do
    transfer = %Transfer{
      id: <<1234::128>>,
      timestamp: 99
    }

    assert %Transfer{
             timestamp: 0
           } =
             transfer
             |> Transfer.to_batch_item()
             |> Transfer.from_binary()
  end
end
