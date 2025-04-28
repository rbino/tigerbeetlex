defmodule TigerbeetlexTest do
  use ExUnit.Case, async: true

  alias TigerBeetlex.Account
  alias TigerBeetlex.CreateAccountsResult

  describe "receive_and_decode/1" do
    setup do
      {:ok, client} = TigerBeetlex.connect(<<0::128>>, ["3000"])

      %{client: client}
    end

    test "blocks on the request and returns the result", %{client: client} do
      accounts = [%Account{id: <<0::128>>, ledger: 3, code: 4}]

      {:ok, ref} = TigerBeetlex.create_accounts(client, accounts)

      assert TigerBeetlex.receive_and_decode(ref) ==
               {:ok, [%CreateAccountsResult{index: 0, result: :id_must_not_be_zero}]}
    end
  end
end
