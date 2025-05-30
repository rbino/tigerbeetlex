#######################################################
# This file was auto-generated by elixir_bindings.zig #
#              Do not manually modify.                #
#######################################################

defmodule TigerBeetlex.AccountBalance do
  @moduledoc """
  See [AccountBalance](https://docs.tigerbeetle.com/reference/account-balance#).
  """

  use TypedStruct

  typedstruct do
    field :debits_pending, non_neg_integer(), default: 0
    field :debits_posted, non_neg_integer(), default: 0
    field :credits_pending, non_neg_integer(), default: 0
    field :credits_posted, non_neg_integer(), default: 0
    field :timestamp, non_neg_integer(), default: 0
  end

  @doc """
  Creates a `TigerBeetlex.AccountBalance` struct from its binary representation.
  """
  @spec from_binary(binary :: <<_::1024>>) :: t()
  def from_binary(<<_::binary-size(128)>> = bin) do
    <<
      debits_pending::unsigned-little-128,
      debits_posted::unsigned-little-128,
      credits_pending::unsigned-little-128,
      credits_posted::unsigned-little-128,
      timestamp::unsigned-little-64,
      _reserved::binary-size(56)
    >> = bin

    %__MODULE__{
      debits_pending: debits_pending,
      debits_posted: debits_posted,
      credits_pending: credits_pending,
      credits_posted: credits_posted,
      timestamp: timestamp
    }
  end

  @doc """
  Converts a `TigerBeetlex.AccountBalance` struct to its binary representation.
  """
  @spec to_binary(struct :: t()) :: <<_::1024>>
  def to_binary(struct) do
    %__MODULE__{
      debits_pending: debits_pending,
      debits_posted: debits_posted,
      credits_pending: credits_pending,
      credits_posted: credits_posted,
      timestamp: timestamp
    } = struct

    <<
      debits_pending::unsigned-little-128,
      debits_posted::unsigned-little-128,
      credits_pending::unsigned-little-128,
      credits_posted::unsigned-little-128,
      timestamp::unsigned-little-64,
      # reserved
      0::unit(8)-size(56)
    >>
  end
end
