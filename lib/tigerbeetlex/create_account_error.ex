defmodule TigerBeetlex.CreateAccountError do
  @moduledoc """
  Decode account creation errors.

  This module defines a struct that represents errors happening during a CreateAccount operation
  in TigerBeetle. The `:index` indicates the (0-based) index of the Account in the Account Batch
  that failed its creation, `:reason` indicates the reason for the error.

  See [TigerBeetle docs]
  (https://docs.tigerbeetle.com/reference/operations/create_accounts#result) for the meaning of the
  errors.
  """

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

  @doc """
  Converts the binary representation of the result (8 bytes) in a
  `%TigerBeetlex.CreateAccountError{}` struct
  """
  @spec from_binary!(bin :: <<_::64>>) :: t()
  def from_binary!(<<_::binary-size(8)>> = bin) do
    <<index::unsigned-little-32, result::unsigned-little-32>> = bin

    %CreateAccountError{
      index: index,
      reason: Map.fetch!(@result_to_atom_map, result)
    }
  end
end
