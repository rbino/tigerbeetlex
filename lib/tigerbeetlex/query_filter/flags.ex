defmodule TigerBeetlex.QueryFilter.Flags do
  @moduledoc """
    See https://docs.tigerbeetle.com/reference/query-filter#flags
  """

  use TypedStruct
  alias TigerBeetlex.QueryFilter.Flags

  typedstruct do
    field :reversed, boolean(), default: false
  end

  @doc """
  Converts a `%Tigerbeetlex.QueryFilter.Flags{}` struct to its integer representation (32 bit unsigned
  int)
  """
  @spec to_u32!(flags :: t()) :: non_neg_integer()
  def to_u32!(%Flags{} = flags) do
    %Flags{
      reversed: reversed
    } = flags

    # We use big endian for the destination number so we can just follow the (reverse) order of
    # the struct for the fields without manually swapping bytes
    <<n::unsigned-big-32>> = <<_padding = 0::31, bool_to_u1(reversed)::1>>
    n
  end

  @spec bool_to_u1(b :: boolean()) :: 0 | 1
  defp bool_to_u1(false), do: 0
  defp bool_to_u1(true), do: 1
end
