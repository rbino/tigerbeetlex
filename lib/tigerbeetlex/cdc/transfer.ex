defmodule TigerBeetlex.CDC.Transfer do
  @moduledoc """
  A struct representing a Transfer in a TigerBeetle CDC event, see
  [Change Data Capture](https://docs.tigerbeetle.com/operating/cdc/#message-content).

  This is almost the same as `TigerBeetlex.Transfer` except it doesn't contain
  the `ledger` field, since it's defined in the parent `TigerBeetlex.CDC.Event`, and
  `debit_account_id` and `credit_account_id` since the account information is contained
  in the two `debit_account` and `credit_account` structs in the event.
  """

  use TypedStruct

  alias TigerBeetlex.CDC
  alias TigerBeetlex.CDC.TransferFlags

  typedstruct enforce: true do
    field :id, <<_::128>>
    field :amount, non_neg_integer()
    field :pending_id, <<_::128>>
    field :user_data_128, <<_::128>>
    field :user_data_64, non_neg_integer()
    field :user_data_32, non_neg_integer()
    field :timeout, non_neg_integer()
    field :code, non_neg_integer()
    field :flags, TransferFlags.t()
    field :timestamp, non_neg_integer()
  end

  @doc false
  def cast!(params) do
    CDC.cast_struct!(
      __MODULE__,
      [
        {:id, &CDC.cast_id!/1},
        {:amount, &CDC.cast_int!/1},
        {:pending_id, &CDC.cast_id!/1},
        {:user_data_128, &CDC.cast_id!/1},
        {:user_data_64, &CDC.cast_int!/1},
        {:user_data_32, &CDC.cast_int!/1},
        {:timeout, &CDC.cast_int!/1},
        {:code, &CDC.cast_int!/1},
        {:flags, &TransferFlags.cast!/1},
        {:timestamp, &CDC.cast_int!/1}
      ],
      params
    )
  end
end
