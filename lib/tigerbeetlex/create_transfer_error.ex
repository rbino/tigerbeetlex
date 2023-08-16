defmodule TigerBeetlex.CreateTransferError do
  @moduledoc """
  Decode transfer creation errors.

  This module defines a struct that represents errors happening during a CreateAccount operation
  in TigerBeetle. The `:index` indicates the (0-based) index of the Transfer in the Transfer Batch
  that failed its creation, `:reason` indicates the reason for the error.

  See [TigerBeetle docs]
  (https://docs.tigerbeetle.com/reference/operations/create_transfers#result) for the meaning of the
  errors.
  """

  use TypedStruct

  alias TigerBeetlex.CreateTransferError

  @type reason ::
          :linked_event_failed
          | :linked_event_chain_open
          | :timestamp_must_be_zero
          | :reserved_flag
          | :reserved_field
          | :id_must_not_be_zero
          | :id_must_not_be_int_max
          | :flags_are_mutually_exclusive
          | :debit_account_id_must_not_be_zero
          | :debit_account_id_must_not_be_int_max
          | :credit_account_id_must_not_be_zero
          | :credit_account_id_must_not_be_int_max
          | :accounts_must_be_different
          | :pending_id_must_be_zero
          | :pending_id_must_not_be_zero
          | :pending_id_must_not_be_int_max
          | :pending_id_must_be_different
          | :timeout_reserved_for_pending_transfer
          | :ledger_must_not_be_zero
          | :code_must_not_be_zero
          | :amount_must_not_be_zero
          | :debit_account_not_found
          | :credit_account_not_found
          | :accounts_must_have_the_same_ledger
          | :transfer_must_have_the_same_ledger_as_accounts
          | :pending_transfer_not_found
          | :pending_transfer_not_pending
          | :pending_transfer_has_different_debit_account_id
          | :pending_transfer_has_different_credit_account_id
          | :pending_transfer_has_different_ledger
          | :pending_transfer_has_different_code
          | :exceeds_pending_transfer_amount
          | :pending_transfer_has_different_amount
          | :pending_transfer_already_posted
          | :pending_transfer_already_voided
          | :pending_transfer_expired
          | :exists_with_different_flags
          | :exists_with_different_debit_account_id
          | :exists_with_different_credit_account_id
          | :exists_with_different_pending_id
          | :exists_with_different_user_data
          | :exists_with_different_timeout
          | :exists_with_different_code
          | :exists_with_different_amount
          | :exists
          | :overflows_debits_pending
          | :overflows_credits_pending
          | :overflows_debits_posted
          | :overflows_credits_posted
          | :overflows_debits
          | :overflows_credits
          | :overflows_timeout
          | :exceeds_credits
          | :exceeds_debits

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
                        :debit_account_id_must_not_be_zero,
                        :debit_account_id_must_not_be_int_max,
                        :credit_account_id_must_not_be_zero,
                        :credit_account_id_must_not_be_int_max,
                        :accounts_must_be_different,
                        :pending_id_must_be_zero,
                        :pending_id_must_not_be_zero,
                        :pending_id_must_not_be_int_max,
                        :pending_id_must_be_different,
                        :timeout_reserved_for_pending_transfer,
                        :ledger_must_not_be_zero,
                        :code_must_not_be_zero,
                        :amount_must_not_be_zero,
                        :debit_account_not_found,
                        :credit_account_not_found,
                        :accounts_must_have_the_same_ledger,
                        :transfer_must_have_the_same_ledger_as_accounts,
                        :pending_transfer_not_found,
                        :pending_transfer_not_pending,
                        :pending_transfer_has_different_debit_account_id,
                        :pending_transfer_has_different_credit_account_id,
                        :pending_transfer_has_different_ledger,
                        :pending_transfer_has_different_code,
                        :exceeds_pending_transfer_amount,
                        :pending_transfer_has_different_amount,
                        :pending_transfer_already_posted,
                        :pending_transfer_already_voided,
                        :pending_transfer_expired,
                        :exists_with_different_flags,
                        :exists_with_different_debit_account_id,
                        :exists_with_different_credit_account_id,
                        :exists_with_different_pending_id,
                        :exists_with_different_user_data,
                        :exists_with_different_timeout,
                        :exists_with_different_code,
                        :exists_with_different_amount,
                        :exists,
                        :overflows_debits_pending,
                        :overflows_credits_pending,
                        :overflows_debits_posted,
                        :overflows_credits_posted,
                        :overflows_debits,
                        :overflows_credits,
                        :overflows_timeout,
                        :exceeds_credits,
                        :exceeds_debits
                      ]
                      |> Enum.with_index(1)
                      |> Enum.into(%{}, fn {reason, idx} -> {idx, reason} end)

  typedstruct do
    @typedoc "A struct representing an error occured during a create_transfers operation"

    field :index, non_neg_integer(), enforce: true
    field :reason, reason(), enforce: true
  end

  @doc """
  Converts the binary representation of the result (8 bytes) in a
  `%TigerBeetlex.CreateTransferError{}` struct
  """
  @spec from_binary(bin :: <<_::64>>) :: t()
  def from_binary(<<_::binary-size(8)>> = bin) do
    <<index::unsigned-little-32, result::unsigned-little-32>> = bin

    %CreateTransferError{
      index: index,
      reason: Map.fetch!(@result_to_atom_map, result)
    }
  end
end
