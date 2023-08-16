defmodule TigerBeetlex.NifAdapter do
  @moduledoc false

  alias TigerBeetlex.Types

  @on_load :load_nif
  @nif_path "priv/#{Mix.target()}/lib/tigerbeetlex"

  defp load_nif do
    path = Application.app_dir(:tigerbeetlex, @nif_path)
    :erlang.load_nif(String.to_charlist(path), 0)
  end

  @spec client_init(
          cluster_id :: non_neg_integer(),
          addresses :: binary(),
          concurrency_max :: pos_integer()
        ) ::
          {:ok, Types.client()} | {:error, Types.client_init_error()}
  def client_init(_cluster_id, _addresses, _concurrency_max) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @spec create_account_batch(capacity :: non_neg_integer()) ::
          {:ok, Types.account_batch()} | {:error, Types.create_account_batch_error()}
  def create_account_batch(_capacity), do: :erlang.nif_error(:nif_not_loaded)

  @spec add_account(account_batch :: Types.account_batch()) ::
          {:ok, new_length :: pos_integer()} | {:error, Types.add_account_error()}
  def add_account(_account_batch), do: :erlang.nif_error(:nif_not_loaded)

  @spec append_account(
          account_batch :: Types.account_batch(),
          account_binary :: Types.account_binary()
        ) ::
          :ok | {:error, Types.append_account_error()}
  def append_account(_account_batch, _account_binary), do: :erlang.nif_error(:nif_not_loaded)

  @spec set_account_id(
          account_batch :: Types.account_batch(),
          index :: non_neg_integer(),
          id :: Types.uint128()
        ) ::
          :ok | {:error, Types.set_function_error()}
  def set_account_id(_account_batch, _index, _id), do: :erlang.nif_error(:nif_not_loaded)

  @spec set_account_user_data(
          account_batch :: Types.account_batch(),
          index :: non_neg_integer(),
          user_data :: Types.uint128()
        ) ::
          :ok | {:error, Types.set_function_error()}
  def set_account_user_data(_account_batch, _index, _user_data),
    do: :erlang.nif_error(:nif_not_loaded)

  @spec set_account_ledger(
          account_batch :: Types.account_batch(),
          index :: non_neg_integer(),
          ledger :: pos_integer()
        ) ::
          :ok | {:error, Types.set_function_error()}
  def set_account_ledger(_account_batch, _index, _ledger), do: :erlang.nif_error(:nif_not_loaded)

  @spec set_account_code(
          account_batch :: Types.account_batch(),
          index :: non_neg_integer(),
          code :: pos_integer()
        ) ::
          :ok | {:error, Types.set_function_error()}
  def set_account_code(_account_batch, _index, _code), do: :erlang.nif_error(:nif_not_loaded)

  @spec set_account_flags(
          account_batch :: Types.account_batch(),
          index :: non_neg_integer(),
          flags :: non_neg_integer()
        ) ::
          :ok | {:error, Types.set_function_error()}
  def set_account_flags(_account_batch, _index, _flags), do: :erlang.nif_error(:nif_not_loaded)

  @spec create_accounts(client :: Types.client(), account_batch :: Types.account_batch()) ::
          {:ok, reference()} | {:error, Types.create_accounts_error()}
  def create_accounts(_client, _account_batch), do: :erlang.nif_error(:nif_not_loaded)

  @spec create_transfer_batch(capacity :: non_neg_integer()) ::
          {:ok, Types.transfer_batch()} | {:error, Types.create_transfer_batch_error()}
  def create_transfer_batch(_capacity), do: :erlang.nif_error(:nif_not_loaded)

  @spec add_transfer(transfer_batch :: Types.transfer_batch()) ::
          {:ok, new_length :: pos_integer()} | {:error, Types.add_transfer_error()}
  def add_transfer(_transfer_batch), do: :erlang.nif_error(:nif_not_loaded)

  @spec append_transfer(
          transfer_batch :: Types.transfer_batch(),
          transfer_binary :: Types.transfer_binary()
        ) ::
          :ok | {:error, Types.append_transfer_error()}
  def append_transfer(_transfer_batch, _transfer_binary), do: :erlang.nif_error(:nif_not_loaded)

  @spec set_transfer_id(
          transfer_batch :: Types.transfer_batch(),
          index :: non_neg_integer(),
          id :: Types.uint128()
        ) ::
          :ok | {:error, Types.set_function_error()}
  def set_transfer_id(_transfer_batch, _index, _id), do: :erlang.nif_error(:nif_not_loaded)

  @spec set_transfer_debit_account_id(
          transfer_batch :: Types.transfer_batch(),
          index :: non_neg_integer(),
          debit_account_id :: Types.uint128()
        ) ::
          :ok | {:error, Types.set_function_error()}
  def set_transfer_debit_account_id(_transfer_batch, _index, _debit_account_id),
    do: :erlang.nif_error(:nif_not_loaded)

  @spec set_transfer_credit_account_id(
          transfer_batch :: Types.transfer_batch(),
          index :: non_neg_integer(),
          credit_account_id :: Types.uint128()
        ) ::
          :ok | {:error, Types.set_function_error()}
  def set_transfer_credit_account_id(_transfer_batch, _index, _credit_account_id),
    do: :erlang.nif_error(:nif_not_loaded)

  @spec set_transfer_user_data(
          transfer_batch :: Types.transfer_batch(),
          index :: non_neg_integer(),
          user_data :: Types.uint128()
        ) ::
          :ok | {:error, Types.set_function_error()}
  def set_transfer_user_data(_transfer_batch, _index, _user_data),
    do: :erlang.nif_error(:nif_not_loaded)

  @spec set_transfer_pending_id(
          transfer_batch :: Types.transfer_batch(),
          index :: non_neg_integer(),
          pending_id :: Types.uint128()
        ) ::
          :ok | {:error, Types.set_function_error()}
  def set_transfer_pending_id(_transfer_batch, _index, _pending_id),
    do: :erlang.nif_error(:nif_not_loaded)

  @spec set_transfer_timeout(
          transfer_batch :: Types.transfer_batch(),
          index :: non_neg_integer(),
          timeout :: non_neg_integer()
        ) ::
          :ok | {:error, Types.set_function_error()}
  def set_transfer_timeout(_transfer_batch, _index, _timeout),
    do: :erlang.nif_error(:nif_not_loaded)

  @spec set_transfer_ledger(
          transfer_batch :: Types.transfer_batch(),
          index :: non_neg_integer(),
          ledger :: non_neg_integer()
        ) ::
          :ok | {:error, Types.set_function_error()}
  def set_transfer_ledger(_transfer_batch, _index, _ledger),
    do: :erlang.nif_error(:nif_not_loaded)

  @spec set_transfer_code(
          transfer_batch :: Types.transfer_batch(),
          index :: non_neg_integer(),
          code :: non_neg_integer()
        ) ::
          :ok | {:error, Types.set_function_error()}
  def set_transfer_code(_transfer_batch, _index, _code), do: :erlang.nif_error(:nif_not_loaded)

  @spec set_transfer_flags(
          transfer_batch :: Types.transfer_batch(),
          index :: non_neg_integer(),
          flags :: non_neg_integer()
        ) ::
          :ok | {:error, Types.set_function_error()}
  def set_transfer_flags(_transfer_batch, _index, _flags), do: :erlang.nif_error(:nif_not_loaded)

  @spec set_transfer_amount(
          transfer_batch :: Types.transfer_batch(),
          index :: non_neg_integer(),
          amount :: non_neg_integer()
        ) ::
          :ok | {:error, Types.set_function_error()}
  def set_transfer_amount(_transfer_batch, _index, _amount),
    do: :erlang.nif_error(:nif_not_loaded)

  @spec create_transfers(client :: Types.client(), transfer_batch :: Types.transfer_batch()) ::
          {:ok, reference()} | {:error, Types.create_transfers_error()}
  def create_transfers(_client, _transfer_batch), do: :erlang.nif_error(:nif_not_loaded)

  @spec create_id_batch(capacity :: non_neg_integer()) ::
          {:ok, Types.id_batch()} | {:error, Types.create_id_batch_error()}
  def create_id_batch(_capacity), do: :erlang.nif_error(:nif_not_loaded)

  @spec add_id(id_batch :: Types.id_batch(), id :: Types.uint128()) ::
          {:ok, new_length :: pos_integer()} | {:error, Types.add_id_error()}
  def add_id(_id_batch, _id), do: :erlang.nif_error(:nif_not_loaded)

  @spec set_id(id_batch :: Types.id_batch(), index :: non_neg_integer(), id :: Types.uint128()) ::
          :ok | {:error, Types.set_function_error()}
  def set_id(_id_batch, _index, _id), do: :erlang.nif_error(:nif_not_loaded)

  @spec lookup_accounts(client :: Types.client(), id_batch :: Types.id_batch()) ::
          {:ok, reference()} | {:error, Types.lookup_accounts_error()}
  def lookup_accounts(_client, _id_batch), do: :erlang.nif_error(:nif_not_loaded)

  @spec lookup_transfers(client :: Types.client(), id_batch :: Types.id_batch()) ::
          {:ok, reference()} | {:error, Types.lookup_transfers_error()}
  def lookup_transfers(_client, _id_batch), do: :erlang.nif_error(:nif_not_loaded)
end
