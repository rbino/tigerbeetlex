#######################################################
# This file was auto-generated by elixir_bindings.zig #
#              Do not manually modify.                #
#######################################################

defmodule TigerBeetlex.QueryFilterFlags do
  import Bitwise

  use TypedStruct

  @moduledoc """
  See [QueryFilterFlags](https://docs.tigerbeetle.com/reference/query-filter#flags).
  """
  typedstruct do
    field :reversed, boolean()
  end

  @doc """
  Given a binary flags value, returns the corresponding struct.
  """
  def from_binary(<<_::binary-size(4)>> = bin) do
    <<
      _padding::31,
      reversed::1
    >> = bin

    %__MODULE__{
      reversed: reversed == 1
    }
  end

  @doc """
  Given a `%QueryFilterFlags{}` struct, returns the corresponding serialized binary value.
  """
  def to_binary(flags) do
    %__MODULE__{
      reversed: reversed
    } = flags

    <<
      # padding
      0::31,
      bool_to_u1(reversed)::1
    >>
  end

  @spec bool_to_u1(b :: boolean()) :: 0 | 1
  defp bool_to_u1(true), do: 1
  defp bool_to_u1(falsy) when falsy in [nil, false], do: 0
end
