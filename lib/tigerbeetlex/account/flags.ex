defmodule TigerBeetlex.Account.Flags do
  use TypedStruct

  alias TigerBeetlex.Account.Flags

  typedstruct do
    @typedoc "A struct representing TigerBeetle account flags"

    field :linked, boolean(), default: false
    field :debits_must_not_exceed_credits, boolean(), default: false
    field :credits_must_not_exceed_debits, boolean(), default: false
  end

  def from_u16!(n) when n >= 0 and n < 65_536 do
    # We use big endian for the source number so we can just follow the (reverse) order of
    # the struct for the fields without manually swapping bytes
    <<_padding::13, credits_must_not_exceed_debits::1, debits_must_not_exceed_credits::1,
      linked::1>> = <<n::unsigned-big-16>>

    %Flags{
      linked: linked == 1,
      debits_must_not_exceed_credits: debits_must_not_exceed_credits == 1,
      credits_must_not_exceed_debits: credits_must_not_exceed_debits == 1
    }
  end
end
