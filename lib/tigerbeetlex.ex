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

  alias TigerBeetlex.AccountBatch
  alias TigerBeetlex.IDBatch
  alias TigerBeetlex.NifAdapter
  alias TigerBeetlex.TransferBatch
  alias TigerBeetlex.Types

  @doc """
  Creates a processless TigerBeetlex client.

  The returned client can be safely shared between multiple processes. Each process will receive
  the responses to the requests it submits.

  ## Arguments

  - `cluster_id` (`non_neg_integer/0`): - The TigerBeetle cluster id.
  - `addresses` (list of `String.t()`) - The list of node addresses. These can either be a single
  digit (e.g. `"3000"`), which is interpreted as a port on `127.0.0.1`, an IP address + port (e.g.
  `"127.0.0.1:3000"`), or just an IP address (e.g. `"127.0.0.1"`), which defaults to port `3001`.
  - `concurrency_max` (`pos_integer/0`) - The maximum number of concurrent requests the client can
  handle. 32 is a good default, and can be increased to 4096 if there's the need of increased
  throughput.

  ## Examples

      {:ok, client} = TigerBeetlex.connect(0, ["3000"], 32)
  """
  @spec connect(
          cluster_id :: non_neg_integer(),
          addresses :: [binary()],
          concurrency_max :: pos_integer()
        ) ::
          {:ok, t()} | Types.client_init_errors()
  def connect(cluster_id, addresses, concurrency_max)
      when cluster_id >= 0 and is_list(addresses) and is_integer(concurrency_max) and
             concurrency_max > 0 do
    joined_addresses = Enum.join(addresses, ",")

    with {:ok, ref} <- NifAdapter.client_init(cluster_id, joined_addresses, concurrency_max) do
      {:ok, %__MODULE__{ref: ref}}
    end
  end

  @doc """
  Creates a batch of accounts.

  `client` is a `%TigerBeetlex{}` client.

  `account_batch` is a `%TigerBeetlex.AccountBatch{}`, see `TigerBeetlex.AccountBatch` for
  the functions to create and manipulate it.

  The function returns a ref which can be used to match the received response message.

  The response message has this format:

      {:tigerbeetlex_response, request_ref, response}

  Where `request_ref` is the same `ref` returned when this function was called and `response` is
  a response that can be decoded using `TigerBeetlex.Response.to_stream/1`.

  The value returned from `TigerBeetlex.Response.to_stream(response)` will either be
  `{:error, reason}` or `{:ok, stream}`.

  `stream` is an enumerable that can lazily produce `%TigerBeetlex.CreateAccountError{}` structs
  which contain the index of the account batch and the reason of the failure. An account has a
  corresponding `%TigerBeetlex.CreateAccountError{}` only if it fails to be created, otherwise
  the account has been created succesfully (so a successful request returns an empty stream).

  ## Examples

      # Successful request
      {:ok, batch} = TigerBeetlex.AccountBatch.new(10)

      {:ok, batch} =
        TigerBeetlex.AccountBatch.add_account(batch, id: <<42::128>>, ledger: 3, code: 4)

      {:ok, ref} = TigerBeetlex.create_accounts(client, batch)

      {:ok, stream} =
        receive do
          {:tigerbeetlex_response, ^ref, response} -> TigerBeetlex.Response.to_stream(response)
        end

      Enum.to_list(stream)
      #=> []

      # Creation error
      {:ok, batch} = TigerBeetlex.AccountBatch.new(10)

      {:ok, batch} =
        TigerBeetlex.AccountBatch.add_account(batch, id: <<0::128>>, ledger: 3, code: 4)

      {:ok, ref} = TigerBeetlex.create_accounts(client, batch)

      {:ok, stream} =
        receive do
          {:tigerbeetlex_response, ^ref, response} -> TigerBeetlex.Response.to_stream(response)
        end

      Enum.to_list(stream)
      #=> [%TigerBeetlex.CreateAccountError{index: 0, reason: :id_must_not_be_zero}]
  """
  @spec create_accounts(client :: t(), account_batch :: TigerBeetlex.AccountBatch.t()) ::
          {:ok, reference()} | Types.create_accounts_errors()
  def create_accounts(%__MODULE__{} = client, %AccountBatch{} = account_batch) do
    NifAdapter.create_accounts(client.ref, account_batch.ref)
  end

  @doc """
  Creates a batch of transfers.

  `client` is a `%TigerBeetlex{}` client.

  `transfer_batch` is a `%TigerBeetlex.TransferBatch{}`, see `TigerBeetlex.TransferBatch` for
  the functions to create and manipulate it.

  The function returns a ref which can be used to match the received response message.

  The response message has this format:

      {:tigerbeetlex_response, request_ref, response}

  Where `request_ref` is the same `ref` returned when this function was called and `response` is
  a response that can be decoded using `TigerBeetlex.Response.to_stream/1`.

  The value returned from `TigerBeetlex.Response.to_stream(response)` will either be
  `{:error, reason}` or `{:ok, stream}`.

  `stream` is an enumerable that can lazily produce `%TigerBeetlex.CreateTransferError{}` structs
  which contain the index of the transfer batch and the reason of the failure. An transfer has a
  corresponding `%TigerBeetlex.CreateTransferError{}` only if it fails to be created, otherwise
  the transfer has been created succesfully (so a successful request returns an empty stream).

  ## Examples

      # Successful request
      {:ok, batch} = TigerBeetlex.TransferBatch.new(10)

      {:ok, batch} =
        TigerBeetlex.TransferBatch.add_transfer(batch,
          id: <<42::128>>,
          debit_account_id: <<42::128>>,
          credit_account_id: <<43::128>>,
          ledger: 3,
          code: 4
          amount: 100
        )

      {:ok, ref} = TigerBeetlex.create_transfers(client, batch)

      {:ok, stream} =
        receive do
          {:tigerbeetlex_response, ^ref, response} -> TigerBeetlex.Response.to_stream(response)
        end

      Enum.to_list(stream)
      #=> []

      # Creation error
      {:ok, batch} = TigerBeetlex.TransferBatch.new(10)

      {:ok, batch} =
        TigerBeetlex.TransferBatch.add_transfer(batch,
          id: <<42::128>>,
          debit_account_id: <<42::128>>,
          credit_account_id: <<43::128>>,
          ledger: 3,
          code: 4
          amount: 100
        )

      {:ok, ref} = TigerBeetlex.create_transfers(client, batch)

      {:ok, stream} =
        receive do
          {:tigerbeetlex_response, ^ref, response} -> TigerBeetlex.Response.to_stream(response)
        end

      Enum.to_list(stream)
      #=> [%TigerBeetlex.CreateTransferError{index: 0, reason: :id_must_not_be_zero}]
  """
  @spec create_transfers(client :: t(), transfer_batch :: TigerBeetlex.TransferBatch.t()) ::
          {:ok, reference()} | Types.create_transfers_errors()
  def create_transfers(%__MODULE__{} = client, %TransferBatch{} = transfer_batch) do
    NifAdapter.create_transfers(client.ref, transfer_batch.ref)
  end

  @doc """
  Lookup a batch of accounts.

  `client` is a `%TigerBeetlex{}` client.

  `id_batch` is a `%TigerBeetlex.IDBatch{}`, see `TigerBeetlex.IDBatch` for the functions to
  create and manipulate it.

  The function returns a ref which can be used to match the received response message.

  The response message has this format:

      {:tigerbeetlex_response, request_ref, response}

  Where `request_ref` is the same `ref` returned when this function was called and `response` is
  a response that can be decoded using `TigerBeetlex.Response.to_stream/1`.

  The value returned from `TigerBeetlex.Response.to_stream(response)` will either be
  `{:error, reason}` or `{:ok, stream}`.

  `stream` is an enumerable that can lazily produce `%TigerBeetlex.Account{}` structs. If an id in
  the batch does not correspond to an existing account, it will simply be skipped, so the result
  could have less accounts then the provided ids in the id batch.

  ## Examples

      {:ok, batch} = TigerBeetlex.IDBatch.new(10)

      {:ok, batch} = TigerBeetlex.IDBatch.add_id(batch, <<42::128>>)

      {:ok, ref} = TigerBeetlex.lookup_accounts(client, batch)

      {:ok, stream} =
        receive do
          {:tigerbeetlex_response, ^ref, response} -> TigerBeetlex.Response.to_stream(response)
        end

      Enum.to_list(stream)
      #=> [%TigerBeetlex.Account{}]
  """
  @spec lookup_accounts(client :: t(), id_batch :: TigerBeetlex.IDBatch.t()) ::
          {:ok, reference()} | Types.lookup_accounts_errors()
  def lookup_accounts(%__MODULE__{} = client, %IDBatch{} = id_batch) do
    NifAdapter.lookup_accounts(client.ref, id_batch.ref)
  end

  @doc """
  Lookup a batch of transfers.

  `client` is a `%TigerBeetlex{}` client.

  `id_batch` is a `%TigerBeetlex.IDBatch{}`, see `TigerBeetlex.IDBatch` for the functions to
  create and manipulate it.

  The function returns a ref which can be used to match the received response message.

  The response message has this format:

      {:tigerbeetlex_response, request_ref, response}

  Where `request_ref` is the same `ref` returned when this function was called and `response` is
  a response that can be decoded using `TigerBeetlex.Response.to_stream/1`.

  The value returned from `TigerBeetlex.Response.to_stream(response)` will either be
  `{:error, reason}` or `{:ok, stream}`.

  `stream` is an enumerable that can lazily produce `%TigerBeetlex.Transfer{}` structs. If an id in
  the batch does not correspond to an existing transfer, it will simply be skipped, so the result
  could have less accounts then the provided ids in the id batch.

  ## Examples

      {:ok, batch} = TigerBeetlex.IDBatch.new(10)

      {:ok, batch} = TigerBeetlex.IDBatch.add_id(batch, <<42::128>>)

      {:ok, ref} = TigerBeetlex.lookup_transfers(client, batch)

      {:ok, stream} =
        receive do
          {:tigerbeetlex_response, ^ref, response} -> TigerBeetlex.Response.to_stream(response)
        end

      Enum.to_list(stream)
      #=> [%TigerBeetlex.Transfer{}]
  """
  @spec lookup_transfers(client :: t(), id_batch :: TigerBeetlex.IDBatch.t()) ::
          {:ok, reference()} | Types.lookup_transfers_errors()
  def lookup_transfers(%__MODULE__{} = client, %IDBatch{} = id_batch) do
    NifAdapter.lookup_transfers(client.ref, id_batch.ref)
  end
end
