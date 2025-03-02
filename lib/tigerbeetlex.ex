defmodule TigerBeetlex do
  @moduledoc """
  Processless API.

  This module exposes a processless API to the TigerBeetle NIF client. The responses from the NIF
  arrive in the form of messages. This allows to integrate the client in an existing process
  architecture without spawning any other processes.
  """

  use TypedStruct

  typedstruct do
    field :ref, reference(), enforce: true
  end

  alias TigerBeetlex.Account
  alias TigerBeetlex.AccountFilter
  alias TigerBeetlex.NifAdapter
  alias TigerBeetlex.QueryFilter
  alias TigerBeetlex.Transfer
  alias TigerBeetlex.Types

  @doc """
  Creates a processless TigerBeetlex client.

  The returned client can be safely shared between multiple processes. Each process will receive
  the responses to the requests it submits.

  ## Arguments

  - `cluster_id` (128-bit binary ID): - The TigerBeetle cluster id.
  - `addresses` (list of `String.t()`) - The list of node addresses. These can either be a single
  digit (e.g. `"3000"`), which is interpreted as a port on `127.0.0.1`, an IP address + port (e.g.
  `"127.0.0.1:3000"`), or just an IP address (e.g. `"127.0.0.1"`), which defaults to port `3001`.

  ## Examples

      {:ok, client} = TigerBeetlex.connect(<<0::128>>, ["3000"])
  """
  @spec connect(
          cluster_id :: Types.id_128(),
          addresses :: [binary()]
        ) ::
          {:ok, t()} | {:error, Types.client_init_error()}
  def connect(<<_::128>> = cluster_id, addresses)
      when is_list(addresses) do
    joined_addresses = Enum.join(addresses, ",")

    with {:ok, ref} <- NifAdapter.client_init(cluster_id, joined_addresses) do
      {:ok, %__MODULE__{ref: ref}}
    end
  end

  @doc """
  Creates a batch of accounts.

  `client` is a `TigerBeetlex` client.

  `accounts` is a list of `TigerBeetlex.Account` structs.

  The function returns a ref which can be used to match the received response message.

  The response message has this format:

      {:tigerbeetlex_response, request_ref, response}

  Where `request_ref` is the same `ref` returned when this function was called and `response` is
  a response that can be decoded using `TigerBeetlex.Response.decode/1`.

  The value returned from `TigerBeetlex.Response.decode(response)` will either be
  `{:error, reason}` or `{:ok, results}`.

  `results` is a list of `TigerBeetlex.CreateAccountsResult` structs
  which contain the index of the account list and the reason of the failure. An account has a
  corresponding `TigerBeetlex.CreateAccountsResult` only if it fails to be created, otherwise
  the account has been created succesfully (so a successful request returns an empty list).

  See [`create_accounts`](https://docs.tigerbeetle.com/reference/requests/create_accounts/).

  ## Examples
      alias TigerBeetlex.Account

      # Successful request
      accounts = [%Account{id: <<42::128>>, ledger: 3, code: 4}]

      {:ok, ref} = TigerBeetlex.create_accounts(client, accounts)

      receive do
        {:tigerbeetlex_response, ^ref, response} -> TigerBeetlex.Response.decode(response)
      end

      #=> {:ok, []}

      # Creation error
      accounts = [%Account{id: <<0::128>>, ledger: 3, code: 4}]

      {:ok, ref} = TigerBeetlex.create_accounts(client, accounts)

      receive do
        {:tigerbeetlex_response, ^ref, response} -> TigerBeetlex.Response.decode(response)
      end

      #=> {:ok, [%TigerBeetlex.CreateAccountsResult{index: 0, reason: :id_must_not_be_zero}]}
  """
  @spec create_accounts(client :: t(), accounts :: [Account.t()]) ::
          {:ok, reference()} | {:error, Types.request_error()}
  def create_accounts(%__MODULE__{} = client, accounts) when is_list(accounts) do
    accounts
    |> structs_to_binary(Account)
    |> then(&NifAdapter.create_accounts(client.ref, &1))
  end

  @doc """
  Creates a batch of transfers.

  `client` is a `%TigerBeetlex{}` client.

  `transfers` is a list of `TigerBeetlex.Transfer` structs.

  The function returns a ref which can be used to match the received response message.

  The response message has this format:

      {:tigerbeetlex_response, request_ref, response}

  Where `request_ref` is the same `ref` returned when this function was called and `response` is
  a response that can be decoded using `TigerBeetlex.Response.decode/1`.

  The value returned from `TigerBeetlex.Response.decode(response)` will either be
  `{:error, reason}` or `{:ok, results}`.

  `results` is a list of `TigerBeetlex.CreateTransfersResult` structs
  which contain the index of the transfer list and the reason of the failure. A transfer has a
  corresponding `TigerBeetlex.CreateTransfersResult` only if it fails to be created, otherwise
  the transfer has been created succesfully (so a successful request returns an empty list).

  See [`create_transfers`](https://docs.tigerbeetle.com/reference/requests/create_transfers/).

  ## Examples
      alias TigerBeetlex.Transfer

      # Successful request
      transfers = [
        %Transfer{
          id: <<42::128>>,
          debit_account_id: <<42::128>>,
          credit_account_id: <<43::128>>,
          ledger: 3,
          code: 4
          amount: 100
        }
      ]

      {:ok, ref} = TigerBeetlex.create_transfers(client, transfers)

      receive do
        {:tigerbeetlex_response, ^ref, response} -> TigerBeetlex.Response.decode(response)
      end

      #=> {:ok, []}

      # Creation error
      transfers = [
        %Transfer{
          id: <<0::128>>,
          debit_account_id: <<42::128>>,
          credit_account_id: <<43::128>>,
          ledger: 3,
          code: 4
          amount: 100
        }
      ]

      {:ok, ref} = TigerBeetlex.create_transfers(client, transfers)

      receive do
        {:tigerbeetlex_response, ^ref, response} -> TigerBeetlex.Response.decode(response)
      end

      #=> {:ok, [%TigerBeetlex.CreateTransfersResult{index: 0, reason: :id_must_not_be_zero}]}
  """
  @spec create_transfers(client :: t(), transfers :: [Transfer.t()]) ::
          {:ok, reference()} | {:error, Types.request_error()}
  def create_transfers(%__MODULE__{} = client, transfers) when is_list(transfers) do
    transfers
    |> structs_to_binary(Transfer)
    |> then(&NifAdapter.create_transfers(client.ref, &1))
  end

  @doc """
  Fetch a list of historical `TigerBeetlex.AccountBalance` for a given `TigerBeetlex.Account`.

  Only accounts created with the `history` flag set retain historical balances. This is off by default.

  `client` is a `%TigerBeetlex{}` client.

  `account_filter` is a `TigerBeetlex.AccountFilter` struct. The `limit` field must be set.

  The function returns a ref which can be used to match the received response message.

  The response message has this format:

      {:tigerbeetlex_response, request_ref, response}

  Where `request_ref` is the same `ref` returned when this function was called and `response` is
  a response that can be decoded using `TigerBeetlex.Response.decode/1`.

  The value returned from `TigerBeetlex.Response.decode(response)` will either be
  `{:error, reason}` or `{:ok, results}`, where `results` is a list of `TigerBeetlex.AccountBalance`
  structs.

  See [`get_account_balances`](https://docs.tigerbeetle.com/reference/requests/get_account_balances/).

  ## Examples
      alias TigerBeetlex.AccountFilter

      account_filter = %AccountFilter{id: <<42::128>>, limit: 10}

      {:ok, ref} = TigerBeetlex.get_account_balances(client, account_filter)

      receive do
        {:tigerbeetlex_response, ^ref, response} -> TigerBeetlex.Response.decode(response)
      end

      #=> {:ok, [%TigerBeetlex.AccountBalance{}]}
  """
  @spec get_account_balances(client :: t(), account_filter :: AccountFilter.t()) ::
          {:ok, reference()} | {:error, Types.request_error()}
  def get_account_balances(%__MODULE__{} = client, %AccountFilter{} = account_filter) do
    account_filter
    |> AccountFilter.to_binary()
    |> then(&NifAdapter.get_account_balances(client.ref, &1))
  end

  @doc """
  Fetch a list of `%TigerBeetlex.Transfer{}` involving a `%TigerBeetlex.Account{}`.

  `client` is a `%TigerBeetlex{}` client.

  `account_filter` is a `TigerBeetlex.AccountFilter` struct. The `limit` field must be set.

  The function returns a ref which can be used to match the received response message.

  The response message has this format:

      {:tigerbeetlex_response, request_ref, response}

  Where `request_ref` is the same `ref` returned when this function was called and `response` is
  a response that can be decoded using `TigerBeetlex.Response.decode/1`.

  The value returned from `TigerBeetlex.Response.decode(response)` will either be
  `{:error, reason}` or `{:ok, results}`, where `results` is a list of `TigerBeetlex.Transfer`
  structs.

  See [`get_account_transfers`](https://docs.tigerbeetle.com/reference/requests/get_account_transfers/).

  ## Examples
      alias TigerBeetlex.AccountFilter

      account_filter = %AccountFilter{id: <<42::128>>, limit: 10}

      {:ok, ref} = TigerBeetlex.get_account_balances(client, account_filter)

      receive do
        {:tigerbeetlex_response, ^ref, response} -> TigerBeetlex.Response.decode(response)
      end

      #=> {:ok, [%TigerBeetlex.Transfer{}]}
  """
  @spec get_account_transfers(client :: t(), account_filter :: AccountFilter.t()) ::
          {:ok, reference()} | {:error, Types.request_error()}
  def get_account_transfers(%__MODULE__{} = client, %AccountFilter{} = account_filter) do
    account_filter
    |> AccountFilter.to_binary()
    |> then(&NifAdapter.get_account_transfers(client.ref, &1))
  end

  @doc """
  Lookup a batch of accounts.

  `client` is a `%TigerBeetlex{}` client.

  `ids` is a list of 128-bit binaries.

  The function returns a ref which can be used to match the received response message.

  The response message has this format:

      {:tigerbeetlex_response, request_ref, response}

  Where `request_ref` is the same `ref` returned when this function was called and `response` is
  a response that can be decoded using `TigerBeetlex.Response.decode/1`.

  The value returned from `TigerBeetlex.Response.decode(response)` will either be
  `{:error, reason}` or `{:ok, results}`.

  `results` is a list of `TigerBeetlex.Account` structs. If an id in the list does not
  correspond to an existing account, it will simply be skipped, so the result could have less
  accounts then the provided ids.

  See [`lookup_accounts`](https://docs.tigerbeetle.com/reference/requests/lookup_accounts/).

  ## Examples

      ids = [<<42::128>>]

      {:ok, ref} = TigerBeetlex.lookup_accounts(client, ids)

      receive do
        {:tigerbeetlex_response, ^ref, response} -> TigerBeetlex.Response.decode(response)
      end

      #=> {:ok, [%TigerBeetlex.Account{}]}
  """
  @spec lookup_accounts(client :: t(), ids :: [Types.id_128()]) ::
          {:ok, reference()} | {:error, Types.request_error()}
  def lookup_accounts(%__MODULE__{} = client, ids) when is_list(ids) do
    ids
    |> join_ids()
    |> then(&NifAdapter.lookup_accounts(client.ref, &1))
  end

  @doc """
  Lookup a batch of transfers.

  `client` is a `%TigerBeetlex{}` client.

  `ids` is a list of 128-bit binaries.

  The function returns a ref which can be used to match the received response message.

  The response message has this format:

      {:tigerbeetlex_response, request_ref, response}

  Where `request_ref` is the same `ref` returned when this function was called and `response` is
  a response that can be decoded using `TigerBeetlex.Response.decode/1`.

  The value returned from `TigerBeetlex.Response.decode(response)` will either be
  `{:error, reason}` or `{:ok, results}`.

  `results` is list of `TigerBeetlex.Transfer` structs. If an id in the list does not correspond
  to an existing transfer, it will simply be skipped, so the result could have less accounts then
  the provided ids.

  See [`lookup_transfers`](https://docs.tigerbeetle.com/reference/requests/lookup_transfers/).

  ## Examples

      ids = [<<42::128>>]

      {:ok, ref} = TigerBeetlex.lookup_transfers(client, ids)

      receive do
        {:tigerbeetlex_response, ^ref, response} -> TigerBeetlex.Response.decode(response)
      end

      #=> {:ok, [%TigerBeetlex.Transfer{}]}
  """
  @spec lookup_transfers(client :: t(), ids :: [Types.id_128()]) ::
          {:ok, reference()} | {:error, Types.request_error()}
  def lookup_transfers(%__MODULE__{} = client, ids) when is_list(ids) do
    ids
    |> join_ids()
    |> then(&NifAdapter.lookup_transfers(client.ref, &1))
  end

  @doc """
  Query accounts by the intersection of some fields and by timestamp range.

  `client` is a `%TigerBeetlex{}` client.

  `query_filter` is a `TigerBeetlex.QueryFilter` struct. The `limit` field must be set.

  The function returns a ref which can be used to match the received response message.

  The response message has this format:

      {:tigerbeetlex_response, request_ref, response}

  Where `request_ref` is the same `ref` returned when this function was called and `response` is
  a response that can be decoded using `TigerBeetlex.Response.decode/1`.

  The value returned from `TigerBeetlex.Response.decode(response)` will either be
  `{:error, reason}` or `{:ok, results}`.

  `results` is a list of `TigerBeetlex.Account` structs that match `query_filter`.

  See [`query_accounts`](https://docs.tigerbeetle.com/reference/requests/query_accounts/).

  ## Examples
      alias TigerBeetlex.QueryFilter

      query_filter = %QueryFilter{user_data_128: <<42::128>>, limit: 10}

      {:ok, ref} = TigerBeetlex.query_accounts(client, query_filter)

      receive do
        {:tigerbeetlex_response, ^ref, response} -> TigerBeetlex.Response.decode(response)
      end

      #=> {:ok, [%TigerBeetlex.Account{}]}
  """
  @spec query_accounts(client :: t(), query_filter :: QueryFilter.t()) ::
          {:ok, reference()} | {:error, Types.request_error()}
  def query_accounts(%__MODULE__{} = client, %QueryFilter{} = query_filter) do
    query_filter
    |> QueryFilter.to_binary()
    |> then(&NifAdapter.query_accounts(client.ref, &1))
  end

  @doc """
  Query transfers by the intersection of some fields and by timestamp range.

  `client` is a `%TigerBeetlex{}` client.

  `query_filter` is a `TigerBeetlex.QueryFilter` struct. The `limit` field must be set.

  The function returns a ref which can be used to match the received response message.

  The response message has this format:

      {:tigerbeetlex_response, request_ref, response}

  Where `request_ref` is the same `ref` returned when this function was called and `response` is
  a response that can be decoded using `TigerBeetlex.Response.decode/1`.

  The value returned from `TigerBeetlex.Response.decode(response)` will either be
  `{:error, reason}` or `{:ok, results}`.

  `results` is a list of `TigerBeetlex.Transfer` structs that match `query_filter`.

  See [`query_transfers`](https://docs.tigerbeetle.com/reference/requests/query_transfers/).

  ## Examples
      alias TigerBeetlex.QueryFilter

      query_filter = %QueryFilter{user_data_128: <<42::128>>, limit: 10}

      {:ok, ref} = TigerBeetlex.query_transfers(client, ids)

      receive do
        {:tigerbeetlex_response, ^ref, response} -> TigerBeetlex.Response.decode(response)
      end

      #=> {:ok, [%TigerBeetlex.Transfer{}]}
  """
  @spec query_transfers(client :: t(), query_filter :: QueryFilter.t()) ::
          {:ok, reference()} | {:error, Types.request_error()}
  def query_transfers(%__MODULE__{} = client, %QueryFilter{} = query_filter) do
    query_filter
    |> QueryFilter.to_binary()
    |> then(&NifAdapter.query_transfers(client.ref, &1))
  end

  defp join_ids(ids) do
    for id <- ids, into: "", do: id
  end

  defp structs_to_binary(structs, struct_module) do
    for struct <- structs, into: "" do
      struct_module.to_binary(struct)
    end
  end
end
