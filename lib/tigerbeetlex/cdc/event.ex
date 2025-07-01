defmodule TigerBeetlex.CDC.Event do
  @moduledoc """
  A struct representing TigerBeetle CDC event, see
  [Change Data Capture](https://docs.tigerbeetle.com/operating/cdc/#message-content).

  Also check out the [guide](change_data_capture.html) to consume CDC data using Broadway.
  """

  use TypedStruct

  alias TigerBeetlex.CDC
  alias TigerBeetlex.CDC.Account
  alias TigerBeetlex.CDC.Transfer
  alias TigerBeetlex.Types

  typedstruct enforce: true do
    field :type, Types.event_type()
    field :timestamp, non_neg_integer()
    field :ledger, non_neg_integer()
    field :transfer, Transfer.t()
    field :debit_account, Account.t()
    field :credit_account, Account.t()
  end

  @doc """
  Creates a `TigerBeetlex.CDC.Event` struct from its JSON map representation.

  This converts all keys to atom, parses all integers, converts all binary IDs and creates
  flags structs from their integer representation.

  Since the format is expected to be well defined, the function raises if it can't cast.

  Note that the TigerBeetle CDC message payload is a string, you have to decode it to a map
  (using, e.g. Jason) before you pass it to this function.

  ## Examples

      alias TigerBeetlex.CDC.Event

      message_body
      |> Jason.decode!()
      |> Event.cast!()

      #=> %TigerBeetlex.CDC.Event{type: :single_phase, transfer: %TigerBeetlex.CDC.Transfer{}, ...}
  """
  @spec cast!(%{required(binary()) => term()}) :: t() | no_return()
  def cast!(params) when is_map(params) do
    CDC.cast_struct!(
      __MODULE__,
      [
        {:type, &cast_type/1},
        {:timestamp, &CDC.cast_int!/1},
        {:ledger, &CDC.cast_int!/1},
        {:transfer, &Transfer.cast!/1},
        {:debit_account, &Account.cast!/1},
        {:credit_account, &Account.cast!/1}
      ],
      params
    )
  end

  defp cast_type("single_phase"), do: :single_phase
  defp cast_type("two_phase_pending"), do: :two_phase_pending
  defp cast_type("two_phase_posted"), do: :two_phase_posted
  defp cast_type("two_phase_voided"), do: :two_phase_voided
  defp cast_type("two_phase_expired"), do: :two_phase_expired
end
