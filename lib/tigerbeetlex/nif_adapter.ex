defmodule TigerBeetlex.NifAdapter do
  @moduledoc """
  Documentation for `TigerBeetlex.NifAdapter`.
  """

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
          max_concurrency :: pos_integer()
        ) ::
          {:ok, Types.client()} | Types.client_init_errors()
  def client_init(_cluster_id, _addresses, _max_concurrency) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @spec create_account_batch(capacity :: non_neg_integer()) ::
          {:ok, Types.account_batch()} | Types.create_account_batch_errors()
  def create_account_batch(_capacity), do: :erlang.nif_error(:nif_not_loaded)

  @spec add_account(account_batch :: Types.account_batch()) ::
          :ok | Types.add_account_errors()
  def add_account(_account_batch), do: :erlang.nif_error(:nif_not_loaded)

  @spec set_account_id(
          account_batch :: Types.account_batch(),
          index :: non_neg_integer(),
          id :: Types.uint128()
        ) ::
          :ok | Types.account_setter_errors()
  def set_account_id(_account_batch, _index, _id), do: :erlang.nif_error(:nif_not_loaded)

  @spec set_account_user_data(
          account_batch :: Types.account_batch(),
          index :: non_neg_integer(),
          user_data :: Types.uint128()
        ) ::
          :ok | Types.account_setter_errors()
  def set_account_user_data(_account_batch, _index, _user_data),
    do: :erlang.nif_error(:nif_not_loaded)

  @spec set_account_ledger(
          account_batch :: Types.account_batch(),
          index :: non_neg_integer(),
          ledger :: pos_integer()
        ) ::
          :ok | Types.account_setter_errors()
  def set_account_ledger(_account_batch, _index, _ledger), do: :erlang.nif_error(:nif_not_loaded)

  @spec set_account_code(
          account_batch :: Types.account_batch(),
          index :: non_neg_integer(),
          code :: pos_integer()
        ) ::
          :ok | Types.account_setter_errors()
  def set_account_code(_account_batch, _index, _code), do: :erlang.nif_error(:nif_not_loaded)

  @spec set_account_flags(
          account_batch :: Types.account_batch(),
          index :: non_neg_integer(),
          flags :: non_neg_integer()
        ) ::
          :ok | Types.account_setter_errors()
  def set_account_flags(_account_batch, _index, _flags), do: :erlang.nif_error(:nif_not_loaded)

  @spec create_accounts(client :: Types.client(), account_batch :: Types.account_batch()) ::
          {:ok, reference()} | Types.create_account_errors()
  def create_accounts(_client, _account_batch), do: :erlang.nif_error(:nif_not_loaded)

  @spec create_transfer_batch(capacity :: non_neg_integer()) ::
          {:ok, Types.transfer_batch()} | Types.create_transfer_batch_errors()
  def create_transfer_batch(_capacity), do: :erlang.nif_error(:nif_not_loaded)
end
