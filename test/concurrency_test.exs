defmodule TigerBeetlex.ConcurrencyTest do
  use ExUnit.Case, async: true

  alias TigerBeetlex.Account
  alias TigerBeetlex.Client
  alias TigerBeetlex.ID
  alias TigerBeetlex.Response

  setup do
    {:ok, client} = Client.new(ID.from_int(0), ["3000"])

    {:ok, client: client}
  end

  test "concurrency smoke test: 1_000 callers creating 10 accounts each using the same client",
       %{client: client} do
    tasks =
      for _ <- 1..1_000 do
        Task.async(fn ->
          for _ <- 1..10 do
            account = %Account{
              id: ID.generate(),
              ledger: 1,
              code: 1
            }

            {:ok, ref} = Client.create_accounts(client, [account])

            assert_receive {:tigerbeetlex_response, ^ref, response}, 1_000

            assert {:ok, []} = Response.decode(response)
          end
        end)
      end

    Task.await_many(tasks, 30_000)
  end
end
