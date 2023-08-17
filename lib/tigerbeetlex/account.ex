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

    field :id, Types.uint128(), enforce: true
    field :user_data, Types.uint128()
    field :ledger, non_neg_integer(), enforce: true
    field :code, non_neg_integer(), enforce: true
    field :flags, Flags.t(), default: %Flags{}
    field :debits_pending, non_neg_integer(), default: 0
    field :debits_posted, non_neg_integer(), default: 0
    field :credits_pending, non_neg_integer(), default: 0
    field :credits_posted, non_neg_integer(), default: 0
    field :timestamp, non_neg_integer(), default: 0
  end

  @doc """
  Converts the binary representation of an account (128 bytes) in a
  `%TigerBeetlex.Account{}` struct
  """
  @spec from_binary(bin :: Types.account_binary()) :: t()
  def from_binary(<<_::binary-size(128)>> = bin) do
    <<id::binary-size(16), user_data::binary-size(16), _reserved::binary-size(48),
      ledger::unsigned-little-32, code::unsigned-little-16, flags::unsigned-little-16,
      debits_pending::unsigned-little-64, debits_posted::unsigned-little-64,
      credits_pending::unsigned-little-64, credits_posted::unsigned-little-64,
      timestamp::unsigned-little-64>> = bin

    %Account{
      id: id,
      user_data: nilify_u128_default(user_data),
      ledger: ledger,
      code: code,
      flags: Flags.from_u16!(flags),
      debits_pending: debits_pending,
      debits_posted: debits_posted,
      credits_pending: credits_pending,
      credits_posted: credits_posted,
      timestamp: timestamp
    }
  end

  defp nilify_u128_default(<<0::unit(8)-size(16)>>), do: nil
  defp nilify_u128_default(value), do: value

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
      user_data: user_data,
      ledger: ledger,
      code: code,
      flags: flags
    } = account

    reserved = <<0::unit(8)-size(48)>>
    server_controlled = <<0::unit(8)-size(40)>>

    flags_u16 =
      (flags || %Flags{})
      |> Flags.to_u16!()

    <<id::binary-size(16), u128_default(user_data)::binary-size(16), reserved::binary-size(48),
      ledger::unsigned-little-32, code::unsigned-little-16, flags_u16::unsigned-little-16,
      server_controlled::binary-size(40)>>
  end

  defp u128_default(nil), do: <<0::unit(8)-size(16)>>
  defp u128_default(value), do: value
end
