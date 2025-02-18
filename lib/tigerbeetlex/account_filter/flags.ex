defmodule TigerBeetlex.AccountFilter.Flags do
  @moduledoc """
  AccountFilter Flags.

  This module defines a struct that represents the flags for a TigerBeetle AccountFilter. Flags are all
  false by default.

  See [TigerBeetle docs](https://docs.tigerbeetle.com/reference/account-filter/#flags) for the meaning
  of the flags.
  """

  use TypedStruct

  alias TigerBeetlex.AccountFilter.Flags

  typedstruct do
    @typedoc "A struct representing TigerBeetle transfer flags"

    field :debits, boolean(), default: false
    field :credits, boolean(), default: false
    field :reversed, boolean(), default: false
  end

  @doc """
  Converts the integer representation of flags (16 bit unsigned int) in a
  `%TigerBeetlex.AccountFilter.Flags{}` struct
  """
  @spec from_u32!(n :: non_neg_integer()) :: t()
  def from_u32!(n) when n >= 0 and n < 4_294_967_296 do
    # We use big endian for the source number so we can just follow the (reverse) order of
    # the struct for the fields without manually swapping bytes
    <<_padding::29, reversed::1, credits::1, debits::1>> = <<n::unsigned-big-32>>

    %Flags{
      reversed: reversed == 1,
      credits: credits == 1,
      debits: debits == 1
    }
  end

  @doc """
  Converts a `%TigerBeetlex.AccountFilter.Flags{}` struct to its integer representation (16 bit unsigned
  int)
  """
  @spec to_u32!(flags :: t()) :: non_neg_integer()
  def to_u32!(%Flags{} = flags) do
    %Flags{
      reversed: reversed,
      credits: credits,
      debits: debits
    } = flags

    # We use big endian for the destination number so we can just follow the (reverse) order of
    # the struct for the fields without manually swapping bytes
    <<n::unsigned-big-32>> =
      <<_padding = 0::29, bool_to_u1(reversed)::1, bool_to_u1(credits)::1, bool_to_u1(debits)::1>>

    n
  end

  @spec bool_to_u1(b :: boolean()) :: 0 | 1
  defp bool_to_u1(false), do: 0
  defp bool_to_u1(true), do: 1
end
