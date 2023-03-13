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
          addresses :: charlist(),
          max_concurrency :: pos_integer()
        ) ::
          {:ok, Types.client()} | Types.client_init_errors()
  def client_init(_cluster_id, _addresses, _max_concurrency) do
    :erlang.nif_error(:nif_not_loaded)
  end
end
