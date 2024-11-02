defmodule TigerBeetlex.QueryFilter do
  @moduledoc """
  QueryFilter creation and manipulation.

  This module collects functions to interact with a query filter. A Query Filter represents a struct that will be used to submit a Query Accounts or Query Transfers
  operation on TigerBeetle.

  The Query Filter should be treated as an opaque and underneath it is implemented with a mutable NIF
  resource. It is safe to modify an ID Batch from multiple processes concurrently.

  See https://docs.tigerbeetle.com/reference/query-filter/#fields
  """

  alias TigerBeetlex.QueryFilter
  alias TigerBeetlex.QueryFilter.Flags
  alias TigerBeetlex.Types
  use TypedStruct

  typedstruct do
    field :user_data_128, Types.user_data_128()
    field :user_data_64, Types.user_data_64()
    field :user_data_32, Types.user_data_32()
    field :ledger, non_neg_integer()
    field :code, non_neg_integer()
    field :timestamp_min, non_neg_integer()
    field :timestamp_max, non_neg_integer()
    field :limit, non_neg_integer()

    field :flags, %Flags{}
  end

  @doc """
  Converts a `%TigerBeetlex.QueryFilter{}` to its binary representation (?? bytes
  binary).
  """
  # @spec encode(query_filter :: t()) :: Types.account_binary()
  def encode(%QueryFilter{} = query_filter) do
    %QueryFilter{
      user_data_128: user_data_128,
      user_data_64: user_data_64,
      user_data_32: user_data_32,
      ledger: ledger,
      code: code,
      timestamp_min: timestamp_min,
      timestamp_max: timestamp_max,
      limit: limit,
      flags: flags
    } = query_filter

    reserved = <<0::unit(8)-size(6)>>

    flags_u32 =
      (flags || %Flags{})
      |> Flags.to_u32!()

    <<user_data_128_default(user_data_128)::binary-size(16),
      user_data_64_default(user_data_64)::binary-size(8),
      user_data_32_default(user_data_32)::binary-size(4),
      value_or_zero(ledger)::unsigned-little-32, value_or_zero(code)::unsigned-little-16,
      value_or_zero(timestamp_min)::unsigned-little-64,
      value_or_zero(timestamp_max)::unsigned-little-64, value_or_zero(limit)::unsigned-little-32,
      value_or_zero(limit)::unsigned-little-32, value_or_zero(flags_u32)::unsigned-little-32,
      reserved::binary>>
  end

  defp user_data_128_default(nil), do: <<0::unit(8)-size(16)>>
  defp user_data_128_default(value), do: value

  defp user_data_64_default(nil), do: <<0::unit(8)-size(8)>>
  defp user_data_64_default(value), do: value

  defp user_data_32_default(nil), do: <<0::unit(8)-size(4)>>
  defp user_data_32_default(value), do: value

  defp value_or_zero(nil), do: 0
  defp value_or_zero(value), do: value
end
