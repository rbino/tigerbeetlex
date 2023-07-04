defmodule TigerBeetlex.Transfer.Flags do
  @moduledoc """
  Transfer Flags.

  This module defines a struct that represents the flags for a TigerBeetle transfer. Flags are all
  false by default.

  See [TigerBeetle docs](https://docs.tigerbeetle.com/reference/transfers#flags) for the meaning
  of the flags.
  """

  use TypedStruct

  alias TigerBeetlex.Transfer.Flags

  typedstruct do
    @typedoc "A struct representing TigerBeetle transfer flags"

    field :linked, boolean(), default: false
    field :pending, boolean(), default: false
    field :post_pending_transfer, boolean(), default: false
    field :void_pending_transfer, boolean(), default: false
    field :balancing_debit, boolean(), default: false
    field :balancing_credit, boolean(), default: false
  end

  @doc """
  Converts the integer representation of flags (16 bit unsigned int) in a
  `%TigerBeetlex.Transfer.Flags{}` struct
  """
  @spec from_u16!(n :: non_neg_integer()) :: t()
  def from_u16!(n) when n >= 0 and n < 65_536 do
    # We use big endian for the source number so we can just follow the (reverse) order of
    # the struct for the fields without manually swapping bytes
    <<_padding::10, balancing_credit::1, balancing_debit::1, void_pending_transfer::1,
      post_pending_transfer::1, pending::1, linked::1>> = <<n::unsigned-big-16>>

    %Flags{
      linked: linked == 1,
      pending: pending == 1,
      post_pending_transfer: post_pending_transfer == 1,
      void_pending_transfer: void_pending_transfer == 1,
      balancing_debit: balancing_debit == 1,
      balancing_credit: balancing_credit == 1
    }
  end

  @doc """
  Converts a `%TigerBeetlex.Transfer.Flags{}` struct to its integer representation (16 bit unsigned
  int)
  """
  @spec to_u16!(flags :: t()) :: non_neg_integer()
  def to_u16!(%Flags{} = flags) do
    %Flags{
      linked: linked,
      pending: pending,
      post_pending_transfer: post_pending_transfer,
      void_pending_transfer: void_pending_transfer,
      balancing_debit: balancing_debit,
      balancing_credit: balancing_credit
    } = flags

    # We use big endian for the destination number so we can just follow the (reverse) order of
    # the struct for the fields without manually swapping bytes
    <<n::unsigned-big-16>> =
      <<_padding = 0::10, bool_to_u1(balancing_credit)::1, bool_to_u1(balancing_debit)::1,
        bool_to_u1(void_pending_transfer)::1, bool_to_u1(post_pending_transfer)::1,
        bool_to_u1(pending)::1, bool_to_u1(linked)::1>>

    n
  end

  @spec bool_to_u1(b :: boolean()) :: 0 | 1
  defp bool_to_u1(false), do: 0
  defp bool_to_u1(true), do: 1
end
