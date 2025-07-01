defmodule TigerBeetlex.CDC.Account do
  @moduledoc """
  A struct representing an Account in a TigerBeetle CDC event, see
  [Change Data Capture](https://docs.tigerbeetle.com/operating/cdc/#message-content)

  This is almost the same as `TigerBeetlex.Account` except it doesn't contain
  the `ledger` field, since it's defined in the parent `TigerBeetlex.CDC.Event`.
  """

  use TypedStruct

  alias TigerBeetlex.CDC
  alias TigerBeetlex.CDC.AccountFlags

  typedstruct enforce: true do
    field :id, <<_::128>>
    field :debits_pending, non_neg_integer()
    field :debits_posted, non_neg_integer()
    field :credits_pending, non_neg_integer()
    field :credits_posted, non_neg_integer()
    field :user_data_128, <<_::128>>
    field :user_data_64, non_neg_integer()
    field :user_data_32, non_neg_integer()
    field :code, non_neg_integer()
    field :flags, AccountFlags.t()
    field :timestamp, non_neg_integer()
  end

  @doc false
  def cast!(params) do
    CDC.cast_struct!(
      __MODULE__,
      [
        {:id, &CDC.cast_id!/1},
        {:debits_pending, &CDC.cast_int!/1},
        {:debits_posted, &CDC.cast_int!/1},
        {:credits_pending, &CDC.cast_int!/1},
        {:credits_posted, &CDC.cast_int!/1},
        {:user_data_128, &CDC.cast_id!/1},
        {:user_data_64, &CDC.cast_int!/1},
        {:user_data_32, &CDC.cast_int!/1},
        {:code, &CDC.cast_int!/1},
        {:flags, &AccountFlags.cast!/1},
        {:timestamp, &CDC.cast_int!/1}
      ],
      params
    )
  end
end
