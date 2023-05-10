defmodule TigerBeetlex.CreateAccountError do
  use TypedStruct

  alias TigerBeetlex.CreateAccountError

  @type reason ::
          :linked_event_failed
          | :linked_event_chain_open
          | :timestamp_must_be_zero
          | :reserved_flag
          | :reserved_field
          | :id_must_not_be_zero
          | :id_must_not_be_int_max
          | :flags_are_mutually_exclusive
          | :ledger_must_not_be_zero
          | :code_must_not_be_zero
          | :debits_pending_must_be_zero
          | :debits_posted_must_be_zero
          | :credits_pending_must_be_zero
          | :credits_posted_must_be_zero
          | :exists_with_different_flags
          | :exists_with_different_user_data
          | :exists_with_different_ledger
          | :exists_with_different_code
          | :exists

  # Taken from tb_client.h
  @result_to_atom_map [
                        :linked_event_failed,
                        :linked_event_chain_open,
                        :timestamp_must_be_zero,
                        :reserved_flag,
                        :reserved_field,
                        :id_must_not_be_zero,
                        :id_must_not_be_int_max,
                        :flags_are_mutually_exclusive,
                        :ledger_must_not_be_zero,
                        :code_must_not_be_zero,
                        :debits_pending_must_be_zero,
                        :debits_posted_must_be_zero,
                        :credits_pending_must_be_zero,
                        :credits_posted_must_be_zero,
                        :exists_with_different_flags,
                        :exists_with_different_user_data,
                        :exists_with_different_ledger,
                        :exists_with_different_code,
                        :exists
                      ]
                      |> Enum.with_index(1)
                      |> Enum.into(%{}, fn {reason, idx} -> {idx, reason} end)

  typedstruct do
    @typedoc "A struct representing an error occured during a create_accounts operation"

    field :index, non_neg_integer(), enforce: true
    field :reason, reason(), enforce: true
  end

  def from_binary!(<<_::binary-size(8)>> = bin) do
    <<index::unsigned-little-32, result::unsigned-little-32>> = bin

    %CreateAccountError{
      index: index,
      reason: Map.fetch!(@result_to_atom_map, result)
    }
  end
end
