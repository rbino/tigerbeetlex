defmodule TigerBeetlex.AccountFilter do
  @moduledoc """
  AccountFilter struct module.

  This module defines a struct that represents a TigerBeetle account-filter.

  See [TigerBeetle docs](https://docs.tigerbeetle.com/reference/account-filter) for the meaning of the
  fields.
  """

  use TypedStruct

  alias TigerBeetlex.AccountFilter
  alias TigerBeetlex.AccountFilter.Flags
  alias TigerBeetlex.Types

  typedstruct do
    @typedoc "A struct representing a TigerBeetle account-filter"

    field :account_id, Types.id_128(), enforce: true
    field :user_data_128, Types.user_data_128()
    field :user_data_64, Types.user_data_64()
    field :user_data_32, Types.user_data_32()
    field :code, non_neg_integer(), default: 0
    field :timestamp_min, non_neg_integer(), default: 0
    field :timestamp_max, non_neg_integer(), default: 0
    field :limit, non_neg_integer(), default: 8190
    field :flags, Flags.t(), default: %Flags{}
  end

  @doc """
  Converts a `%TigerBeetlex.AccountFilter{}` to its binary representation (128 bytes
  binary).
  """
  # TODO @spec to_binary(account :: t()) :: Types.account_binary()
  def to_batch_item(%AccountFilter{} = filter) do
    %AccountFilter{
      account_id: account_id,
      user_data_128: user_data_128,
      user_data_64: user_data_64,
      user_data_32: user_data_32,
      code: code,
      timestamp_min: timestamp_min,
      timestamp_max: timestamp_max,
      limit: limit,
      flags: flags
    } = filter

    reserved = <<0::unit(8)-size(58)>>

    flags_u32 = (flags || %Flags{}) |> Flags.to_u32!()

    <<account_id::binary-size(16),
      user_data_128_default(user_data_128)::binary-size(16),
      user_data_64_default(user_data_64)::binary-size(8),
      user_data_32_default(user_data_32)::binary-size(4), 
      code::unsigned-little-16,
      reserved::binary,
      timestamp_min::unsigned-little-64,
      timestamp_max::unsigned-little-64,
      limit::unsigned-little-32,
      flags_u32::unsigned-little-32>>
  end

  defp user_data_128_default(nil), do: <<0::unit(8)-size(16)>>
  defp user_data_128_default(value), do: value

  defp user_data_64_default(nil), do: <<0::unit(8)-size(8)>>
  defp user_data_64_default(value), do: value

  defp user_data_32_default(nil), do: <<0::unit(8)-size(4)>>
  defp user_data_32_default(value), do: value
end
