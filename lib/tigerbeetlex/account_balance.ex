defmodule TigerBeetlex.AccountBalance do
  @moduledoc """
  AccountBalance struct module.

  This module defines a struct that represents a TigerBeetle account-balance.

  See [TigerBeetle docs](https://docs.tigerbeetle.com/reference/accounts) for the meaning of the
  fields.
  """

  use TypedStruct

  alias TigerBeetlex.AccountBalance
  alias TigerBeetlex.Types

  typedstruct do
    @typedoc "A struct representing a TigerBeetle account-balance"

    field :timestamp, non_neg_integer()
    field :debits_pending, non_neg_integer()
    field :debits_posted, non_neg_integer()
    field :credits_pending, non_neg_integer()
    field :credits_posted, non_neg_integer()
  end

  @doc """
  Converts the binary representation of an account-balance (128 bytes) in a
  `%TigerBeetlex.AccountBalance{}` struct
  """
  @spec from_binary(bin :: Types.account_binary()) :: t()
  def from_binary(<<_::binary-size(128)>> = bin) do
    <<debits_pending::unsigned-little-128, debits_posted::unsigned-little-128,
      credits_pending::unsigned-little-128, credits_posted::unsigned-little-128,
      timestamp::unsigned-little-64, _reserved::binary-size(56)>> = bin

    %AccountBalance{
      timestamp: timestamp,
      debits_pending: debits_pending,
      debits_posted: debits_posted,
      credits_pending: credits_pending,
      credits_posted: credits_posted
    }
  end
end
