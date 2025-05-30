defmodule TigerBeetlex.Response do
  @moduledoc """
  NIF Response parsing.
  This module is responsible for converting a response received from the TigerBeetle NIF to either
  an error or a list of results.
  """

  @doc """
  Converts a NIF message response to a list of results.

  If the response contains an error, `{:error, reason}` is returned.

  If successful, it returns `{:ok, list}`. The type of the items of the list depend on the
  operation.

  - `create_accounts`: a list of `%TigerBeetlex.CreateAccountsResult{}`
  - `create_transfers`: a list of `%TigerBeetlex.CreateTransfersResult{}`
  - `lookup_accounts`: a list of `%TigerBeetlex.Account{}`
  - `lookup_transfers`: a list of `%TigerBeetlex.Transfer{}`
  - `get_account_transfers`: a list of `%TigerBeetlex.Transfer{}`
  - `get_account_balances`: a list of `%TigerBeetlex.AccountBalance{}`
  - `query_accounts`: a list of `%TigerBeetlex.Account{}`
  - `query_transfers`: a list of `%TigerBeetlex.Transfer{}`
  """
  def decode({0, operation, batch} = _response) do
    {:ok, build_result_list(operation, batch)}
  end

  def decode({1, _operation, _batch}) do
    {:error, :too_much_data}
  end

  def decode({2, _operation, _batch}) do
    {:error, :client_evicted}
  end

  def decode({3, _operation, _batch}) do
    {:error, :client_release_too_low}
  end

  def decode({4, _operation, _batch}) do
    {:error, :client_release_too_high}
  end

  def decode({5, _operation, _batch}) do
    {:error, :client_shutdown}
  end

  def decode({6, _operation, _batch}) do
    {:error, :invalid_operation}
  end

  def decode({7, _operation, _batch}) do
    {:error, :invalid_data_size}
  end

  defp build_result_list(138, batch) when rem(bit_size(batch), 64) == 0 do
    for <<item::binary-size(8) <- batch>> do
      TigerBeetlex.CreateAccountsResult.from_binary(item)
    end
  end

  defp build_result_list(139, batch) when rem(bit_size(batch), 64) == 0 do
    for <<item::binary-size(8) <- batch>> do
      TigerBeetlex.CreateTransfersResult.from_binary(item)
    end
  end

  defp build_result_list(140, batch) when rem(bit_size(batch), 1024) == 0 do
    for <<item::binary-size(128) <- batch>> do
      TigerBeetlex.Account.from_binary(item)
    end
  end

  defp build_result_list(141, batch) when rem(bit_size(batch), 1024) == 0 do
    for <<item::binary-size(128) <- batch>> do
      TigerBeetlex.Transfer.from_binary(item)
    end
  end

  defp build_result_list(142, batch) when rem(bit_size(batch), 1024) == 0 do
    for <<item::binary-size(128) <- batch>> do
      TigerBeetlex.Transfer.from_binary(item)
    end
  end

  defp build_result_list(143, batch) when rem(bit_size(batch), 1024) == 0 do
    for <<item::binary-size(128) <- batch>> do
      TigerBeetlex.AccountBalance.from_binary(item)
    end
  end

  defp build_result_list(144, batch) when rem(bit_size(batch), 1024) == 0 do
    for <<item::binary-size(128) <- batch>> do
      TigerBeetlex.Account.from_binary(item)
    end
  end

  defp build_result_list(145, batch) when rem(bit_size(batch), 1024) == 0 do
    for <<item::binary-size(128) <- batch>> do
      TigerBeetlex.Transfer.from_binary(item)
    end
  end

  @doc false
  def status_map do
    %{
      ok: 0,
      too_much_data: 1,
      client_evicted: 2,
      client_release_too_low: 3,
      client_release_too_high: 4,
      client_shutdown: 5,
      invalid_operation: 6,
      invalid_data_size: 7
    }
  end
end
