defmodule TigerBeetlex.Transfer.Flags do
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
end
