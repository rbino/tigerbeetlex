defmodule TigerBeetlex.Account do
  use TypedStruct

  alias TigerBeetlex.Account
  alias TigerBeetlex.Account.Flags

  typedstruct do
    @typedoc "A struct representing a TigerBeetle account"

    field :id, TigerBeetlex.Types.uint128(), enforce: true
    field :user_data, TigerBeetlex.Types.uint128()
    field :ledger, non_neg_integer(), enforce: true
    field :code, non_neg_integer(), enforce: true
    field :flags, TigerBeetlex.Account.Flags.t()
    field :debits_pending, non_neg_integer()
    field :debits_posted, non_neg_integer()
    field :credits_pending, non_neg_integer()
    field :credits_posted, non_neg_integer()
    field :timestamp, non_neg_integer()
  end

  def from_binary!(<<_::binary-size(128)>> = bin) do
    <<id::binary-size(16), user_data::binary-size(16), _reserved::binary-size(48),
      ledger::unsigned-little-32, code::unsigned-little-16, flags::unsigned-little-16,
      debits_pending::unsigned-little-64, debits_posted::unsigned-little-64,
      credits_pending::unsigned-little-64, credits_posted::unsigned-little-64,
      timestamp::unsigned-little-64>> = bin

    %Account{
      id: id,
      user_data: user_data,
      ledger: ledger,
      code: code,
      flags: Flags.from_u16!(flags),
      debits_pending: debits_pending,
      debits_posted: debits_posted,
      credits_pending: credits_pending,
      credits_posted: credits_posted,
      timestamp: timestamp
    }
  end
end
