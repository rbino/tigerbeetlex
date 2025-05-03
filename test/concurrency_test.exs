defmodule TigerBeetlex.ConcurrencyTest do
  use ExUnit.Case, async: true

  alias TigerBeetlex.Account
  alias TigerBeetlex.Client
  alias TigerBeetlex.Response

  setup do
    {:ok, client} = Client.new(<<0::128>>, ["3000"])

    {:ok, client: client}
  end

  test "concurrency smoke test: 1_000 callers creating 10 accounts each using the same client",
       %{client: client} do
    for _ <- 1..1_000 do
      Task.async(fn ->
        for _ <- 1..10 do
          account = %Account{
            id: random_id(),
            ledger: 1,
            code: 1
          }

          {:ok, ref} = Client.create_accounts(client, [account])

          assert_receive {:tigerbeetlex_response, ^ref, response}, 1_000

          assert {:ok, []} = Response.decode(response)
        end
      end)
    end
    |> Task.await_many(30_000)
  end

  defp random_id do
    Uniq.UUID.uuid7(:raw)
  end
end
