defmodule TigerBeetlex.Connection do
  @moduledoc """
  GenServer based API.

  This module exposes a blocking API to the TigerBeetle NIF client. This is obtained by spawning
  receiver processes under a `PartitionSupervisor`. The receiver processes handle receiving messages
  from the processless `TigerBeetlex` client and translate them in a blocking API.

  If you already have a wrapping process, you can use `TigerBeetlex` directly instead.
  """

  alias TigerBeetlex.{
    AccountBatch,
    IDBatch,
    Receiver,
    TransferBatch,
    Types
  }

  @start_link_opts_schema [
    name: [
      type: :atom,
      required: true,
      doc: """
      The name of the Connection process. The same atom has to be passed to all the other functions
      as first argument.
      """
    ],
    cluster_id: [
      type: :non_neg_integer,
      required: true,
      doc: "The TigerBeetle cluster id."
    ],
    addresses: [
      type: {:list, :string},
      required: true,
      doc: """
      The list of node addresses. These can either be a single digit (e.g. `"3000"`), which is
      interpreted as a port on `127.0.0.1`, an IP address + port (e.g. `"127.0.0.1:3000"`), or just
      an IP address (e.g. `"127.0.0.1"`), which defaults to port `3001`.
      """
    ],
    concurrency_max: [
      type: :pos_integer,
      required: true,
      doc: """
      The maximum number of concurrent requests the client can handle. 32 is a good default, and can
      be increased to 4096 if there's the need of increased throughput.
      """
    ]
  ]

  @start_link_opts_keys Keyword.keys(@start_link_opts_schema)

  @doc false
  def child_spec(arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [arg]}
    }
  end

  @doc """
  Starts a process-based TigerBeetlex client.

  This creates N receiver processes (where N can be controlled by
  passing options to the underlying `PartitionSupervisor`) under a `PartitionSupervisor`.

  ## Options

  These are the TigerBeetlex-specific options supported by this function:

  #{NimbleOptions.docs(@start_link_opts_schema)}

  The rest of the options are forwarded to `PartitionSupervisor.start_link/1`. For example, to
  start a pool of five receivers, you can use the `:partitions` option:

      TigerBeetlex.Connection.start_link(
        partitions: 5,
        # ...
      )

  ## Examples

      # Start the TigerBeetlex connection
      {:ok, pid} =
        TigerBeetlex.Connection.start_link(
          cluster_id: 0,
          addresses: ["3000"],
          concurrency_max: 32
        )

      # Start a named TigerBeetlex connection
      {:ok, pid} =
        TigerBeetlex.Connection.start_link(
          cluster_id: 0,
          addresses: ["3000"],
          concurrency_max: 32,
          name: :tb
        )
  """
  def start_link(opts) do
    {tigerbeetlex_opts, partition_supervisor_opts} = Keyword.split(opts, @start_link_opts_keys)
    tigerbeetlex_opts = NimbleOptions.validate!(tigerbeetlex_opts, @start_link_opts_schema)

    # :name is actually a PartitionSupervisor key, but we validate it in the schema since
    # it's required
    {name, tigerbeetlex_opts} = Keyword.pop!(tigerbeetlex_opts, :name)
    partition_supervisor_opts = Keyword.put(partition_supervisor_opts, :name, name)

    cluster_id = Keyword.fetch!(tigerbeetlex_opts, :cluster_id)
    addresses = Keyword.fetch!(tigerbeetlex_opts, :addresses)
    concurrency_max = Keyword.fetch!(tigerbeetlex_opts, :concurrency_max)

    with {:ok, client} <- TigerBeetlex.connect(cluster_id, addresses, concurrency_max) do
      start_opts = Keyword.merge(partition_supervisor_opts, child_spec: {Receiver, client})
      PartitionSupervisor.start_link(start_opts)
    end
  end

  @doc """
  Creates a batch of accounts.

  `name` is the same atom that was passed in the `:name` option in `start_link/1`.

  `account_batch` is a `%TigerBeetlex.AccountBatch{}`, see `TigerBeetlex.AccountBatch` for
  the functions to create and manipulate it.

  If successful, the function returns `{:ok, stream}` where `stream` is an enumerable that
  can lazily produce `%TigerBeetlex.CreateAccountError{}` structs which contain the index
  of the account batch and the reason of the failure. An account has a corresponding
  `%TigerBeetlex.CreateAccountError{}` only if it fails to be created, otherwise the account
  has been created succesfully (so a successful request returns an empty stream).

  ## Examples

      # Successful request
      {:ok, batch} = TigerBeetlex.AccountBatch.new(10)

      {:ok, batch} =
        TigerBeetlex.AccountBatch.add_account(batch, id: <<42::128>>, ledger: 3, code: 4)

      {:ok, stream} = TigerBeetlex.Connection.create_accounts(:tb, batch)

      Enum.to_list(stream)
      #=> []

      # Creation error
      {:ok, batch} = TigerBeetlex.AccountBatch.new(10)

      {:ok, batch} =
        TigerBeetlex.AccountBatch.add_account(batch, id: <<0::128>>, ledger: 3, code: 4)

      {:ok, stream} = TigerBeetlex.Connection.create_accounts(:tb, batch)

      Enum.to_list(stream)
      #=> [%TigerBeetlex.CreateAccountError{index: 0, reason: :id_must_not_be_zero}]
  """
  @spec create_accounts(
          name :: PartitionSupervisor.name(),
          account_batch :: TigerBeetlex.AccountBatch.t()
        ) ::
          {:ok, Enumerable.t()} | Types.create_accounts_errors()
  def create_accounts(name, %AccountBatch{} = account_batch) do
    via_tuple(name)
    |> GenServer.call({:create_accounts, account_batch})
  end

  @doc """
  Creates a batch of transfers.

  `name` is the same atom that was passed in the `:name` option in `start_link/1`.

  `transfer_batch` is a `%TigerBeetlex.TransferBatch{}`, see `TigerBeetlex.TransferBatch` for
  the functions to create and manipulate it.

  If successful, the function returns `{:ok, stream}` where `stream` is an enumerable that
  can lazily produce `%TigerBeetlex.CreateTransferError{}` structs which contain the index
  of the transfer batch and the reason of the failure. An transfer has a corresponding
  `%TigerBeetlex.CreateTransferError{}` only if it fails to be created, otherwise the transfer
  has been created succesfully (so a successful request returns an empty stream).

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

      {:ok, stream} = TigerBeetlex.Connection.create_transfers(:tb, batch)

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

      {:ok, stream} = TigerBeetlex.Connection.create_transfers(:tb, batch)

      Enum.to_list(stream)
      #=> [%TigerBeetlex.CreateTransferError{index: 0, reason: :id_must_not_be_zero}]
  """
  @spec create_transfers(
          name :: PartitionSupervisor.name(),
          transfer_batch :: TigerBeetlex.TransferBatch.t()
        ) ::
          {:ok, Enumerable.t()} | Types.create_transfers_errors()
  def create_transfers(name, %TransferBatch{} = transfer_batch) do
    via_tuple(name)
    |> GenServer.call({:create_transfers, transfer_batch})
  end

  @doc """
  Lookup a batch of accounts.

  `name` is the same atom that was passed in the `:name` option in `start_link/1`.

  `id_batch` is a `%TigerBeetlex.IDBatch{}`, see `TigerBeetlex.IDBatch` for the functions to
  create and manipulate it.

  If successful, the function returns `{:ok, stream}` where `stream` is an enumerable that
  can lazily produce `%TigerBeetlex.Account{}` structs. If an id in the batch does not correspond
  to an existing account, it will simply be skipped, so the result could have less accounts then
  the provided ids in the id batch.

  ## Examples

      {:ok, batch} = TigerBeetlex.IDBatch.new(10)

      {:ok, batch} = TigerBeetlex.IDBatch.add_id(batch, <<42::128>>)

      {:ok, stream} = TigerBeetlex.Connection.lookup_accounts(:tb, batch)

      Enum.to_list(stream)
      #=> [%TigerBeetlex.Account{}]
  """
  @spec lookup_accounts(
          name :: PartitionSupervisor.name(),
          id_batch :: TigerBeetlex.IDBatch.t()
        ) ::
          {:ok, Enumerable.t()} | Types.lookup_accounts_errors()
  def lookup_accounts(name, %IDBatch{} = id_batch) do
    via_tuple(name)
    |> GenServer.call({:lookup_accounts, id_batch})
  end

  @doc """
  Lookup a batch of transfers.

  `name` is the same atom that was passed in the `:name` option in `start_link/1`.

  `id_batch` is a `%TigerBeetlex.IDBatch{}`, see `TigerBeetlex.IDBatch` for the functions to
  create and manipulate it.

  If successful, the function returns `{:ok, stream}` where `stream` is an enumerable that
  can lazily produce `%TigerBeetlex.Transfer{}` structs. If an id in the batch does not correspond
  to an existing transfer, it will simply be skipped, so the result could have less transfers then
  the provided ids in the id batch.

  ## Examples

      {:ok, batch} = TigerBeetlex.IDBatch.new(10)

      {:ok, batch} = TigerBeetlex.IDBatch.add_id(batch, <<42::128>>)

      {:ok, stream} = TigerBeetlex.Connection.lookup_transfers(:tb, batch)

      Enum.to_list(stream)
      #=> [%TigerBeetlex.Transfer{}]
  """
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
