defmodule TigerBeetlex.Connection do
  @moduledoc """
  Blocking API.

  This module exposes a blocking API to the TigerBeetle NIF client. This is obtained by spawning
  receiver processes under a `PartitionSupervisor`. The receiver processes handle receiving messages
  from the message based `TigerBeetlex.Client` client and translate them in a blocking API.

  If you already have a wrapping process, you can use `TigerBeetlex.Client` directly instead.
  """

  alias TigerBeetlex.Account
  alias TigerBeetlex.AccountBalance
  alias TigerBeetlex.AccountFilter
  alias TigerBeetlex.Client
  alias TigerBeetlex.CreateAccountsResult
  alias TigerBeetlex.CreateTransfersResult
  alias TigerBeetlex.QueryFilter
  alias TigerBeetlex.Receiver
  alias TigerBeetlex.Transfer
  alias TigerBeetlex.Types

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
      type: {:custom, TigerBeetlex.ID128, :validate, []},
      type_doc: "`t:TigerBeetlex.Types.id_128/0`",
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
  Starts a managed TigerBeetlex connection.

  This creates N receiver processes (where N can be controlled by
  passing options to the underlying `PartitionSupervisor`) under a `PartitionSupervisor`.

  On success, the it returns the pid of the `PartitionSupervisor`. Note that this is not
  what you have to pass to all the other functions in this module as first argument,
  rather the `name` atom passed as option to `start_link/1` has to be passed.

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
          cluster_id: <<0::128>>,
          addresses: ["3000"],
          name: :tb
        )
  """
  @spec start_link(opts :: Types.start_options()) ::
          Supervisor.on_start() | {:error, Types.init_client_error()}
  def start_link(opts) do
    {tigerbeetlex_opts, partition_supervisor_opts} = Keyword.split(opts, @start_link_opts_keys)
    tigerbeetlex_opts = NimbleOptions.validate!(tigerbeetlex_opts, @start_link_opts_schema)

    # :name is actually a PartitionSupervisor key, but we validate it in the schema since
    # it's required
    {name, tigerbeetlex_opts} = Keyword.pop!(tigerbeetlex_opts, :name)
    partition_supervisor_opts = Keyword.put(partition_supervisor_opts, :name, name)

    cluster_id = Keyword.fetch!(tigerbeetlex_opts, :cluster_id)
    addresses = Keyword.fetch!(tigerbeetlex_opts, :addresses)

    with {:ok, client} <- Client.new(cluster_id, addresses) do
      start_opts = Keyword.merge(partition_supervisor_opts, child_spec: {Receiver, client})
      PartitionSupervisor.start_link(start_opts)
    end
  end

  @doc """
  Creates a batch of accounts.

  `name` is the same atom that was passed in the `:name` option in `start_link/1`.

  `accounts` is a list of `TigerBeetlex.Account` structs.

  If successful, the function returns `{:ok, results}` where `results` is a list of
  `TigerBeetlex.CreateAccountsResult` structs which contain the index
  of the account list and the reason of the failure. An account has a corresponding
  `TigerBeetlex.CreateAccountsResult` only if it fails to be created, otherwise the account
  has been created succesfully (so a successful request returns an empty list).

  See [`create_accounts`](https://docs.tigerbeetle.com/reference/requests/create_accounts/).

  ## Examples
      alias TigerBeetlex.Account

      # Successful request
      accounts = [%Account{id: <<42::128>>, ledger: 3, code: 4}]

      TigerBeetlex.Connection.create_accounts(:tb, accounts)
      #=> {:ok, []}

      # Creation error
      accounts = [%Account{id: <<0::128>>, ledger: 3, code: 4}]

      TigerBeetlex.Connection.create_accounts(:tb, accounts)

      #=> {:ok, [%TigerBeetlex.CreateAccountsResult{index: 0, result: :id_must_not_be_zero}]}
  """
  @spec create_accounts(
          name :: PartitionSupervisor.name(),
          accounts :: [Account.t()]
        ) ::
          {:ok, [CreateAccountsResult.t()]} | {:error, Types.request_error()}
  def create_accounts(name, accounts) when is_list(accounts) do
    via_tuple(name)
    |> GenServer.call({:create_accounts, accounts})
  end

  @doc """
  Creates a batch of transfers.

  `name` is the same atom that was passed in the `:name` option in `start_link/1`.

  `transfers` is a list of `TigerBeetlex.Transfer` structs.

  If successful, the function returns `{:ok, results}` where `results` is a list of
  `TigerBeetlex.CreateTransfersResult` structs which contain the index
  of the transfer list and the reason of the failure. A transfer has a corresponding
  `TigerBeetlex.CreateTransfersResult` only if it fails to be created, otherwise the transfer
  has been created succesfully (so a successful request returns an empty list).

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

      TigerBeetlex.Connection.create_transfers(:tb, transfers)
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

      TigerBeetlex.Connection.create_transfers(:tb, transfers)
      #=> {:ok, [%TigerBeetlex.CreateTransferError{index: 0, result: :id_must_not_be_zero}]}
  """
  @spec create_transfers(
          name :: PartitionSupervisor.name(),
          transfers :: [Transfer.t()]
        ) ::
          {:ok, [CreateTransfersResult.t()]} | {:error, Types.request_error()}
  def create_transfers(name, transfers) when is_list(transfers) do
    via_tuple(name)
    |> GenServer.call({:create_transfers, transfers})
  end

  @doc """
  Lookup a batch of accounts.

  `name` is the same atom that was passed in the `:name` option in `start_link/1`.

  `ids` is a list of 128-bit binaries.

  If successful, the function returns `{:ok, results}` where `results` is a list of
  `TigerBeetlex.Account` structs. If an id in the list does not correspond to an existing
  account, it will simply be skipped, so the result can have less accounts then the provided
  ids.

  See [`lookup_accounts`](https://docs.tigerbeetle.com/reference/requests/lookup_accounts/).

  ## Examples

      ids = [<<42::128>>]

      TigerBeetlex.Connection.lookup_accounts(:tb, ids)
      #=> {:ok, [%TigerBeetlex.Account{}]}
  """
  @spec lookup_accounts(
          name :: PartitionSupervisor.name(),
          ids :: [Types.id_128()]
        ) ::
          {:ok, [Account.t()]} | {:error, Types.request_error()}
  def lookup_accounts(name, ids) when is_list(ids) do
    via_tuple(name)
    |> GenServer.call({:lookup_accounts, ids})
  end

  @doc """
  Lookup a batch of transfers.

  `name` is the same atom that was passed in the `:name` option in `start_link/1`.

  `ids` is a list of 128-bit binaries.

  If successful, the function returns `{:ok, results}` where `results` is a list of
  `TigerBeetlex.Transfer` structs. If an id in the list does not correspond to an existing
  transfer, it will simply be skipped, so the result could have less transfers then the provided
  ids.

  See [`lookup_transfers`](https://docs.tigerbeetle.com/reference/requests/lookup_transfers/).

  ## Examples

      ids = [<<42::128>>]

      TigerBeetlex.Connection.lookup_transfers(:tb, ids)
      #=> {:ok, [%TigerBeetlex.Transfer{}]}
  """
  @spec lookup_transfers(
          name :: PartitionSupervisor.name(),
          ids :: [Types.id_128()]
        ) ::
          {:ok, [Transfer.t()]} | {:error, Types.request_error()}
  def lookup_transfers(name, ids) when is_list(ids) do
    via_tuple(name)
    |> GenServer.call({:lookup_transfers, ids})
  end

  @doc """
  Fetch a list of historical `TigerBeetlex.AccountBalance` for a given `TigerBeetlex.Account`.

  Only accounts created with the `history` flag set retain historical balances. This is off by default.

  `name` is the same atom that was passed in the `:name` option in `start_link/1`.

  `account_filter` is a `TigerBeetlex.AccountFilter` struct. The `limit` field must be set.

  If successful, the function returns `{:ok, results}` where `results` is a list of
  `TigerBeetlex.AccountBalance` structs.

  See [`get_account_balances`](https://docs.tigerbeetle.com/reference/requests/get_account_balances/).

  ## Examples
      alias TigerBeetlex.AccountFilter

      account_filter = %AccountFilter{id: <<42::128>>, limit: 10}

      TigerBeetlex.Connection.get_account_balances(:tb, account_filter)
      #=> {:ok, [%TigerBeetlex.AccountBalance{}]}
  """
  @spec get_account_balances(
          name :: PartitionSupervisor.name(),
          account_filter :: AccountFilter.t()
        ) ::
          {:ok, [AccountBalance.t()]} | {:error, Types.request_error()}
  def get_account_balances(name, %AccountFilter{} = account_filter) do
    via_tuple(name)
    |> GenServer.call({:get_account_balances, account_filter})
  end

  @doc """
  Fetch a list of `TigerBeetlex.Transfer` involving a `TigerBeetlex.Account`.

  `name` is the same atom that was passed in the `:name` option in `start_link/1`.

  `account_filter` is a `TigerBeetlex.AccountFilter` struct. The `limit` field must be set.

  If successful, the function returns `{:ok, results}` where `results` is a list of
  `TigerBeetlex.Transfer` structs.

  See [`get_account_transfers`](https://docs.tigerbeetle.com/reference/requests/get_account_transfers/).

  ## Examples
      alias TigerBeetlex.AccountFilter

      account_filter = %AccountFilter{id: <<42::128>>, limit: 10}

      TigerBeetlex.Connection.get_account_transfers(:tb, account_filter)
      #=> {:ok, [%TigerBeetlex.Transfer{}]}
  """
  @spec get_account_transfers(
          name :: PartitionSupervisor.name(),
          account_filter :: AccountFilter.t()
        ) ::
          {:ok, [Transfer.t()]} | {:error, Types.request_error()}
  def get_account_transfers(name, %AccountFilter{} = account_filter) do
    via_tuple(name)
    |> GenServer.call({:get_account_transfers, account_filter})
  end

  @doc """
  Query accounts by the intersection of some fields and by timestamp range.

  `name` is the same atom that was passed in the `:name` option in `start_link/1`.

  `query_filter` is a `TigerBeetlex.QueryFilter` struct. The `limit` field must be set.

  If successful, the function returns `{:ok, results}` where `results` is a list of
  `TigerBeetlex.Account` structs.

  See [`query_accounts`](https://docs.tigerbeetle.com/reference/requests/query_accounts/).

  ## Examples
      alias TigerBeetlex.QueryFilter

      query_filter = %QueryFilter{id: <<42::128>>, limit: 10}

      TigerBeetlex.Connection.query_accounts(:tb, query_filter)
      #=> {:ok, [%TigerBeetlex.Account{}]}
  """
  @spec query_accounts(
          name :: PartitionSupervisor.name(),
          query_filter :: QueryFilter.t()
        ) ::
          {:ok, [Account.t()]} | {:error, Types.request_error()}
  def query_accounts(name, %QueryFilter{} = query_filter) do
    via_tuple(name)
    |> GenServer.call({:query_accounts, query_filter})
  end

  @doc """
  Query transfers by the intersection of some fields and by timestamp range.

  `name` is the same atom that was passed in the `:name` option in `start_link/1`.

  `query_filter` is a `TigerBeetlex.QueryFilter` struct. The `limit` field must be set.

  If successful, the function returns `{:ok, results}` where `results` is a list of
  `TigerBeetlex.Transfer` structs.

  See [`query_transfers`](https://docs.tigerbeetle.com/reference/requests/query_transfers/).

  ## Examples
      alias TigerBeetlex.QueryFilter

      query_filter = %QueryFilter{id: <<42::128>>, limit: 10}

      TigerBeetlex.Connection.query_transfers(:tb, query_filter)
      #=> {:ok, [%TigerBeetlex.Transfer{}]}
  """
  @spec query_transfers(
          name :: PartitionSupervisor.name(),
          query_filter :: QueryFilter.t()
        ) ::
          {:ok, [Account.t()]} | {:error, Types.request_error()}
  def query_transfers(name, %QueryFilter{} = query_filter) do
    via_tuple(name)
    |> GenServer.call({:query_transfers, query_filter})
  end

  defp via_tuple(name) do
    {:via, PartitionSupervisor, {name, self()}}
  end
end
