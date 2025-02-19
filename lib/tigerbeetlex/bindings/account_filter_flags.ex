#######################################################
# This file was auto-generated by elixir_bindings.zig #
#              Do not manually modify.                #
#######################################################

defmodule TigerBeetlex.AccountFilterFlags do
  @moduledoc """
  See [AccountFilterFlags](https://docs.tigerbeetle.com/reference/account-filter#flags).
  """

  use TypedStruct

  typedstruct do
    field :debits, boolean(), default: false
    field :credits, boolean(), default: false
    field :reversed, boolean(), default: false
  end

  @doc """
  Given a binary flags value, returns the corresponding struct.
  """
  def from_binary(<<n::unsigned-little-32>>) do
    <<
      _padding::29,
      reversed::1,
      credits::1,
      debits::1
    >> = <<n::unsigned-big-32>>

    %__MODULE__{
      debits: debits == 1,
      credits: credits == 1,
      reversed: reversed == 1
    }
  end

  @doc """
  Given a `%AccountFilterFlags{}` struct, returns the corresponding serialized binary value.
  """
  def to_binary(flags) do
    %__MODULE__{
      debits: debits,
      credits: credits,
      reversed: reversed
    } = flags

    <<n::unsigned-big-32>> =
      <<
        # padding
        0::29,
        bool_to_u1(reversed)::1,
        bool_to_u1(credits)::1,
        bool_to_u1(debits)::1
      >>

    <<n::unsigned-little-32>>
  end

  @spec bool_to_u1(b :: boolean()) :: 0 | 1
  defp bool_to_u1(true), do: 1
  defp bool_to_u1(false), do: 0
end
