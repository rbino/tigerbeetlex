defmodule Tigerbeetlex.ClientTest do
  use ExUnit.Case, async: true

  alias TigerBeetlex.Account
  alias TigerBeetlex.Client
  alias TigerBeetlex.CreateAccountsResult
  alias TigerBeetlex.ID

  describe "new/2" do
    test "returns a client with valid parameters" do
      assert {:ok, %Client{}} = Client.new(ID.from_int(0), ["3000"])
    end

    test "returns :invalid_address for invalid address" do
      assert {:error, :invalid_address} = Client.new(ID.from_int(0), ["foobar"])
    end

    test "returns :address_limit_exceeded for too many addresses" do
      addresses = Enum.map(3000..3010, &to_string/1)
      assert {:error, :address_limit_exceeded} = Client.new(ID.from_int(0), addresses)
    end
  end

  describe "receive_and_decode/1" do
    setup do
      {:ok, client} = Client.new(ID.from_int(0), ["3000"])

      %{client: client}
    end

    test "blocks on the request and returns the result", %{client: client} do
      accounts = [%Account{id: ID.from_int(0), ledger: 3, code: 4}]

      {:ok, ref} = Client.create_accounts(client, accounts)

      assert Client.receive_and_decode(ref) ==
               {:ok, [%CreateAccountsResult{index: 0, result: :id_must_not_be_zero}]}
    end
  end
end
