defmodule TigerBeetlex.ID do
  @moduledoc """
  Utility functions to generate TigerBeetle Time-Based Identifiers.
  """

  alias TigerBeetlex.ID.Server

  @doc """
  Generate a TigerBeetle Time-Based Identifier.

  This is a lexicographically-sortable time-based monotonic identifier. See
  [TigerBeetle docs](https://docs.tigerbeetle.com/coding/data-modeling/#tigerbeetle-time-based-identifiers-recommended)
  for the complete explanation of the format.
  """
  def generate do
    Server.generate_id()
  end

  @doc """
  Converts an integer to a 128 bit binary id.

  The integer is formatted in little endian format so that the correct ordering is preserved in
  TigerBeetle LSM trees.
  """
  def from_int(n) when is_integer(n) and n >= 0 do
    <<n::unsigned-integer-little-size(128)>>
  end

  @doc false
  def validate(<<_::128>> = value), do: {:ok, value}
  def validate(_other), do: {:error, "not a valid 128-bit binary"}
end
