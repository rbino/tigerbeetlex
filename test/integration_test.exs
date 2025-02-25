defmodule TigerBeetlex.IntegrationTest do
  use ExUnit.Case, async: true

  @moduletag :integration

  alias TigerBeetlex.{
    Account,
    AccountBalance,
    AccountBatch,
    AccountFilter,
    AccountFilterBatch,
    AccountFlags,
    Connection,
    CreateAccountsResult,
    CreateTransfersResult,
    IDBatch,
    Transfer,
    TransferBatch,
    TransferFlags
  }

  # 254 since it runs against a --development instance
  @max_batch_size 254

  setup_all do
    name = :tb

    args = [
      name: name,
      cluster_id: <<0::128>>,
      addresses: ["3000"]
    ]

    _pid = start_supervised!({Connection, args})

    {:ok, conn: name}
  end

  describe "get_account_balances/2" do
    setup do
      {:ok, batch} = AccountBatch.new(32)

      {:ok, batch: batch}
    end

    test "we can fetch an account balances for an account", ctx do
      %{
        batch: batch,
        conn: conn
      } = ctx

      debit_account_id = random_id()
      credit_account_id = random_id()

      deposit = %Account{
        id: debit_account_id,
        ledger: 1,
        code: 1,
        flags: %AccountFlags{history: true}
      }

      {:ok, batch} = AccountBatch.append(batch, deposit)

      credit = %Account{
        id: credit_account_id,
        ledger: 1,
        code: 1,
        flags: %AccountFlags{history: true}
      }

      {:ok, batch} = AccountBatch.append(batch, credit)

      assert {:ok, []} = Connection.create_accounts(conn, batch)

      {:ok, tbatch} = TransferBatch.new(32)

      transfer = %Transfer{
        id: random_id(),
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id,
        ledger: 1,
        code: 1,
        user_data_128: <<42::128>>,
        amount: 100
      }

      {:ok, tbatch} = TransferBatch.append(tbatch, transfer)

      transfer = %Transfer{
        id: random_id(),
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id,
        ledger: 1,
        code: 1,
        user_data_128: <<43::128>>,
        amount: 3000
      }

      {:ok, tbatch} = TransferBatch.append(tbatch, transfer)

      assert {:ok, []} = Connection.create_transfers(conn, tbatch)

      assert %Account{
               ledger: 1,
               code: 1,
               credits_pending: 0,
               credits_posted: 0,
               debits_pending: 0,
               debits_posted: 3100,
               flags: %AccountFlags{history: true}
             } = get_account!(conn, debit_account_id)

      assert %Account{
               ledger: 1,
               code: 1,
               credits_pending: 0,
               credits_posted: 3100,
               debits_pending: 0,
               debits_posted: 0,
               flags: %AccountFlags{history: true}
             } = get_account!(conn, credit_account_id)

      assert [
               %AccountBalance{
                 debits_pending: 0,
                 debits_posted: 100,
                 credits_pending: 0,
                 credits_posted: 0
               },
               %AccountBalance{
                 debits_pending: 0,
                 debits_posted: 3100,
                 credits_pending: 0,
                 credits_posted: 0
               }
             ] = get_balances!(conn, debit_account_id)

      assert [
               %AccountBalance{
                 debits_pending: 0,
                 debits_posted: 0,
                 credits_pending: 0,
                 credits_posted: 100
               },
               %AccountBalance{
                 debits_pending: 0,
                 debits_posted: 0,
                 credits_pending: 0,
                 credits_posted: 3100
               }
             ] = get_balances!(conn, credit_account_id)
    end

    @tag only: true
    test "we can list transfers on an account", ctx do
      %{
        batch: batch,
        conn: conn
      } = ctx

      debit_account_id = random_id()
      credit_account_id = random_id()

      deposit = %Account{
        id: debit_account_id,
        ledger: 1,
        code: 1,
        flags: %AccountFlags{history: true}
      }

      {:ok, batch} = AccountBatch.append(batch, deposit)

      credit = %Account{
        id: credit_account_id,
        ledger: 1,
        code: 1,
        flags: %AccountFlags{history: true}
      }

      {:ok, batch} = AccountBatch.append(batch, credit)
      assert {:ok, []} = Connection.create_accounts(conn, batch)

      {:ok, tbatch} = TransferBatch.new(32)

      transfer = %Transfer{
        id: random_id(),
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id,
        ledger: 1,
        code: 1,
        user_data_128: <<42::128>>,
        amount: 100
      }

      {:ok, tbatch} = TransferBatch.append(tbatch, transfer)

      transfer = %Transfer{
        id: random_id(),
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id,
        ledger: 1,
        code: 1,
        user_data_128: <<43::128>>,
        amount: 3000
      }

      {:ok, tbatch} = TransferBatch.append(tbatch, transfer)

      assert {:ok, []} = Connection.create_transfers(conn, tbatch)

      assert %Account{
               ledger: 1,
               code: 1,
               credits_pending: 0,
               credits_posted: 0,
               debits_pending: 0,
               debits_posted: 3100
             } = get_account!(conn, debit_account_id)

      assert %Account{
               ledger: 1,
               code: 1,
               credits_pending: 0,
               credits_posted: 3100,
               debits_pending: 0,
               debits_posted: 0
             } = get_account!(conn, credit_account_id)

      assert [
               %TigerBeetlex.Transfer{
                 amount: 100
               },
               %TigerBeetlex.Transfer{
                 amount: 3000
               }
             ] = get_account_transfers!(conn, debit_account_id)

      assert [
               %TigerBeetlex.Transfer{
                 amount: 100
               },
               %TigerBeetlex.Transfer{
                 amount: 3000
               }
             ] = get_account_transfers!(conn, credit_account_id)
    end
  end

  describe "create_accounts/2" do
    setup do
      {:ok, batch} = AccountBatch.new(32)

      {:ok, batch: batch}
    end

    test "successful account creation", %{conn: conn, batch: batch} do
      id = random_id()

      account = %Account{
        id: id,
        ledger: 1,
        code: 1,
        flags: %AccountFlags{credits_must_not_exceed_debits: true}
      }

      {:ok, batch} = AccountBatch.append(batch, account)

      assert {:ok, []} = Connection.create_accounts(conn, batch)

      assert %Account{
               id: ^id,
               ledger: 1,
               code: 1,
               flags: %AccountFlags{credits_must_not_exceed_debits: true}
             } = get_account!(conn, id)
    end

    test "successful linked account creation", %{conn: conn, batch: batch} do
      id_1 = random_id()

      account_1 = %Account{
        id: id_1,
        ledger: 1,
        code: 1,
        flags: %AccountFlags{linked: true}
      }

      {:ok, batch} = AccountBatch.append(batch, account_1)

      id_2 = random_id()

      account_2 = %Account{
        id: id_2,
        ledger: 2,
        code: 2,
        user_data_128: <<42::128>>
      }

      {:ok, batch} = AccountBatch.append(batch, account_2)

      assert {:ok, []} = Connection.create_accounts(conn, batch)

      assert %Account{
               id: ^id_1,
               ledger: 1,
               code: 1
             } = get_account!(conn, id_1)

      assert %Account{
               id: ^id_2,
               ledger: 2,
               code: 2,
               user_data_128: <<42::128>>
             } = get_account!(conn, id_2)
    end

    test "failed account creation", %{conn: conn, batch: batch} do
      account = %Account{
        id: <<0::128>>,
        ledger: 1,
        code: 1,
        flags: %AccountFlags{credits_must_not_exceed_debits: true}
      }

      {:ok, batch} = AccountBatch.append(batch, account)

      assert {:ok, results} = Connection.create_accounts(conn, batch)

      assert [
               %CreateAccountsResult{index: 0, result: :id_must_not_be_zero}
             ] == results
    end

    test "failed linked account creation", %{conn: conn, batch: batch} do
      id_1 = random_id()

      account_1 = %Account{
        id: id_1,
        ledger: 1,
        code: 1,
        flags: %AccountFlags{linked: true}
      }

      {:ok, batch} = AccountBatch.append(batch, account_1)

      id_2 = random_id()

      account_2 = %Account{
        id: id_2,
        ledger: 0,
        code: 2,
        user_data_128: <<42::128>>
      }

      {:ok, batch} = AccountBatch.append(batch, account_2)

      assert {:ok, results} = Connection.create_accounts(conn, batch)

      assert [
               %CreateAccountsResult{index: 0, result: :linked_event_failed},
               %CreateAccountsResult{index: 1, result: :ledger_must_not_be_zero}
             ] == results

      assert_account_not_existing(conn, id_1)
      assert_account_not_existing(conn, id_2)
    end

    test "mixed successful and failed account creations", %{conn: conn, batch: batch} do
      id_1 = random_id()

      account_1 = %Account{
        id: id_1,
        ledger: 42,
        code: 42,
        flags: %AccountFlags{debits_must_not_exceed_credits: true}
      }

      {:ok, batch} = AccountBatch.append(batch, account_1)

      id_2 = random_id()

      account_2 = %Account{
        id: id_2,
        ledger: 2,
        code: 2,
        flags: %AccountFlags{
          credits_must_not_exceed_debits: true,
          debits_must_not_exceed_credits: true
        }
      }

      {:ok, batch} = AccountBatch.append(batch, account_2)

      assert {:ok, results} = Connection.create_accounts(conn, batch)

      assert [
               %CreateAccountsResult{index: 1, result: :flags_are_mutually_exclusive}
             ] == results

      assert %Account{
               id: ^id_1,
               ledger: 42,
               code: 42,
               flags: %AccountFlags{debits_must_not_exceed_credits: true}
             } = get_account!(conn, id_1)

      assert_account_not_existing(conn, id_2)
    end

    test "max batch size account creation", %{conn: conn} do
      batch =
        Enum.reduce(1..@max_batch_size, AccountBatch.new!(@max_batch_size), fn _idx, batch ->
          account = %Account{
            id: random_id(),
            ledger: 1,
            code: 1,
            flags: %AccountFlags{credits_must_not_exceed_debits: true}
          }

          AccountBatch.append!(batch, account)
        end)

      assert {:ok, []} = Connection.create_accounts(conn, batch)
    end
  end

  describe "create_transfers/2" do
    setup %{conn: conn} do
      {:ok, batch} = TransferBatch.new(32)
      credit_account_id = create_account!(conn)
      debit_account_id = create_account!(conn)

      ctx = [
        batch: batch,
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id
      ]

      {:ok, ctx}
    end

    test "successful transfer creation", ctx do
      %{
        conn: conn,
        batch: batch,
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id
      } = ctx

      id = random_id()

      transfer = %Transfer{
        id: id,
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id,
        ledger: 1,
        code: 1,
        user_data_128: <<42::128>>,
        amount: 100
      }

      {:ok, batch} = TransferBatch.append(batch, transfer)

      assert {:ok, []} = Connection.create_transfers(conn, batch)

      assert %Transfer{
               id: ^id,
               credit_account_id: ^credit_account_id,
               debit_account_id: ^debit_account_id,
               ledger: 1,
               code: 1,
               user_data_128: <<42::128>>,
               amount: 100
             } = get_transfer!(conn, id)

      assert %Account{
               id: ^credit_account_id,
               ledger: 1,
               code: 1,
               credits_posted: 100
             } = get_account!(conn, credit_account_id)

      assert %Account{
               id: ^debit_account_id,
               ledger: 1,
               code: 1,
               debits_posted: 100
             } = get_account!(conn, debit_account_id)
    end

    test "successful linked transfer creation", ctx do
      %{
        conn: conn,
        batch: batch,
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id
      } = ctx

      id_1 = random_id()

      transfer_1 = %Transfer{
        id: id_1,
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id,
        ledger: 1,
        code: 1,
        amount: 100,
        flags: %TransferFlags{linked: true}
      }

      {:ok, batch} = TransferBatch.append(batch, transfer_1)

      id_2 = random_id()

      transfer_2 = %Transfer{
        id: id_2,
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id,
        ledger: 1,
        code: 1,
        amount: 50
      }

      {:ok, batch} = TransferBatch.append(batch, transfer_2)

      assert {:ok, []} = Connection.create_transfers(conn, batch)

      assert %Transfer{
               id: ^id_1,
               credit_account_id: ^credit_account_id,
               debit_account_id: ^debit_account_id,
               ledger: 1,
               code: 1,
               amount: 100
             } = get_transfer!(conn, id_1)

      assert %Transfer{
               id: ^id_2,
               credit_account_id: ^credit_account_id,
               debit_account_id: ^debit_account_id,
               ledger: 1,
               code: 1,
               amount: 50
             } = get_transfer!(conn, id_2)

      assert %Account{
               id: ^credit_account_id,
               ledger: 1,
               code: 1,
               credits_posted: 150
             } = get_account!(conn, credit_account_id)

      assert %Account{
               id: ^debit_account_id,
               ledger: 1,
               code: 1,
               debits_posted: 150
             } = get_account!(conn, debit_account_id)
    end

    test "successful two phase posted transfer creation", ctx do
      %{
        conn: conn,
        batch: batch,
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id
      } = ctx

      pending_id = random_id()

      pending_transfer = %Transfer{
        id: pending_id,
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id,
        ledger: 1,
        code: 1,
        amount: 100,
        flags: %TransferFlags{pending: true}
      }

      {:ok, batch} = TransferBatch.append(batch, pending_transfer)

      assert {:ok, []} = Connection.create_transfers(conn, batch)

      assert %Transfer{
               id: ^pending_id,
               credit_account_id: ^credit_account_id,
               debit_account_id: ^debit_account_id,
               ledger: 1,
               code: 1,
               amount: 100,
               flags: %TransferFlags{pending: true}
             } = get_transfer!(conn, pending_id)

      assert %Account{
               id: ^credit_account_id,
               ledger: 1,
               code: 1,
               credits_pending: 100,
               credits_posted: 0
             } = get_account!(conn, credit_account_id)

      assert %Account{
               id: ^debit_account_id,
               ledger: 1,
               code: 1,
               debits_pending: 100,
               debits_posted: 0
             } = get_account!(conn, debit_account_id)

      post_pending_id = random_id()

      {:ok, batch} = TransferBatch.new(1)

      amount_max = 2 ** 128 - 1

      post_pending_transfer = %Transfer{
        id: post_pending_id,
        amount: amount_max,
        pending_id: pending_id,
        flags: %TransferFlags{post_pending_transfer: true}
      }

      {:ok, batch} = TransferBatch.append(batch, post_pending_transfer)

      assert {:ok, []} = Connection.create_transfers(conn, batch)

      assert %Transfer{
               id: ^post_pending_id,
               credit_account_id: ^credit_account_id,
               debit_account_id: ^debit_account_id,
               ledger: 1,
               code: 1,
               amount: 100,
               pending_id: ^pending_id,
               flags: %TransferFlags{post_pending_transfer: true}
             } = get_transfer!(conn, post_pending_id)

      assert %Account{
               id: ^credit_account_id,
               ledger: 1,
               code: 1,
               credits_pending: 0,
               credits_posted: 100
             } = get_account!(conn, credit_account_id)

      assert %Account{
               id: ^debit_account_id,
               ledger: 1,
               code: 1,
               debits_pending: 0,
               debits_posted: 100
             } = get_account!(conn, debit_account_id)
    end

    test "successful two phase voided transfer creation", ctx do
      %{
        conn: conn,
        batch: batch,
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id
      } = ctx

      pending_id = random_id()

      pending_transfer = %Transfer{
        id: pending_id,
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id,
        ledger: 1,
        code: 1,
        amount: 100,
        flags: %TransferFlags{pending: true}
      }

      {:ok, batch} = TransferBatch.append(batch, pending_transfer)

      assert {:ok, []} = Connection.create_transfers(conn, batch)

      assert %Transfer{
               id: ^pending_id,
               credit_account_id: ^credit_account_id,
               debit_account_id: ^debit_account_id,
               ledger: 1,
               code: 1,
               amount: 100,
               flags: %TransferFlags{pending: true}
             } = get_transfer!(conn, pending_id)

      assert %Account{
               id: ^credit_account_id,
               ledger: 1,
               code: 1,
               credits_pending: 100,
               credits_posted: 0
             } = get_account!(conn, credit_account_id)

      assert %Account{
               id: ^debit_account_id,
               ledger: 1,
               code: 1,
               debits_pending: 100,
               debits_posted: 0
             } = get_account!(conn, debit_account_id)

      void_pending_id = random_id()

      {:ok, batch} = TransferBatch.new(1)

      void_pending_transfer = %Transfer{
        id: void_pending_id,
        pending_id: pending_id,
        flags: %TransferFlags{void_pending_transfer: true}
      }

      {:ok, batch} = TransferBatch.append(batch, void_pending_transfer)

      assert {:ok, []} = Connection.create_transfers(conn, batch)

      assert %Transfer{
               id: ^void_pending_id,
               credit_account_id: ^credit_account_id,
               debit_account_id: ^debit_account_id,
               ledger: 1,
               code: 1,
               amount: 100,
               pending_id: ^pending_id,
               flags: %TransferFlags{void_pending_transfer: true}
             } = get_transfer!(conn, void_pending_id)

      assert %Account{
               id: ^credit_account_id,
               ledger: 1,
               code: 1,
               credits_pending: 0,
               credits_posted: 0
             } = get_account!(conn, credit_account_id)

      assert %Account{
               id: ^debit_account_id,
               ledger: 1,
               code: 1,
               debits_pending: 0,
               debits_posted: 0
             } = get_account!(conn, debit_account_id)
    end

    test "failed transfer creation", ctx do
      %{
        conn: conn,
        batch: batch,
        credit_account_id: credit_account_id
      } = ctx

      id = random_id()

      transfer = %Transfer{
        id: id,
        credit_account_id: credit_account_id,
        debit_account_id: credit_account_id,
        ledger: 1,
        code: 1,
        amount: 100
      }

      {:ok, batch} = TransferBatch.append(batch, transfer)

      assert {:ok, results} = Connection.create_transfers(conn, batch)

      assert [
               %CreateTransfersResult{index: 0, result: :accounts_must_be_different}
             ] == results

      assert_transfer_not_existing(conn, id)
    end

    test "failed linked transfer creation", ctx do
      %{
        conn: conn,
        batch: batch,
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id
      } = ctx

      id_1 = random_id()

      transfer_1 = %Transfer{
        id: id_1,
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id,
        ledger: 1,
        code: 1,
        amount: 100,
        flags: %TransferFlags{linked: true}
      }

      {:ok, batch} = TransferBatch.append(batch, transfer_1)

      id_2 = random_id()

      transfer_2 = %Transfer{
        id: id_2,
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id,
        ledger: 42,
        code: 1,
        amount: 50
      }

      {:ok, batch} = TransferBatch.append(batch, transfer_2)

      assert {:ok, results} = Connection.create_transfers(conn, batch)

      assert [
               %CreateTransfersResult{index: 0, result: :linked_event_failed},
               %CreateTransfersResult{
                 index: 1,
                 result: :transfer_must_have_the_same_ledger_as_accounts
               }
             ] == results

      assert_transfer_not_existing(conn, id_1)
      assert_transfer_not_existing(conn, id_2)
    end

    test "mixed successful and failed transfer creations", ctx do
      %{
        conn: conn,
        batch: batch,
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id
      } = ctx

      id_1 = random_id()

      transfer_1 = %Transfer{
        id: id_1,
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id,
        ledger: 1,
        code: 1,
        amount: 42
      }

      {:ok, batch} = TransferBatch.append(batch, transfer_1)

      id_2 = random_id()

      transfer_2 = %Transfer{
        id: id_2,
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id,
        ledger: 1,
        code: 0,
        amount: 50
      }

      {:ok, batch} = TransferBatch.append(batch, transfer_2)

      assert {:ok, results} = Connection.create_transfers(conn, batch)

      assert [
               %CreateTransfersResult{
                 index: 1,
                 result: :code_must_not_be_zero
               }
             ] == results

      assert %Transfer{
               id: ^id_1,
               credit_account_id: ^credit_account_id,
               debit_account_id: ^debit_account_id,
               ledger: 1,
               code: 1,
               amount: 42
             } = get_transfer!(conn, id_1)

      assert %Account{
               id: ^credit_account_id,
               ledger: 1,
               code: 1,
               credits_posted: 42
             } = get_account!(conn, credit_account_id)

      assert %Account{
               id: ^debit_account_id,
               ledger: 1,
               code: 1,
               debits_posted: 42
             } = get_account!(conn, debit_account_id)

      assert_transfer_not_existing(conn, id_2)
    end
  end

  describe "lookup_accounts/2" do
    setup %{conn: conn} do
      account_id = create_account!(conn)
      {:ok, batch} = IDBatch.new(32)

      {:ok, account_id: account_id, batch: batch}
    end

    test "returns existing account", ctx do
      %{
        account_id: account_id,
        batch: batch,
        conn: conn
      } = ctx

      {:ok, batch} = IDBatch.append(batch, account_id)

      assert {:ok, results} = Connection.lookup_accounts(conn, batch)
      assert [%Account{id: ^account_id}] = results
    end

    test "returns multiple existing accounts", ctx do
      %{
        account_id: account_id_1,
        batch: batch,
        conn: conn
      } = ctx

      account_id_2 = create_account!(conn)

      {:ok, batch} = IDBatch.append(batch, account_id_1)
      {:ok, batch} = IDBatch.append(batch, account_id_2)

      assert {:ok, results} = Connection.lookup_accounts(conn, batch)
      assert [%Account{id: ^account_id_1}, %Account{id: ^account_id_2}] = results
    end

    test "returns empty result for non-existing account", ctx do
      %{
        batch: batch,
        conn: conn
      } = ctx

      {:ok, batch} = IDBatch.append(batch, <<42::128>>)

      assert {:ok, []} = Connection.lookup_accounts(conn, batch)
    end

    test "returns partial result for mixed existing and non-existing accounts", ctx do
      %{
        account_id: account_id,
        batch: batch,
        conn: conn
      } = ctx

      {:ok, batch} = IDBatch.append(batch, <<42::128>>)
      {:ok, batch} = IDBatch.append(batch, account_id)

      assert {:ok, results} = Connection.lookup_accounts(conn, batch)
      assert [%Account{id: ^account_id}] = results
    end
  end

  describe "lookup_transfers/2" do
    setup %{conn: conn} do
      transfer_id = create_transfer!(conn)
      {:ok, batch} = IDBatch.new(32)

      {:ok, transfer_id: transfer_id, batch: batch}
    end

    test "returns existing transfer", ctx do
      %{
        transfer_id: transfer_id,
        batch: batch,
        conn: conn
      } = ctx

      {:ok, batch} = IDBatch.append(batch, transfer_id)

      assert {:ok, results} = Connection.lookup_transfers(conn, batch)
      assert [%Transfer{id: ^transfer_id}] = results
    end

    test "returns multiple existing transfers", ctx do
      %{
        transfer_id: transfer_id_1,
        batch: batch,
        conn: conn
      } = ctx

      transfer_id_2 = create_transfer!(conn)

      {:ok, batch} = IDBatch.append(batch, transfer_id_1)
      {:ok, batch} = IDBatch.append(batch, transfer_id_2)

      assert {:ok, results} = Connection.lookup_transfers(conn, batch)
      assert [%Transfer{id: ^transfer_id_1}, %Transfer{id: ^transfer_id_2}] = results
    end

    test "returns empty result for non-existing transfer", ctx do
      %{
        batch: batch,
        conn: conn
      } = ctx

      {:ok, batch} = IDBatch.append(batch, <<42::128>>)

      assert {:ok, []} = Connection.lookup_transfers(conn, batch)
    end

    test "returns partial result for mixed existing and non-existing transfers", ctx do
      %{
        transfer_id: transfer_id,
        batch: batch,
        conn: conn
      } = ctx

      {:ok, batch} = IDBatch.append(batch, <<42::128>>)
      {:ok, batch} = IDBatch.append(batch, transfer_id)

      assert {:ok, results} = Connection.lookup_transfers(conn, batch)
      assert [%Transfer{id: ^transfer_id}] = results
    end
  end

  defp random_id do
    Uniq.UUID.uuid7(:raw)
  end

  defp create_account!(conn) do
    id = random_id()

    {:ok, batch} = AccountBatch.new(1)

    account = %Account{
      id: id,
      ledger: 1,
      code: 1
    }

    {:ok, batch} = AccountBatch.append(batch, account)

    {:ok, results} = Connection.create_accounts(conn, batch)
    assert [] = results

    id
  end

  defp create_transfer!(conn) do
    id = random_id()

    credit_account_id = create_account!(conn)
    debit_account_id = create_account!(conn)

    {:ok, batch} = TransferBatch.new(1)

    transfer = %Transfer{
      id: id,
      credit_account_id: credit_account_id,
      debit_account_id: debit_account_id,
      ledger: 1,
      code: 1,
      amount: 100
    }

    {:ok, batch} = TransferBatch.append(batch, transfer)

    {:ok, results} = Connection.create_transfers(conn, batch)
    assert [] = results

    id
  end

  defp get_balances!(conn, account_id) do
    {:ok, batch} =
      AccountFilterBatch.new(%AccountFilter{
        account_id: account_id,
        limit: @max_batch_size,
        flags: %TigerBeetlex.AccountFilterFlags{debits: true, credits: true}
      })

    assert {:ok, list} = Connection.get_account_balances(conn, batch)

    list
  end

  defp get_account_transfers!(conn, account_id) do
    {:ok, batch} =
      AccountFilterBatch.new(%AccountFilter{
        account_id: account_id,
        limit: @max_batch_size,
        flags: %TigerBeetlex.AccountFilterFlags{debits: true, credits: true}
      })

    assert {:ok, list} = Connection.get_account_transfers(conn, batch)

    list
  end

  defp get_account!(conn, id) do
    {:ok, batch} = IDBatch.new(1)
    {:ok, batch} = IDBatch.append(batch, id)

    {:ok, results} = Connection.lookup_accounts(conn, batch)
    assert [%Account{} = account] = results

    account
  end

  defp get_transfer!(conn, id) do
    {:ok, batch} = IDBatch.new(1)
    {:ok, batch} = IDBatch.append(batch, id)

    {:ok, results} = Connection.lookup_transfers(conn, batch)
    assert [%Transfer{} = transfer] = results

    transfer
  end

  defp assert_account_not_existing(conn, id) do
    {:ok, batch} = IDBatch.new(1)
    {:ok, batch} = IDBatch.append(batch, id)

    {:ok, results} = Connection.lookup_accounts(conn, batch)
    assert [] = results
  end

  defp assert_transfer_not_existing(conn, id) do
    {:ok, batch} = IDBatch.new(1)
    {:ok, batch} = IDBatch.append(batch, id)

    {:ok, results} = Connection.lookup_accounts(conn, batch)
    assert [] = results
  end
end
