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
          cluster_id :: Types.id_128(),
          addresses :: binary()
        ) ::
          {:ok, Types.client()} | {:error, Types.client_init_error()}
  def client_init(_cluster_id, _addresses) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @spec create_account_batch(capacity :: non_neg_integer()) ::
          {:ok, Types.account_batch()} | {:error, Types.create_batch_error()}
  def create_account_batch(_capacity), do: :erlang.nif_error(:nif_not_loaded)

  @spec append_account(
          account_batch :: Types.account_batch(),
          account_binary :: Types.account_binary()
        ) ::
          :ok | {:error, Types.append_error()}
  def append_account(_account_batch, _account_binary), do: :erlang.nif_error(:nif_not_loaded)

  @spec fetch_account(account_batch :: Types.account_batch(), idx :: non_neg_integer()) ::
          {:ok, account_binary :: Types.account_binary()} | {:error, Types.fetch_error()}
  def fetch_account(_account_batch, _index), do: :erlang.nif_error(:nif_not_loaded)

  @spec replace_account(
          account_batch :: Types.account_batch(),
          idx :: non_neg_integer(),
          account_binary :: Types.account_binary()
        ) :: :ok | {:error, Types.replace_error()}
  def replace_account(_account_batch, _index, _account_binary),
    do: :erlang.nif_error(:nif_not_loaded)

  @spec create_accounts(client :: Types.client(), account_batch :: Types.account_batch()) ::
          {:ok, reference()} | {:error, Types.create_accounts_error()}
  def create_accounts(_client, _account_batch), do: :erlang.nif_error(:nif_not_loaded)

  @spec create_transfer_batch(capacity :: non_neg_integer()) ::
          {:ok, Types.transfer_batch()} | {:error, Types.create_batch_error()}
  def create_transfer_batch(_capacity), do: :erlang.nif_error(:nif_not_loaded)

  @spec append_transfer(
          transfer_batch :: Types.transfer_batch(),
          transfer_binary :: Types.transfer_binary()
        ) ::
          :ok | {:error, Types.append_error()}
  def append_transfer(_transfer_batch, _transfer_binary), do: :erlang.nif_error(:nif_not_loaded)

  @spec fetch_transfer(transfer_batch :: Types.transfer_batch(), idx :: non_neg_integer()) ::
          {:ok, transfer_binary :: Types.transfer_binary()} | {:error, Types.fetch_error()}
  def fetch_transfer(_transfer_batch, _index), do: :erlang.nif_error(:nif_not_loaded)

  @spec replace_transfer(
          transfer_batch :: Types.transfer_batch(),
          idx :: non_neg_integer(),
          transfer_binary :: Types.transfer_binary()
        ) :: :ok | {:error, Types.replace_error()}
  def replace_transfer(_transfer_batch, _index, _transfer_binary),
    do: :erlang.nif_error(:nif_not_loaded)

  @spec create_transfers(client :: Types.client(), transfer_batch :: Types.transfer_batch()) ::
          {:ok, reference()} | {:error, Types.create_transfers_error()}
  def create_transfers(_client, _transfer_batch), do: :erlang.nif_error(:nif_not_loaded)

  @spec create_id_batch(capacity :: non_neg_integer()) ::
          {:ok, Types.id_batch()} | {:error, Types.create_batch_error()}
  def create_id_batch(_capacity), do: :erlang.nif_error(:nif_not_loaded)

  @spec append_id(id_batch :: Types.id_batch(), id :: Types.id_128()) ::
          :ok | {:error, Types.append_error()}
  def append_id(_id_batch, _id), do: :erlang.nif_error(:nif_not_loaded)

  @spec fetch_id(id_batch :: Types.id_batch(), idx :: non_neg_integer()) ::
          {:ok, id_binary :: Types.id_128()} | {:error, Types.fetch_error()}
  def fetch_id(_id_batch, _index), do: :erlang.nif_error(:nif_not_loaded)

  @spec replace_id(
          id_batch :: Types.id_batch(),
          idx :: non_neg_integer(),
          id_binary :: Types.id_128()
        ) :: :ok | {:error, Types.replace_error()}
  def replace_id(_id_batch, _index, _id_binary), do: :erlang.nif_error(:nif_not_loaded)

  @spec lookup_accounts(client :: Types.client(), id_batch :: Types.id_batch()) ::
          {:ok, reference()} | {:error, Types.lookup_accounts_error()}
  def lookup_accounts(_client, _id_batch), do: :erlang.nif_error(:nif_not_loaded)

  @spec lookup_transfers(client :: Types.client(), id_batch :: Types.id_batch()) ::
          {:ok, reference()} | {:error, Types.lookup_transfers_error()}
  def lookup_transfers(_client, _id_batch), do: :erlang.nif_error(:nif_not_loaded)
end
