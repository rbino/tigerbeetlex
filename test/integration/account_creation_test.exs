defmodule TigerBeetlex.SimpleTest do
  use ExUnit.Case

  alias TigerBeetlex.{
    Account,
    AccountBatch,
    Client,
    IDBatch,
    Response,
    TransferBatch,
    Transfer
  }

  test "a simple sequence of operations works" do
    assert {:ok, client} = Client.connect(0, "3000", 1)

    assert {:ok, account_batch} = AccountBatch.new(2)

    account_id_1 = UUID.uuid4(:raw)

    assert {:ok, account_batch} =
             AccountBatch.add_account(account_batch,
               id: account_id_1,
               ledger: 1,
               code: 1
             )

    account_id_2 = UUID.uuid4(:raw)

    assert {:ok, account_batch} =
             AccountBatch.add_account(account_batch,
               id: account_id_2,
               ledger: 1,
               code: 1
             )

    assert {:ok, ref} = Client.create_accounts(client, account_batch)

    assert_receive {:tigerbeetlex_response, ^ref, response}

    assert {:ok, stream} = Response.to_stream(response)

    assert Enum.to_list(stream) == []

    assert {:ok, transfer_batch} = TransferBatch.new(1)

    transfer_id = UUID.uuid4(:raw)

    assert {:ok, transfer_batch} =
             TransferBatch.add_transfer(transfer_batch,
               id: transfer_id,
               debit_account_id: account_id_1,
               credit_account_id: account_id_2,
               ledger: 1,
               code: 1,
               amount: 100
             )

    assert {:ok, ref} = Client.create_transfers(client, transfer_batch)

    assert_receive {:tigerbeetlex_response, ^ref, response}

    assert {:ok, stream} = Response.to_stream(response)

    assert Enum.to_list(stream) == []

    assert {:ok, id_batch} = IDBatch.new(1)

    assert {:ok, id_batch} = IDBatch.add_id(id_batch, transfer_id)

    assert {:ok, ref} = Client.lookup_transfers(client, id_batch)

    assert_receive {:tigerbeetlex_response, ^ref, response}

    assert {:ok, stream} = Response.to_stream(response)

    assert [
             %Transfer{
               id: ^transfer_id,
               ledger: 1,
               code: 1,
               amount: 100
             }
           ] = Enum.to_list(stream)

    assert {:ok, id_batch} = IDBatch.new(2)

    assert {:ok, id_batch} = IDBatch.add_id(id_batch, account_id_1)
    assert {:ok, id_batch} = IDBatch.add_id(id_batch, account_id_2)

    assert {:ok, ref} = Client.lookup_accounts(client, id_batch)

    assert_receive {:tigerbeetlex_response, ^ref, response}

    assert {:ok, stream} = Response.to_stream(response)

    assert [
             %Account{
               id: ^account_id_1,
               ledger: 1,
               code: 1,
               debits_pending: 0,
               debits_posted: 100,
               credits_pending: 0,
               credits_posted: 0
             },
             %Account{
               id: ^account_id_2,
               ledger: 1,
               code: 1,
               debits_pending: 0,
               debits_posted: 0,
               credits_pending: 0,
               credits_posted: 100
             }
           ] = Enum.to_list(stream)
  end
end
