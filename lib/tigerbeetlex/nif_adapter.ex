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

  @spec create_accounts(client :: Types.client(), payload :: binary()) ::
          {:ok, reference()} | {:error, Types.request_error()}
  def create_accounts(_client, _account_batch), do: :erlang.nif_error(:nif_not_loaded)

  @spec get_account_transfers(client :: Types.client(), payload :: binary()) ::
          {:ok, reference()} | {:error, Types.request_error()}
  def get_account_transfers(_client, _id), do: :erlang.nif_error(:nif_not_loaded)

  @spec get_account_balances(client :: Types.client(), payload :: binary()) ::
          {:ok, reference()} | {:error, Types.request_error()}
  def get_account_balances(_client, _id), do: :erlang.nif_error(:nif_not_loaded)

  @spec create_transfers(client :: Types.client(), payload :: binary()) ::
          {:ok, reference()} | {:error, Types.request_error()}
  def create_transfers(_client, _transfer_batch), do: :erlang.nif_error(:nif_not_loaded)

  @spec lookup_accounts(client :: Types.client(), payload :: binary()) ::
          {:ok, reference()} | {:error, Types.request_error()}
  def lookup_accounts(_client, _id_batch), do: :erlang.nif_error(:nif_not_loaded)

  @spec lookup_transfers(client :: Types.client(), payload :: binary()) ::
          {:ok, reference()} | {:error, Types.request_error()}
  def lookup_transfers(_client, _id_batch), do: :erlang.nif_error(:nif_not_loaded)

  @spec query_accounts(client :: Types.client(), payload :: binary()) ::
          {:ok, reference()} | {:error, Types.request_error()}
  def query_accounts(_client, _id_batch), do: :erlang.nif_error(:nif_not_loaded)

  @spec query_transfers(client :: Types.client(), payload :: binary()) ::
          {:ok, reference()} | {:error, Types.request_error()}
  def query_transfers(_client, _id_batch), do: :erlang.nif_error(:nif_not_loaded)
end
