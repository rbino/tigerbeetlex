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
  alias TigerBeetlex.OperationResult

  @result_to_atom_map OperationResult.extract_result_map(:CreateAccountResult)
  @type reason :: unquote(OperationResult.result_map_to_typespec(@result_to_atom_map))

  # Taken from tb_client.h

  typedstruct do
    @typedoc "A struct representing an error occured during a create_accounts operation"

    field :index, non_neg_integer(), enforce: true
    field :reason, reason(), enforce: true
  end

  @doc """
  Converts the binary representation of the result (8 bytes) in a
  `%TigerBeetlex.CreateAccountError{}` struct
  """
  @spec from_binary(bin :: <<_::64>>) :: t()
  def from_binary(<<_::binary-size(8)>> = bin) do
    <<index::unsigned-little-32, result::unsigned-little-32>> = bin

    %CreateAccountError{
      index: index,
      reason: Map.fetch!(@result_to_atom_map, result)
    }
  end
end
