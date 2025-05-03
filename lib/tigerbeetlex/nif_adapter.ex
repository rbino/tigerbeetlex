defmodule TigerBeetlex.NifAdapter do
  @moduledoc false

  alias TigerBeetlex.Types

  @on_load :load_nif
  @nif_path "priv/#{Mix.target()}/lib/tigerbeetlex"

  defp load_nif do
    path = Application.app_dir(:tigerbeetlex, @nif_path)
    :erlang.load_nif(String.to_charlist(path), 0)
  end

  @spec init_client(
          cluster_id :: Types.id_128(),
          addresses :: binary()
        ) ::
          {:ok, Types.client()} | {:error, Types.init_client_error()}
  def init_client(_cluster_id, _addresses) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @spec submit(client :: Types.client(), operation :: non_neg_integer(), payload :: iodata()) ::
          {:ok, reference()} | {:error, Types.request_error()}
  def submit(_client, _operation, _payload), do: :erlang.nif_error(:nif_not_loaded)
end
