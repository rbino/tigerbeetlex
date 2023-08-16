alias TigerBeetlex.Account
alias TigerBeetlex.AccountBatch

account_minimal_fields = [
  id: <<1::128>>,
  code: 4,
  ledger: 4
]

account_minimal_struct = struct!(Account, account_minimal_fields)

account_full_fields =
  account_minimal_fields ++
    [
      user_data: <<42::128>>,
      flags: %Account.Flags{linked: true}
    ]

account_full_struct = struct!(Account, account_full_fields)

Benchee.run(
  %{
    "add_account (old)" => fn {size, opts, _account} ->
      Enum.reduce(1..size, AccountBatch.new!(size), fn _, batch ->
        {:ok, batch} = AccountBatch.add_account(batch, opts)
        batch
      end)
    end,
    "append (new)" => fn {size, _opts, account} ->
      Enum.reduce(1..size, AccountBatch.new!(size), fn _, batch ->
        {:ok, batch} = AccountBatch.append(batch, account)
        batch
      end)
    end
  },
  inputs: %{
    "1. Single, minimal fields" => {1, account_minimal_fields, account_minimal_struct},
    "2. Small, minimal fields" => {10, account_minimal_fields, account_minimal_struct},
    "3. Big, minimal fields" => {100, account_minimal_fields, account_minimal_struct},
    "4. Single, full fields" => {1, account_full_fields, account_full_struct},
    "5. Small, full fields" => {10, account_full_fields, account_full_struct},
    "6. Big, full fields" => {100, account_full_fields, account_full_struct}
  }
)

alias TigerBeetlex.Transfer
alias TigerBeetlex.TransferBatch

transfer_minimal_fields = [
  id: <<1::128>>,
  pending_id: <<42::128>>,
  flags: %Transfer.Flags{post_pending_transfer: true}
]

transfer_minimal_struct = struct!(Transfer, transfer_minimal_fields)

transfer_full_fields =
  transfer_minimal_fields ++
    [
      debit_account_id: <<1::128>>,
      credit_account_id: <<2::128>>,
      user_data: <<42::128>>,
      timeout: 60_000,
      ledger: 4,
      code: 4,
      amount: 42_000
    ]

transfer_full_struct = struct!(Transfer, transfer_full_fields)

Benchee.run(
  %{
    "add_transfer (old)" => fn {size, opts, _transfer} ->
      Enum.reduce(1..size, TransferBatch.new!(size), fn _, batch ->
        {:ok, batch} = TransferBatch.add_transfer(batch, opts)
        batch
      end)
    end,
    "append (new)" => fn {size, _opts, transfer} ->
      Enum.reduce(1..size, TransferBatch.new!(size), fn _, batch ->
        {:ok, batch} = TransferBatch.append(batch, transfer)
        batch
      end)
    end
  },
  inputs: %{
    "1. Single, minimal fields" => {1, transfer_minimal_fields, transfer_minimal_struct},
    "2. Small, minimal fields" => {10, transfer_minimal_fields, transfer_minimal_struct},
    "3. Big, minimal fields" => {100, transfer_minimal_fields, transfer_minimal_struct},
    "4. Single, full fields" => {1, transfer_full_fields, transfer_full_struct},
    "5. Small, full fields" => {10, transfer_full_fields, transfer_full_struct},
    "6. Big, full fields" => {100, transfer_full_fields, transfer_full_struct}
  }
)
