defmodule TigerBeetlex.Transfer do
  @moduledoc """
  Transfer struct module.

  This module defines a struct that represents a TigerBeetle transfer.

  See [TigerBeetle docs](https://docs.tigerbeetle.com/reference/transfers) for the meaning of the
  fields.
  """

  use TypedStruct

  alias TigerBeetlex.Transfer
  alias TigerBeetlex.Transfer.Flags
  alias TigerBeetlex.Types

  typedstruct do
    @typedoc "A struct representing a TigerBeetle account"

    field :id, Types.uint128(), enforce: true
    field :debit_account_id, Types.uint128()
    field :credit_account_id, Types.uint128()
    field :user_data, Types.uint128()
    field :pending_id, Types.uint128()
    field :timeout, non_neg_integer(), default: 0
    field :ledger, non_neg_integer(), default: 0
    field :code, non_neg_integer(), default: 0
    field :flags, Flags.t(), default: %Flags{}
    field :amount, non_neg_integer(), default: 0
    field :timestamp, non_neg_integer(), default: 0
  end

  @doc """
  Converts the binary representation of an account (128 bytes) in a
  `%TigerBeetlex.Transfer{}` struct
  """
  @spec from_binary(bin :: Types.transfer_binary()) :: t()
  def from_binary(<<_::binary-size(128)>> = bin) do
    <<id::binary-size(16), debit_account_id::binary-size(16), credit_account_id::binary-size(16),
      user_data::binary-size(16), _reserved::binary-size(16), pending_id::binary-size(16),
      timeout::unsigned-little-64, ledger::unsigned-little-32, code::unsigned-little-16,
      flags::unsigned-little-16, amount::unsigned-little-64, timestamp::unsigned-little-64>> = bin

    %Transfer{
      id: id,
      debit_account_id: nilify_u128_default(debit_account_id),
      credit_account_id: nilify_u128_default(credit_account_id),
      user_data: nilify_u128_default(user_data),
      pending_id: nilify_u128_default(pending_id),
      timeout: timeout,
      ledger: ledger,
      code: code,
      flags: Flags.from_u16!(flags),
      amount: amount,
      timestamp: timestamp
    }
  end

  defp nilify_u128_default(<<0::unit(8)-size(16)>>), do: nil
  defp nilify_u128_default(value), do: value

  @doc """
  Converts a `%TigerBeetlex.Transfer{}` to its binary representation (128 bytes
  binary) in a `%TigerBeetlex.TransferBatch{}`. Note that this skips (i.e.
  serializes with zeroes) all server controlled fields:
  - `:timestamp`
  """
  @spec to_batch_item(transfer :: t()) :: Types.transfer_binary()
  def to_batch_item(%Transfer{} = transfer) do
    %Transfer{
      id: id,
      debit_account_id: debit_account_id,
      credit_account_id: credit_account_id,
      user_data: user_data,
      pending_id: pending_id,
      timeout: timeout,
      ledger: ledger,
      code: code,
      flags: flags,
      amount: amount
    } = transfer

    reserved = <<0::unit(8)-size(16)>>
    timestamp = 0

    flags_u16 =
      (flags || %Flags{})
      |> Flags.to_u16!()

    <<id::binary-size(16), u128_default(debit_account_id)::binary-size(16),
      u128_default(credit_account_id)::binary-size(16), u128_default(user_data)::binary-size(16),
      reserved::binary-size(16), u128_default(pending_id)::binary-size(16),
      zero_default(timeout)::unsigned-little-64, zero_default(ledger)::unsigned-little-32,
      zero_default(code)::unsigned-little-16, flags_u16::unsigned-little-16,
      zero_default(amount)::unsigned-little-64, timestamp::unsigned-little-64>>
  end

  defp zero_default(nil), do: 0
  defp zero_default(value), do: value

  defp u128_default(nil), do: <<0::unit(8)-size(16)>>
  defp u128_default(value), do: value
end
