defmodule TigerBeetlex.Client do
  @moduledoc """
  Message based API.

  This module exposes a message based API to the TigerBeetle NIF client. The responses from the NIF
  arrive in the form of messages. This allows to integrate the client in an existing process
  architecture without spawning any other processes.

  ## Response decoding

  When submitting a request through a function in this module, the response is received via message.

  All the functions performing a TigerBeetle request return a ref which can be used to match the
  received response message.

  The response message can be received with this receive pattern:

      {:ok, request_ref} = Client.create_accounts(client, accounts)

      {:ok, results} =
        receive do
          {:tigerbeetlex_response, ^request_ref, response} ->
            TigerBeetlex.Response.decode(response)
        end
      end

  Where `request_ref` is the `ref` returned when the request was submitted. `response` can then be
  decoded using `TigerBeetlex.Response.decode/1`.

  The value returned from `TigerBeetlex.Response.decode(response)` will either be `{:error, reason}`
  or `{:ok, results}`.

  The type of `results` will depend on the operation that was submitted.

  If the caller is a `GenServer` or similar process, it should pattern match for the response tuple
  in its `handle_info` callback.

  ### `receive_and_decode/1`

  If the response is the only message you need to receive, you can call `Client.receive_and_decode/1`
  as a shorthand for the `receive` block above.

      {:ok, request_ref} = Client.create_accounts(client, accounts)
      {:ok, results} = Client.receive_and_decode(request_ref)
  """

  use TypedStruct

  alias TigerBeetlex.Account
  alias TigerBeetlex.AccountFilter
  alias TigerBeetlex.NifAdapter
  alias TigerBeetlex.Operation
  alias TigerBeetlex.QueryFilter
  alias TigerBeetlex.Transfer
  alias TigerBeetlex.Types

  require Operation

  typedstruct do
    field :ref, reference(), enforce: true
  end

  @doc """
  Creates a message based TigerBeetlex client.

  The returned client can be safely shared between multiple processes. Each process will receive
  the responses to the requests it submits.

  ## Arguments

  - `cluster_id` (128-bit binary ID): - The TigerBeetle cluster id.
  - `addresses` (list of `String.t()`) - The list of node addresses. These can either be a single
  digit (e.g. `"3000"`), which is interpreted as a port on `127.0.0.1`, an IP address + port (e.g.
  `"127.0.0.1:3000"`), or just an IP address (e.g. `"127.0.0.1"`), which defaults to port `3001`.

  ## Examples

      alias TigerBeetlex.ID

      {:ok, client} = Client.new(ID.from_int(0), ["3000"])
  """
  @spec new(
          cluster_id :: Types.id_128(),
          addresses :: [binary()]
        ) ::
          {:ok, t()} | {:error, Types.init_client_error()}
  def new(<<_::128>> = cluster_id, addresses) when is_list(addresses) do
    joined_addresses = Enum.join(addresses, ",")

    with {:ok, ref} <- NifAdapter.init_client(cluster_id, joined_addresses) do
      {:ok, %__MODULE__{ref: ref}}
    end
  end

  @doc """
  Creates a batch of accounts.

  `client` is a `TigerBeetlex.Client` struct.

  `accounts` is a list of `TigerBeetlex.Account` structs.

  The decoded `results` are a list of `TigerBeetlex.CreateAccountsResult` structs
  which contain the index of the account list and the reason of the failure. An account has a
  corresponding `TigerBeetlex.CreateAccountsResult` only if it fails to be created, otherwise
  the account has been created succesfully (so a successful request returns an empty list).

  See [`create_accounts`](https://docs.tigerbeetle.com/reference/requests/create_accounts/).

  ## Examples
      alias TigerBeetlex.Account
      alias TigerBeetlex.ID

      # Successful request
      accounts = [%Account{id: ID.generate(), ledger: 3, code: 4}]

      {:ok, ref} = Client.create_accounts(client, accounts)

      Client.receive_and_decode(ref)

      #=> {:ok, []}

      # Creation error
      accounts = [%Account{id: ID.from_int(0), ledger: 3, code: 4}]

      {:ok, ref} = Client.create_accounts(client, accounts)

      Client.receive_and_decode(ref)

      #=> {:ok, [%TigerBeetlex.CreateAccountsResult{index: 0, result: :id_must_not_be_zero}]}
  """
  @spec create_accounts(client :: t(), accounts :: [Account.t()]) ::
          {:ok, reference()} | {:error, Types.request_error()}
  def create_accounts(%__MODULE__{} = client, accounts) when is_list(accounts) do
    operation = Operation.from_atom(:create_accounts)
    payload = structs_to_iolist(accounts, Account, [])
    NifAdapter.submit(client.ref, operation, payload)
  end

  @doc """
  Creates a batch of transfers.

  `client` is a `TigerBeetlex.Client` struct.

  `transfers` is a list of `TigerBeetlex.Transfer` structs.

  The decoded `results` are a list of `TigerBeetlex.CreateTransfersResult` structs
  which contain the index of the transfer list and the reason of the failure. A transfer has a
  corresponding `TigerBeetlex.CreateTransfersResult` only if it fails to be created, otherwise
  the transfer has been created succesfully (so a successful request returns an empty list).

  See [`create_transfers`](https://docs.tigerbeetle.com/reference/requests/create_transfers/).

  ## Examples
      alias TigerBeetlex.ID
      alias TigerBeetlex.Transfer

      # Successful request
      transfers = [
        %Transfer{
          id: ID.generate(),
          debit_account_id: ID.from_int(42),
          credit_account_id: ID.from_int(43),
          ledger: 3,
          code: 4
          amount: 100
        }
      ]

      {:ok, ref} = Client.create_transfers(client, transfers)

      Client.receive_and_decode(ref)

      #=> {:ok, []}

      # Creation error
      transfers = [
        %Transfer{
          id: ID.from_int(0),
          debit_account_id: ID.from_int(42),
          credit_account_id: ID.from_int(43),
          ledger: 3,
          code: 4
          amount: 100
        }
      ]

      {:ok, ref} = Client.create_transfers(client, transfers)

      Client.receive_and_decode(ref)

      #=> {:ok, [%TigerBeetlex.CreateTransfersResult{index: 0, result: :id_must_not_be_zero}]}
  """
  @spec create_transfers(client :: t(), transfers :: [Transfer.t()]) ::
          {:ok, reference()} | {:error, Types.request_error()}
  def create_transfers(%__MODULE__{} = client, transfers) when is_list(transfers) do
    operation = Operation.from_atom(:create_transfers)
    payload = structs_to_iolist(transfers, Transfer, [])
    NifAdapter.submit(client.ref, operation, payload)
  end

  @doc """
  Fetch a list of historical `TigerBeetlex.AccountBalance` for a given `TigerBeetlex.Account`.

  Only accounts created with the `history` flag set retain historical balances. This is off by default.

  `client` is a `TigerBeetlex.Client` struct.

  `account_filter` is a `TigerBeetlex.AccountFilter` struct. The `limit` field must be set.

  The decoded `results` are a list of `TigerBeetlex.AccountBalance` structs that match `account_filter`.

  See [`get_account_balances`](https://docs.tigerbeetle.com/reference/requests/get_account_balances/).

  ## Examples
      alias TigerBeetlex.AccountFilter
      alias TigerBeetlex.ID

      account_filter = %AccountFilter{id: ID.from_int(42), limit: 10}

      {:ok, ref} = Client.get_account_balances(client, account_filter)

      Client.receive_and_decode(ref)

      #=> {:ok, [%TigerBeetlex.AccountBalance{}]}
  """
  @spec get_account_balances(client :: t(), account_filter :: AccountFilter.t()) ::
          {:ok, reference()} | {:error, Types.request_error()}
  def get_account_balances(%__MODULE__{} = client, %AccountFilter{} = account_filter) do
    operation = Operation.from_atom(:get_account_balances)
    payload = AccountFilter.to_binary(account_filter)
    NifAdapter.submit(client.ref, operation, payload)
  end

  @doc """
  Fetch a list of `%TigerBeetlex.Transfer{}` involving a `%TigerBeetlex.Account{}`.

  `client` is a `TigerBeetlex.Client` struct.

  `account_filter` is a `TigerBeetlex.AccountFilter` struct. The `limit` field must be set.

  The decoded `results` are a list of `TigerBeetlex.Transfer` structs that match `account_filter`.

  See [`get_account_transfers`](https://docs.tigerbeetle.com/reference/requests/get_account_transfers/).

  ## Examples
      alias TigerBeetlex.AccountFilter
      alias TigerBeetlex.ID

      account_filter = %AccountFilter{id: ID.from_int(42), limit: 10}

      {:ok, ref} = Client.get_account_balances(client, account_filter)

      Client.receive_and_decode(ref)

      #=> {:ok, [%TigerBeetlex.Transfer{}]}
  """
  @spec get_account_transfers(client :: t(), account_filter :: AccountFilter.t()) ::
          {:ok, reference()} | {:error, Types.request_error()}
  def get_account_transfers(%__MODULE__{} = client, %AccountFilter{} = account_filter) do
    operation = Operation.from_atom(:get_account_transfers)
    payload = AccountFilter.to_binary(account_filter)
    NifAdapter.submit(client.ref, operation, payload)
  end

  @doc """
  Lookup a batch of accounts.

  `client` is a `TigerBeetlex.Client` struct.

  `ids` is a list of 128-bit binaries.

  The decoded `results` are a list of `TigerBeetlex.Account` structs.

  See [`lookup_accounts`](https://docs.tigerbeetle.com/reference/requests/lookup_accounts/).

  ## Examples

      alias TigerBeetlex.ID

      ids = [ID.from_int(42)]

      {:ok, ref} = Client.lookup_accounts(client, ids)

      Client.receive_and_decode(ref)

      #=> {:ok, [%TigerBeetlex.Account{}]}
  """
  @spec lookup_accounts(client :: t(), ids :: [Types.id_128()]) ::
          {:ok, reference()} | {:error, Types.request_error()}
  def lookup_accounts(%__MODULE__{} = client, ids) when is_list(ids) do
    operation = Operation.from_atom(:lookup_accounts)
    NifAdapter.submit(client.ref, operation, ids)
  end

  @doc """
  Lookup a batch of transfers.

  `client` is a `TigerBeetlex.Client` struct.

  `ids` is a list of 128-bit binaries.

  The decoded `results` are a list of `TigerBeetlex.Transfer` structs.

  See [`lookup_transfers`](https://docs.tigerbeetle.com/reference/requests/lookup_transfers/).

  ## Examples

      alias TigerBeetlex.ID

      ids = [ID.from_int(42)]

      {:ok, ref} = Client.lookup_transfers(client, ids)

      Client.receive_and_decode(ref)

      #=> {:ok, [%TigerBeetlex.Transfer{}]}
  """
  @spec lookup_transfers(client :: t(), ids :: [Types.id_128()]) ::
          {:ok, reference()} | {:error, Types.request_error()}
  def lookup_transfers(%__MODULE__{} = client, ids) when is_list(ids) do
    operation = Operation.from_atom(:lookup_transfers)
    NifAdapter.submit(client.ref, operation, ids)
  end

  @doc """
  Query accounts by the intersection of some fields and by timestamp range.

  `client` is a `TigerBeetlex.Client` struct.

  `query_filter` is a `TigerBeetlex.QueryFilter` struct. The `limit` field must be set.

  The decoded `results` are a list of `TigerBeetlex.Account` structs that match `query_filter`.

  See [`query_accounts`](https://docs.tigerbeetle.com/reference/requests/query_accounts/).

  ## Examples
      alias TigerBeetlex.QueryFilter

      query_filter = %QueryFilter{ledger: 42, limit: 10}

      {:ok, ref} = Client.query_accounts(client, query_filter)

      Client.receive_and_decode(ref)

      #=> {:ok, [%TigerBeetlex.Account{}]}
  """
  @spec query_accounts(client :: t(), query_filter :: QueryFilter.t()) ::
          {:ok, reference()} | {:error, Types.request_error()}
  def query_accounts(%__MODULE__{} = client, %QueryFilter{} = query_filter) do
    operation = Operation.from_atom(:query_accounts)
    payload = QueryFilter.to_binary(query_filter)
    NifAdapter.submit(client.ref, operation, payload)
  end

  @doc """
  Query transfers by the intersection of some fields and by timestamp range.

  `client` is a `TigerBeetlex.Client` struct.

  `query_filter` is a `TigerBeetlex.QueryFilter` struct. The `limit` field must be set.

  The decoded `results` are a list of `TigerBeetlex.Transfer` structs that match `query_filter`.

  See [`query_transfers`](https://docs.tigerbeetle.com/reference/requests/query_transfers/).

  ## Examples
      alias TigerBeetlex.QueryFilter

      query_filter = %QueryFilter{ledger: 42, limit: 10}

      {:ok, ref} = Client.query_transfers(client, ids)

      Client.receive_and_decode(ref)

      #=> {:ok, [%TigerBeetlex.Transfer{}]}
  """
  @spec query_transfers(client :: t(), query_filter :: QueryFilter.t()) ::
          {:ok, reference()} | {:error, Types.request_error()}
  def query_transfers(%__MODULE__{} = client, %QueryFilter{} = query_filter) do
    operation = Operation.from_atom(:query_transfers)
    payload = QueryFilter.to_binary(query_filter)
    NifAdapter.submit(client.ref, operation, payload)
  end

  @doc """
  Utility function to receive a message response and decode it.

  This is useful to emulate blocking behavior if TigerBeetlex is the only process that
  can send messages to your process.

  Note that the function doesn't have a timeout and could block forever. This is expected
  since the TigerBeetle client
  [never times out](https://docs.tigerbeetle.com/reference/sessions/#retries).

  See all the other functions in this module for example usage.
  """
  def receive_and_decode(request_ref) when is_reference(request_ref) do
    receive do
      {:tigerbeetlex_response, ^request_ref, response} ->
        TigerBeetlex.Response.decode(response)
    end
  end

  defp structs_to_iolist([], _struct_module, acc), do: acc

  defp structs_to_iolist([struct | rest], struct_module, acc) do
    struct_binary = struct_module.to_binary(struct)
    structs_to_iolist(rest, struct_module, [acc | struct_binary])
  end
end
