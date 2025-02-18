defmodule TigerBeetlex.Account.Flags do
  @moduledoc """
  Account Flags.

  This module defines a struct that represents the flags for a TigerBeetle account. Flags are all
  false by default.

  See [TigerBeetle docs](https://docs.tigerbeetle.com/reference/accounts#flags) for the meaning
  of the flags.
  """

  use TypedStruct

  alias TigerBeetlex.Account.Flags

  typedstruct do
    @typedoc "A struct representing TigerBeetle account flags"

    field :closed, boolean(), default: false
    field :imported, boolean(), default: false
    field :linked, boolean(), default: false
    field :debits_must_not_exceed_credits, boolean(), default: false
    field :credits_must_not_exceed_debits, boolean(), default: false
    field :history, boolean(), default: false
  end

  @doc """
  Converts the integer representation of flags (16 bit unsigned int) in a
  `%TigerBeetlex.Account.Flags{}` struct
  """
  @spec from_u16!(n :: non_neg_integer()) :: t()
  def from_u16!(n) when n >= 0 and n < 65_536 do
    # We use big endian for the source number so we can just follow the (reverse) order of
    # the struct for the fields without manually swapping bytes
    <<_padding::10, closed::1, imported::1, history::1, credits_must_not_exceed_debits::1,
      debits_must_not_exceed_credits::1, linked::1>> = <<n::unsigned-big-16>>

    %Flags{
      closed: closed == 1,
      imported: imported == 1,
      history: history == 1,
      linked: linked == 1,
      debits_must_not_exceed_credits: debits_must_not_exceed_credits == 1,
      credits_must_not_exceed_debits: credits_must_not_exceed_debits == 1
    }
  end

  @doc """
  Converts a `%TigerBeetlex.Account.Flags{}` struct to its integer representation (16 bit unsigned
  int)
  """
  @spec to_u16!(flags :: t()) :: non_neg_integer()
  def to_u16!(%Flags{} = flags) do
    %Flags{
      linked: linked,
      debits_must_not_exceed_credits: debits_must_not_exceed_credits,
      credits_must_not_exceed_debits: credits_must_not_exceed_debits,
      closed: closed,
      imported: imported,
      history: history
    } = flags

    # We use big endian for the destination number so we can just follow the (reverse) order of
    # the struct for the fields without manually swapping bytes
    <<n::unsigned-big-16>> =
      <<_padding = 0::10, bool_to_u1(closed)::1, bool_to_u1(imported)::1, bool_to_u1(history)::1,
        bool_to_u1(credits_must_not_exceed_debits)::1,
        bool_to_u1(debits_must_not_exceed_credits)::1, bool_to_u1(linked)::1>>

    n
  end

  @spec bool_to_u1(b :: boolean()) :: 0 | 1
  defp bool_to_u1(false), do: 0
  defp bool_to_u1(true), do: 1
end
