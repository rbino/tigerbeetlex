defmodule TigerBeetlex do
  alias TigerBeetlex.{
    AccountBatch,
    Client,
    IDBatch,
    Server,
    TransferBatch,
    Types
  }

  def child_spec(arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [arg]}
    }
  end

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    cluster_id = Keyword.fetch!(opts, :cluster_id)
    addresses = Keyword.fetch!(opts, :addresses)
    concurrency_max = Keyword.fetch!(opts, :concurrency_max)

    with {:ok, client} <- Client.connect(cluster_id, addresses, concurrency_max) do
      PartitionSupervisor.start_link(name: name, child_spec: {Server, client})
    end
  end

  @spec create_accounts(
          name :: PartitionSupervisor.name(),
          account_batch :: TigerBeetlex.AccountBatch.t()
        ) ::
          {:ok, Enumerable.t()} | Types.create_accounts_errors()
  def create_accounts(name, %AccountBatch{} = account_batch) do
    via_tuple(name)
    |> GenServer.call({:create_accounts, account_batch})
  end

  @spec create_transfers(
          name :: PartitionSupervisor.name(),
          transfer_batch :: TigerBeetlex.TransferBatch.t()
        ) ::
          {:ok, Enumerable.t()} | Types.create_transfers_errors()
  def create_transfers(name, %TransferBatch{} = transfer_batch) do
    via_tuple(name)
    |> GenServer.call({:create_transfers, transfer_batch})
  end

  @spec lookup_accounts(
          name :: PartitionSupervisor.name(),
          id_batch :: TigerBeetlex.IDBatch.t()
        ) ::
          {:ok, Enumerable.t()} | Types.lookup_accounts_errors()
  def lookup_accounts(name, %IDBatch{} = id_batch) do
    via_tuple(name)
    |> GenServer.call({:lookup_accounts, id_batch})
  end

  @spec lookup_transfers(
          name :: PartitionSupervisor.name(),
          id_batch :: TigerBeetlex.IDBatch.t()
        ) ::
          {:ok, Enumerable.t()} | Types.lookup_transfers_errors()
  def lookup_transfers(name, %IDBatch{} = id_batch) do
    via_tuple(name)
    |> GenServer.call({:lookup_transfers, id_batch})
  end

  defp via_tuple(name) do
    {:via, PartitionSupervisor, {name, self()}}
  end
end
