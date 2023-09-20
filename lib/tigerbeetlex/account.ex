defmodule TigerBeetlex.Account do
  @moduledoc """
  Account struct module.

  This module defines a struct that represents a TigerBeetle account.

  See [TigerBeetle docs](https://docs.tigerbeetle.com/reference/accounts) for the meaning of the
  fields.
  """

  use TypedStruct

  alias TigerBeetlex.Account
  alias TigerBeetlex.Account.Flags
  alias TigerBeetlex.Types

  typedstruct do
    @typedoc "A struct representing a TigerBeetle account"

    field :id, Types.id_128(), enforce: true
    field :debits_pending, non_neg_integer(), default: 0
    field :debits_posted, non_neg_integer(), default: 0
    field :credits_pending, non_neg_integer(), default: 0
    field :credits_posted, non_neg_integer(), default: 0
    field :user_data_128, Types.user_data_128()
    field :user_data_64, Types.user_data_64()
    field :user_data_32, Types.user_data_32()
    field :ledger, non_neg_integer(), enforce: true
    field :code, non_neg_integer(), enforce: true
    field :flags, Flags.t(), default: %Flags{}
    field :timestamp, non_neg_integer(), default: 0
  end

  @doc """
  Converts the binary representation of an account (128 bytes) in a
  `%TigerBeetlex.Account{}` struct
  """
  @spec from_binary(bin :: Types.account_binary()) :: t()
  def from_binary(<<_::binary-size(128)>> = bin) do
    <<id::binary-size(16), debits_pending::unsigned-little-128,
      debits_posted::unsigned-little-128, credits_pending::unsigned-little-128,
      credits_posted::unsigned-little-128, user_data_128::binary-size(16),
      user_data_64::binary-size(8), user_data_32::binary-size(4), _reserved::binary-size(4),
      ledger::unsigned-little-32, code::unsigned-little-16, flags::unsigned-little-16,
      timestamp::unsigned-little-64>> = bin

    %Account{
      id: id,
      debits_pending: debits_pending,
      debits_posted: debits_posted,
      credits_pending: credits_pending,
      credits_posted: credits_posted,
      user_data_128: nilify_user_data_128_default(user_data_128),
      user_data_64: nilify_user_data_64_default(user_data_64),
      user_data_32: nilify_user_data_32_default(user_data_32),
      ledger: ledger,
      code: code,
      flags: Flags.from_u16!(flags),
      timestamp: timestamp
    }
  end

  defp nilify_user_data_128_default(<<0::unit(8)-size(16)>>), do: nil
  defp nilify_user_data_128_default(value), do: value

  defp nilify_user_data_64_default(<<0::unit(8)-size(8)>>), do: nil
  defp nilify_user_data_64_default(value), do: value

  defp nilify_user_data_32_default(<<0::unit(8)-size(4)>>), do: nil
  defp nilify_user_data_32_default(value), do: value

  @doc """
  Converts a `%TigerBeetlex.Account{}` to its binary representation (128 bytes
  binary) in a `%TigerBeetlex.AccountBatch{}`. Note that this skips (i.e.
  serializes with zeroes) all server controlled fields:
  - `:debits_pending`
  - `:debits_posted`
  - `:debits_pending`
  - `:debits_posted`
  - `:timestamp`
  """
  @spec to_batch_item(account :: t()) :: Types.account_binary()
  def to_batch_item(%Account{} = account) do
    %Account{
      id: id,
      user_data_128: user_data_128,
      user_data_64: user_data_64,
      user_data_32: user_data_32,
      ledger: ledger,
      code: code,
      flags: flags
    } = account

    reserved = <<0::unit(8)-size(4)>>
    debits_and_credits = <<0::unit(8)-size(16 * 4)>>
    timestamp = <<0::unit(8)-size(8)>>

    flags_u16 =
      (flags || %Flags{})
      |> Flags.to_u16!()

    <<id::binary-size(16), debits_and_credits::binary-size(16 * 4),
      user_data_128_default(user_data_128)::binary-size(16),
      user_data_64_default(user_data_64)::binary-size(8),
      user_data_32_default(user_data_32)::binary-size(4), reserved::binary,
      ledger::unsigned-little-32, code::unsigned-little-16, flags_u16::unsigned-little-16,
      timestamp::binary>>
  end

  defp user_data_128_default(nil), do: <<0::unit(8)-size(16)>>
  defp user_data_128_default(value), do: value

  defp user_data_64_default(nil), do: <<0::unit(8)-size(8)>>
  defp user_data_64_default(value), do: value

  defp user_data_32_default(nil), do: <<0::unit(8)-size(4)>>
  defp user_data_32_default(value), do: value
end
