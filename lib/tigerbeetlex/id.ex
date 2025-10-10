defmodule TigerBeetlex.ID do
  @moduledoc """
  Utility functions to generate TigerBeetle Time-Based Identifiers.
  """

  @doc """
  Generate a TigerBeetle Time-Based Identifier.

  This is a lexicographically-sortable time-based monotonic identifier. See
  [TigerBeetle docs](https://docs.tigerbeetle.com/coding/data-modeling/#tigerbeetle-time-based-identifiers-recommended)
  for the complete explanation of the format.
  """
  # Based on Python implementation as the reference
  # See https://github.com/tigerbeetle/tigerbeetle/issues/3301
  def generate do
    atomics = :persistent_term.get(:tigerbeetlex_id_atomics)
    ms_now = System.system_time(:millisecond)
    ms_in_atomics = :atomics.get(atomics, 1)
    random = :atomics.get(atomics, 2)
    do_generate(atomics, ms_now, ms_in_atomics, random)
  end

  defp do_generate(atomics, ms_now, ms_in_atomics, random) do
    case ms_in_atomics do
      ms_higher_than_now when ms_higher_than_now > ms_now ->
        do_finish_generate(atomics, ms_higher_than_now, random, random + 1)

      ^ms_now ->
        do_finish_generate(atomics, ms_now, random, random + 1)

      ms_lower_than_now ->
        random = :rand.uniform(unquote(2 ** 64)) - 1

        case :atomics.compare_exchange(atomics, 1, ms_lower_than_now, ms_now) do
          :ok ->
            :atomics.put(atomics, 2, random)
            seed = :rand.uniform(unquote(2 ** 16)) - 1
            <<ms_now::unsigned-integer-size(48), random::unsigned-integer-size(64), seed::unsigned-integer-size(16)>>

          ms_in_atomics ->
            random = :atomics.get(atomics, 2)
            do_generate(atomics, ms_now, ms_in_atomics, random)
        end
    end
  end

  # Tested out with Python implementation as a reference
  defp do_finish_generate(atomics, ms, expected_random, desired_random) do
    case :atomics.compare_exchange(atomics, 2, expected_random, desired_random) do
      :ok ->
        seed = :rand.uniform(unquote(2 ** 16)) - 1
        <<ms::unsigned-integer-size(48), desired_random::unsigned-integer-size(64), seed::unsigned-integer-size(16)>>

      new_random when new_random >= desired_random ->
        do_finish_generate(atomics, ms, new_random, new_random + 1)

      new_random ->
        do_finish_generate(atomics, ms, new_random, desired_random)
    end
  end

  @doc """
  Converts an integer to a 128 bit binary id.

  The integer is formatted in endian format so that the correct ordering is preserved in
  TigerBeetle LSM trees.
  """
  def from_int(n) when is_integer(n) and n >= 0 do
    <<n::unsigned-integer-size(128)>>
  end

  @doc false
  def validate(<<_::128>> = value), do: {:ok, value}
  def validate(_other), do: {:error, "not a valid 128-bit binary"}
end
