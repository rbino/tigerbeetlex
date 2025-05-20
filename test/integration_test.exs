defmodule TigerBeetlex.IntegrationTest do
  use ExUnit.Case, async: true

  alias TigerBeetlex.Account
  alias TigerBeetlex.AccountBalance
  alias TigerBeetlex.AccountFilter
  alias TigerBeetlex.AccountFlags
  alias TigerBeetlex.Connection
  alias TigerBeetlex.CreateAccountsResult
  alias TigerBeetlex.CreateTransfersResult
  alias TigerBeetlex.ID
  alias TigerBeetlex.QueryFilter
  alias TigerBeetlex.QueryFilterFlags
  alias TigerBeetlex.Transfer
  alias TigerBeetlex.TransferFlags

  @moduletag :integration

  # 253 since it runs against a --development instance
  @max_batch_size 253

  setup_all do
    name = :tb

    args = [
      name: name,
      cluster_id: ID.from_int(0),
      addresses: ["3000"]
    ]

    _pid = start_supervised!({Connection, args})

    {:ok, conn: name}
  end

  describe "create_accounts/2" do
    test "successful account creation", %{conn: conn} do
      id = ID.generate()

      account = %Account{
        id: id,
        ledger: 1,
        code: 1,
        flags: %AccountFlags{credits_must_not_exceed_debits: true}
      }

      assert {:ok, []} = Connection.create_accounts(conn, [account])

      assert %Account{
               id: ^id,
               ledger: 1,
               code: 1,
               flags: %AccountFlags{credits_must_not_exceed_debits: true}
             } = get_account!(conn, id)
    end

    test "successful linked account creation", %{conn: conn} do
      id_1 = ID.generate()
      id_2 = ID.generate()

      accounts = [
        %Account{
          id: id_1,
          ledger: 1,
          code: 1,
          flags: %AccountFlags{linked: true}
        },
        %Account{
          id: id_2,
          ledger: 2,
          code: 2,
          user_data_128: <<42::128>>
        }
      ]

      assert {:ok, []} = Connection.create_accounts(conn, accounts)

      assert [
               %Account{
                 id: ^id_1,
                 ledger: 1,
                 code: 1
               },
               %Account{
                 id: ^id_2,
                 ledger: 2,
                 code: 2,
                 user_data_128: <<42::128>>
               }
             ] = get_accounts!(conn, [id_1, id_2])
    end

    test "failed account creation", %{conn: conn} do
      account = %Account{
        id: ID.from_int(0),
        ledger: 1,
        code: 1,
        flags: %AccountFlags{credits_must_not_exceed_debits: true}
      }

      assert {:ok, results} = Connection.create_accounts(conn, [account])

      assert [
               %CreateAccountsResult{index: 0, result: :id_must_not_be_zero}
             ] == results
    end

    test "failed linked account creation", %{conn: conn} do
      id_1 = ID.generate()
      id_2 = ID.generate()

      accounts = [
        %Account{
          id: id_1,
          ledger: 1,
          code: 1,
          flags: %AccountFlags{linked: true}
        },
        %Account{
          id: id_2,
          ledger: 0,
          code: 2,
          user_data_128: <<42::128>>
        }
      ]

      assert {:ok, results} = Connection.create_accounts(conn, accounts)

      assert [
               %CreateAccountsResult{index: 0, result: :linked_event_failed},
               %CreateAccountsResult{index: 1, result: :ledger_must_not_be_zero}
             ] == results

      assert_account_not_existing(conn, id_1)
      assert_account_not_existing(conn, id_2)
    end

    test "mixed successful and failed account creations", %{conn: conn} do
      id_1 = ID.generate()
      id_2 = ID.generate()

      accounts = [
        %Account{
          id: id_1,
          ledger: 42,
          code: 42,
          flags: %AccountFlags{debits_must_not_exceed_credits: true}
        },
        %Account{
          id: id_2,
          ledger: 2,
          code: 2,
          flags: %AccountFlags{
            credits_must_not_exceed_debits: true,
            debits_must_not_exceed_credits: true
          }
        }
      ]

      assert {:ok, results} = Connection.create_accounts(conn, accounts)

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
      accounts =
        for _ <- 1..@max_batch_size do
          %Account{
            id: ID.generate(),
            ledger: 1,
            code: 1,
            flags: %AccountFlags{credits_must_not_exceed_debits: true}
          }
        end

      assert {:ok, []} = Connection.create_accounts(conn, accounts)
    end
  end

  describe "create_transfers/2" do
    setup %{conn: conn} do
      credit_account_id = create_account!(conn)
      debit_account_id = create_account!(conn)

      ctx = [
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id
      ]

      {:ok, ctx}
    end

    test "successful transfer creation", ctx do
      %{
        conn: conn,
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id
      } = ctx

      id = ID.generate()

      transfer = %Transfer{
        id: id,
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id,
        ledger: 1,
        code: 1,
        user_data_128: <<42::128>>,
        amount: 100
      }

      assert {:ok, []} = Connection.create_transfers(conn, [transfer])

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
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id
      } = ctx

      id_1 = ID.generate()
      id_2 = ID.generate()

      transfers = [
        %Transfer{
          id: id_1,
          credit_account_id: credit_account_id,
          debit_account_id: debit_account_id,
          ledger: 1,
          code: 1,
          amount: 100,
          flags: %TransferFlags{linked: true}
        },
        %Transfer{
          id: id_2,
          credit_account_id: credit_account_id,
          debit_account_id: debit_account_id,
          ledger: 1,
          code: 1,
          amount: 50
        }
      ]

      assert {:ok, []} = Connection.create_transfers(conn, transfers)

      assert [
               %Transfer{
                 id: ^id_1,
                 credit_account_id: ^credit_account_id,
                 debit_account_id: ^debit_account_id,
                 ledger: 1,
                 code: 1,
                 amount: 100
               },
               %Transfer{
                 id: ^id_2,
                 credit_account_id: ^credit_account_id,
                 debit_account_id: ^debit_account_id,
                 ledger: 1,
                 code: 1,
                 amount: 50
               }
             ] = get_transfers!(conn, [id_1, id_2])

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
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id
      } = ctx

      pending_id = ID.generate()

      pending_transfer = %Transfer{
        id: pending_id,
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id,
        ledger: 1,
        code: 1,
        amount: 100,
        flags: %TransferFlags{pending: true}
      }

      assert {:ok, []} = Connection.create_transfers(conn, [pending_transfer])

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

      post_pending_id = ID.generate()

      amount_max = 2 ** 128 - 1

      post_pending_transfer = %Transfer{
        id: post_pending_id,
        amount: amount_max,
        pending_id: pending_id,
        flags: %TransferFlags{post_pending_transfer: true}
      }

      assert {:ok, []} = Connection.create_transfers(conn, [post_pending_transfer])

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
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id
      } = ctx

      pending_id = ID.generate()

      pending_transfer = %Transfer{
        id: pending_id,
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id,
        ledger: 1,
        code: 1,
        amount: 100,
        flags: %TransferFlags{pending: true}
      }

      assert {:ok, []} = Connection.create_transfers(conn, [pending_transfer])

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

      void_pending_id = ID.generate()

      void_pending_transfer = %Transfer{
        id: void_pending_id,
        pending_id: pending_id,
        flags: %TransferFlags{void_pending_transfer: true}
      }

      assert {:ok, []} = Connection.create_transfers(conn, [void_pending_transfer])

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
        credit_account_id: credit_account_id
      } = ctx

      id = ID.generate()

      transfer = %Transfer{
        id: id,
        credit_account_id: credit_account_id,
        debit_account_id: credit_account_id,
        ledger: 1,
        code: 1,
        amount: 100
      }

      assert {:ok, results} = Connection.create_transfers(conn, [transfer])

      assert [
               %CreateTransfersResult{index: 0, result: :accounts_must_be_different}
             ] == results

      assert_transfer_not_existing(conn, id)
    end

    test "failed linked transfer creation", ctx do
      %{
        conn: conn,
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id
      } = ctx

      id_1 = ID.generate()
      id_2 = ID.generate()

      transfers = [
        %Transfer{
          id: id_1,
          credit_account_id: credit_account_id,
          debit_account_id: debit_account_id,
          ledger: 1,
          code: 1,
          amount: 100,
          flags: %TransferFlags{linked: true}
        },
        %Transfer{
          id: id_2,
          credit_account_id: credit_account_id,
          debit_account_id: debit_account_id,
          ledger: 42,
          code: 1,
          amount: 50
        }
      ]

      assert {:ok, results} = Connection.create_transfers(conn, transfers)

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
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id
      } = ctx

      id_1 = ID.generate()
      id_2 = ID.generate()

      transfers = [
        %Transfer{
          id: id_1,
          credit_account_id: credit_account_id,
          debit_account_id: debit_account_id,
          ledger: 1,
          code: 1,
          amount: 42
        },
        %Transfer{
          id: id_2,
          credit_account_id: credit_account_id,
          debit_account_id: debit_account_id,
          ledger: 1,
          code: 0,
          amount: 50
        }
      ]

      assert {:ok, results} = Connection.create_transfers(conn, transfers)

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

      {:ok, account_id: account_id}
    end

    test "returns existing account", ctx do
      %{
        account_id: account_id,
        conn: conn
      } = ctx

      assert {:ok, results} = Connection.lookup_accounts(conn, [account_id])
      assert [%Account{id: ^account_id}] = results
    end

    test "returns multiple existing accounts", ctx do
      %{
        account_id: account_id_1,
        conn: conn
      } = ctx

      account_id_2 = create_account!(conn)
      account_ids = [account_id_1, account_id_2]

      assert {:ok, results} = Connection.lookup_accounts(conn, account_ids)
      assert [%Account{id: ^account_id_1}, %Account{id: ^account_id_2}] = results
    end

    test "returns empty result for non-existing account", ctx do
      %{
        conn: conn
      } = ctx

      non_existing_id = ID.from_int(42)

      assert {:ok, []} = Connection.lookup_accounts(conn, [non_existing_id])
    end

    test "returns partial result for mixed existing and non-existing accounts", ctx do
      %{
        account_id: account_id,
        conn: conn
      } = ctx

      non_existing_id = ID.from_int(42)
      account_ids = [non_existing_id, account_id]

      assert {:ok, results} = Connection.lookup_accounts(conn, account_ids)
      assert [%Account{id: ^account_id}] = results
    end
  end

  describe "lookup_transfers/2" do
    setup %{conn: conn} do
      transfer_id = create_transfer!(conn)
      {:ok, transfer_id: transfer_id}
    end

    test "returns existing transfer", ctx do
      %{
        transfer_id: transfer_id,
        conn: conn
      } = ctx

      assert {:ok, results} = Connection.lookup_transfers(conn, [transfer_id])
      assert [%Transfer{id: ^transfer_id}] = results
    end

    test "returns multiple existing transfers", ctx do
      %{
        transfer_id: transfer_id_1,
        conn: conn
      } = ctx

      transfer_id_2 = create_transfer!(conn)
      transfer_ids = [transfer_id_1, transfer_id_2]

      assert {:ok, results} = Connection.lookup_transfers(conn, transfer_ids)
      assert [%Transfer{id: ^transfer_id_1}, %Transfer{id: ^transfer_id_2}] = results
    end

    test "returns empty result for non-existing transfer", ctx do
      %{
        conn: conn
      } = ctx

      non_existing_id = ID.from_int(42)

      assert {:ok, []} = Connection.lookup_transfers(conn, [non_existing_id])
    end

    test "returns partial result for mixed existing and non-existing transfers", ctx do
      %{
        transfer_id: transfer_id,
        conn: conn
      } = ctx

      non_existing_id = ID.from_int(42)
      transfer_ids = [non_existing_id, transfer_id]

      assert {:ok, results} = Connection.lookup_transfers(conn, transfer_ids)
      assert [%Transfer{id: ^transfer_id}] = results
    end
  end

  describe "get_account_balances/2" do
    test "can fetch account balances for an account", ctx do
      %{
        conn: conn
      } = ctx

      debit_account_id = ID.generate()
      credit_account_id = ID.generate()

      accounts = [
        %Account{
          id: debit_account_id,
          ledger: 1,
          code: 1,
          flags: %AccountFlags{history: true}
        },
        %Account{
          id: credit_account_id,
          ledger: 1,
          code: 1,
          flags: %AccountFlags{history: true}
        }
      ]

      assert {:ok, []} = Connection.create_accounts(conn, accounts)

      transfers = [
        %Transfer{
          id: ID.generate(),
          credit_account_id: credit_account_id,
          debit_account_id: debit_account_id,
          ledger: 1,
          code: 1,
          user_data_128: <<42::128>>,
          amount: 100
        },
        %Transfer{
          id: ID.generate(),
          credit_account_id: credit_account_id,
          debit_account_id: debit_account_id,
          ledger: 1,
          code: 1,
          user_data_128: <<43::128>>,
          amount: 3000
        }
      ]

      assert {:ok, []} = Connection.create_transfers(conn, transfers)

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
  end

  describe "get_account_transfers/2" do
    test "we can list transfers on an account", ctx do
      %{
        conn: conn
      } = ctx

      debit_account_id = ID.generate()
      credit_account_id = ID.generate()

      accounts = [
        %Account{
          id: debit_account_id,
          ledger: 1,
          code: 1,
          flags: %AccountFlags{history: true}
        },
        %Account{
          id: credit_account_id,
          ledger: 1,
          code: 1,
          flags: %AccountFlags{history: true}
        }
      ]

      assert {:ok, []} = Connection.create_accounts(conn, accounts)

      transfers = [
        %Transfer{
          id: ID.generate(),
          credit_account_id: credit_account_id,
          debit_account_id: debit_account_id,
          ledger: 1,
          code: 1,
          user_data_128: <<42::128>>,
          amount: 100
        },
        %Transfer{
          id: ID.generate(),
          credit_account_id: credit_account_id,
          debit_account_id: debit_account_id,
          ledger: 1,
          code: 1,
          user_data_128: <<43::128>>,
          amount: 3000
        }
      ]

      assert {:ok, []} = Connection.create_transfers(conn, transfers)

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

  describe "query_accounts/2" do
    test "retrieves account using a query_filter", %{conn: conn} do
      target_code = Enum.random(1..65_535)
      matched_account_id = ID.generate()

      matched_account = %Account{
        id: matched_account_id,
        ledger: 1,
        code: target_code,
        user_data_128: <<42::128>>
      }

      other_code_account = %Account{
        id: ID.generate(),
        ledger: 1,
        code: 1,
        user_data_128: <<42::128>>
      }

      other_user_data_account = %Account{
        id: ID.generate(),
        ledger: 1,
        code: target_code,
        user_data_128: <<1::128>>
      }

      accounts = [
        matched_account,
        other_code_account,
        other_user_data_account
      ]

      assert {:ok, []} = Connection.create_accounts(conn, accounts)

      query_filter = %QueryFilter{user_data_128: <<42::128>>, code: target_code, limit: 10}

      assert {:ok, [%Account{id: ^matched_account_id}]} =
               Connection.query_accounts(conn, query_filter)
    end

    test "reverses order when using the reversed flag", %{conn: conn} do
      target_code = Enum.random(1..65_535)
      account_id_1 = ID.generate()

      account_1 = %Account{
        id: account_id_1,
        ledger: 1,
        code: target_code
      }

      account_id_2 = ID.generate()

      account_2 = %Account{
        id: account_id_2,
        ledger: 1,
        code: target_code
      }

      assert {:ok, []} = Connection.create_accounts(conn, [account_1, account_2])

      query_filter = %QueryFilter{
        code: target_code,
        limit: 10,
        flags: %QueryFilterFlags{reversed: true}
      }

      assert {:ok, [%Account{id: ^account_id_2}, %Account{id: ^account_id_1}]} =
               Connection.query_accounts(conn, query_filter)
    end
  end

  describe "query_transfers/2" do
    setup %{conn: conn} do
      credit_account_id = create_account!(conn)
      debit_account_id = create_account!(conn)

      ctx = [
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id
      ]

      {:ok, ctx}
    end

    test "retrieves transfer using a query_filter", ctx do
      %{
        conn: conn,
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id
      } = ctx

      target_code = Enum.random(1..65_535)
      matched_transfer_id = ID.generate()

      matched_transfer = %Transfer{
        id: matched_transfer_id,
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id,
        ledger: 1,
        code: target_code,
        user_data_128: <<42::128>>
      }

      other_code_transfer = %Transfer{
        id: ID.generate(),
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id,
        ledger: 1,
        code: 1,
        user_data_128: <<42::128>>
      }

      other_user_data_transfer = %Transfer{
        id: ID.generate(),
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id,
        ledger: 1,
        code: target_code,
        user_data_128: <<1::128>>
      }

      transfers = [
        matched_transfer,
        other_code_transfer,
        other_user_data_transfer
      ]

      assert {:ok, []} = Connection.create_transfers(conn, transfers)

      query_filter = %QueryFilter{user_data_128: <<42::128>>, code: target_code, limit: 10}

      assert {:ok, [%Transfer{id: ^matched_transfer_id}]} =
               Connection.query_transfers(conn, query_filter)
    end

    test "reverses order when using the reversed flag", ctx do
      %{
        conn: conn,
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id
      } = ctx

      target_code = Enum.random(1..65_535)
      transfer_id_1 = ID.generate()

      transfer_1 = %Transfer{
        id: transfer_id_1,
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id,
        ledger: 1,
        code: target_code
      }

      transfer_id_2 = ID.generate()

      transfer_2 = %Transfer{
        id: transfer_id_2,
        credit_account_id: credit_account_id,
        debit_account_id: debit_account_id,
        ledger: 1,
        code: target_code
      }

      assert {:ok, []} = Connection.create_transfers(conn, [transfer_1, transfer_2])

      query_filter = %QueryFilter{
        code: target_code,
        limit: 10,
        flags: %QueryFilterFlags{reversed: true}
      }

      assert {:ok, [%Transfer{id: ^transfer_id_2}, %Transfer{id: ^transfer_id_1}]} =
               Connection.query_transfers(conn, query_filter)
    end
  end

  defp create_account!(conn) do
    id = ID.generate()

    account = %Account{
      id: id,
      ledger: 1,
      code: 1
    }

    {:ok, results} = Connection.create_accounts(conn, [account])
    assert [] = results

    id
  end

  defp create_transfer!(conn) do
    id = ID.generate()

    credit_account_id = create_account!(conn)
    debit_account_id = create_account!(conn)

    transfer = %Transfer{
      id: id,
      credit_account_id: credit_account_id,
      debit_account_id: debit_account_id,
      ledger: 1,
      code: 1,
      amount: 100
    }

    {:ok, results} = Connection.create_transfers(conn, [transfer])
    assert [] = results

    id
  end

  defp get_balances!(conn, account_id) do
    account_filter = %AccountFilter{
      account_id: account_id,
      limit: @max_batch_size,
      flags: %TigerBeetlex.AccountFilterFlags{debits: true, credits: true}
    }

    assert {:ok, list} = Connection.get_account_balances(conn, account_filter)

    list
  end

  defp get_account_transfers!(conn, account_id) do
    account_filter = %AccountFilter{
      account_id: account_id,
      limit: @max_batch_size,
      flags: %TigerBeetlex.AccountFilterFlags{debits: true, credits: true}
    }

    assert {:ok, list} = Connection.get_account_transfers(conn, account_filter)

    list
  end

  defp get_account!(conn, id) do
    assert {:ok, results} = Connection.lookup_accounts(conn, [id])
    assert [%Account{} = account] = results

    account
  end

  defp get_accounts!(conn, ids) do
    assert {:ok, results} = Connection.lookup_accounts(conn, ids)

    results
  end

  defp get_transfer!(conn, id) do
    assert {:ok, results} = Connection.lookup_transfers(conn, [id])
    assert [%Transfer{} = transfer] = results

    transfer
  end

  defp get_transfers!(conn, ids) do
    assert {:ok, results} = Connection.lookup_transfers(conn, ids)

    results
  end

  defp assert_account_not_existing(conn, id) do
    {:ok, results} = Connection.lookup_accounts(conn, [id])
    assert [] = results
  end

  defp assert_transfer_not_existing(conn, id) do
    {:ok, results} = Connection.lookup_accounts(conn, [id])
    assert [] = results
  end
end
