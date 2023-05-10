defmodule TigerBeetlex.Client do
  use TypedStruct

  typedstruct opaque: true do
    field :ref, reference(), enforce: true
  end

  alias TigerBeetlex.Client

  alias TigerBeetlex.AccountBatch
  alias TigerBeetlex.IDBatch
  alias TigerBeetlex.NifAdapter
  alias TigerBeetlex.TransferBatch
  alias TigerBeetlex.Types

  @spec connect(
          cluster_id :: non_neg_integer(),
          addresses :: binary(),
          max_concurrency :: pos_integer()
        ) ::
          {:ok, t()} | Types.client_init_errors()
  def connect(cluster_id, addresses, max_concurrency)
      when cluster_id >= 0 and is_binary(addresses) and is_integer(max_concurrency) and
             max_concurrency > 0 do
    with {:ok, ref} <- NifAdapter.client_init(cluster_id, addresses, max_concurrency) do
      {:ok, %Client{ref: ref}}
    end
  end

  @spec create_accounts(client :: t(), account_batch :: TigerBeetlex.AccountBatch.t()) ::
          {:ok, reference()} | Types.create_accounts_errors()
  def create_accounts(%Client{} = client, %AccountBatch{} = account_batch) do
    NifAdapter.create_accounts(client.ref, account_batch.ref)
  end

  @spec create_transfers(client :: t(), transfer_batch :: TigerBeetlex.TransferBatch.t()) ::
          {:ok, reference()} | Types.create_transfers_errors()
  def create_transfers(%Client{} = client, %TransferBatch{} = transfer_batch) do
    NifAdapter.create_transfers(client.ref, transfer_batch.ref)
  end

  @spec lookup_accounts(client :: t(), id_batch :: TigerBeetlex.IDBatch.t()) ::
          {:ok, reference()} | Types.lookup_accounts_errors()
  def lookup_accounts(%Client{} = client, %IDBatch{} = id_batch) do
    NifAdapter.lookup_accounts(client.ref, id_batch.ref)
  end

  @spec lookup_transfers(client :: t(), id_batch :: TigerBeetlex.IDBatch.t()) ::
          {:ok, reference()} | Types.lookup_transfers_errors()
  def lookup_transfers(%Client{} = client, %IDBatch{} = id_batch) do
    NifAdapter.lookup_transfers(client.ref, id_batch.ref)
  end
end
