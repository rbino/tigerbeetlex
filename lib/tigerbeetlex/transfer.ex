defmodule TigerBeetlex.Transfer do
  @moduledoc """
  Transfer struct module.

  This module defines a struct that represents a TigerBeetle transfer.

  See [TigerBeetle docs](https://docs.tigerbeetle.com/reference/transfer/) for the meaning of the
  fields.
  """

  use TypedStruct

  alias TigerBeetlex.Transfer
  alias TigerBeetlex.Transfer.Flags
  alias TigerBeetlex.Types

  typedstruct do
    @typedoc "A struct representing a TigerBeetle account"

    field :id, Types.id_128(), enforce: true
    field :debit_account_id, Types.id_128()
    field :credit_account_id, Types.id_128()
    field :amount, non_neg_integer(), default: 0
    field :pending_id, Types.id_128()
    field :user_data_128, Types.user_data_128()
    field :user_data_64, Types.user_data_64()
    field :user_data_32, Types.user_data_32()
    field :timeout, non_neg_integer(), default: 0
    field :ledger, non_neg_integer(), default: 0
    field :code, non_neg_integer(), default: 0
    field :flags, Flags.t(), default: %Flags{}
    field :timestamp, non_neg_integer(), default: 0
  end

  @doc """
  Converts the binary representation of an account (128 bytes) in a
  `%TigerBeetlex.Transfer{}` struct
  """
  @spec from_binary(bin :: Types.transfer_binary()) :: t()
  def from_binary(<<_::binary-size(128)>> = bin) do
    <<id::binary-size(16), debit_account_id::binary-size(16), credit_account_id::binary-size(16),
      amount::unsigned-little-128, pending_id::binary-size(16), user_data_128::binary-size(16),
      user_data_64::binary-size(8), user_data_32::binary-size(4), timeout::unsigned-little-32,
      ledger::unsigned-little-32, code::unsigned-little-16, flags::unsigned-little-16,
      timestamp::unsigned-little-64>> = bin

    %Transfer{
      id: id,
      debit_account_id: nilify_id_128_default(debit_account_id),
      credit_account_id: nilify_id_128_default(credit_account_id),
      amount: amount,
      pending_id: nilify_id_128_default(pending_id),
      user_data_128: nilify_user_data_128_default(user_data_128),
      user_data_64: nilify_user_data_64_default(user_data_64),
      user_data_32: nilify_user_data_32_default(user_data_32),
      timeout: timeout,
      ledger: ledger,
      code: code,
      flags: Flags.from_u16!(flags),
      timestamp: timestamp
    }
  end

  defp nilify_id_128_default(<<0::unit(8)-size(16)>>), do: nil
  defp nilify_id_128_default(value), do: value

  defp nilify_user_data_128_default(<<0::unit(8)-size(16)>>), do: nil
  defp nilify_user_data_128_default(value), do: value

  defp nilify_user_data_64_default(<<0::unit(8)-size(8)>>), do: nil
  defp nilify_user_data_64_default(value), do: value

  defp nilify_user_data_32_default(<<0::unit(8)-size(4)>>), do: nil
  defp nilify_user_data_32_default(value), do: value

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
      amount: amount,
      pending_id: pending_id,
      user_data_128: user_data_128,
      user_data_64: user_data_64,
      user_data_32: user_data_32,
      timeout: timeout,
      ledger: ledger,
      code: code,
      flags: flags
    } = transfer

    timestamp = 0

    flags_u16 =
      (flags || %Flags{})
      |> Flags.to_u16!()

    <<id::binary-size(16), id_128_default(debit_account_id)::binary-size(16),
      id_128_default(credit_account_id)::binary-size(16),
      zero_default(amount)::unsigned-little-128, id_128_default(pending_id)::binary-size(16),
      user_data_128_default(user_data_128)::binary-size(16),
      user_data_64_default(user_data_64)::binary-size(8),
      user_data_32_default(user_data_32)::binary-size(4),
      zero_default(timeout)::unsigned-little-32, zero_default(ledger)::unsigned-little-32,
      zero_default(code)::unsigned-little-16, flags_u16::unsigned-little-16,
      timestamp::unsigned-little-64>>
  end

  defp zero_default(nil), do: 0
  defp zero_default(value), do: value

  defp id_128_default(nil), do: <<0::unit(8)-size(16)>>
  defp id_128_default(value), do: value

  defp user_data_128_default(nil), do: <<0::unit(8)-size(16)>>
  defp user_data_128_default(value), do: value

  defp user_data_64_default(nil), do: <<0::unit(8)-size(8)>>
  defp user_data_64_default(value), do: value

  defp user_data_32_default(nil), do: <<0::unit(8)-size(4)>>
  defp user_data_32_default(value), do: value
end
