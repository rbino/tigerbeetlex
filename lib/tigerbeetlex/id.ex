defmodule TigerBeetlex.ID do
  @moduledoc """
  Utility functions to generate TigerBeetle Time-Based Identifiers.
  """

  @atomics_ref_persistent_term_key __MODULE__.Atomics

  @last_time_ms_atomic_idx 1
  @last_random_atomic_idx 2

  @doc """
  Generate a TigerBeetle Time-Based Identifier.

  This is a lexicographically-sortable time-based monotonic identifier. See
  [TigerBeetle docs](https://docs.tigerbeetle.com/coding/data-modeling/#tigerbeetle-time-based-identifiers-recommended)
  for the complete explanation of the format.
  """
  def generate do
    atomics_ref = :persistent_term.get(@atomics_ref_persistent_term_key)
    now_ms = System.system_time(:millisecond)

    {time_ms, random_64} = cas_loop(atomics_ref, now_ms)

    # Erlang atomics are limited to 64 bits, and we need 80 bits of randomness. We generate the 2
    # least significat bytes randomly. We still guarantee monotonicity since we increase random_64
    # when the timestamp is the same, we just have a smaller amount of IDs we can generate in the
    # same millisecond due to this.
    <<random_padding::little-unsigned-integer-16>> = :rand.bytes(2)

    <<random_padding::unsigned-little-integer-size(16), random_64::unsigned-little-integer-size(64),
      time_ms::unsigned-little-integer-size(48)>>
  end

  defp cas_loop(atomics_ref, now_ms) do
    last_ms = :atomics.get(atomics_ref, @last_time_ms_atomic_idx)

    if now_ms <= last_ms do
      # Same millisecond (or time moved backward)
      # We must use `last_ms` to ensure monotonicity, and increase random by 1.
      rand_64 =
        atomics_ref
        |> :atomics.add_get(@last_random_atomic_idx, 1)
        |> check_overflow!()

      {last_ms, rand_64}
    else
      # Time has moved forward.
      # We must try to "claim" this new millisecond by being the first
      # to swap the `last_time_ms` atomic. We also generate a new random value.

      <<new_rand_64::little-unsigned-integer-64>> = :rand.bytes(8)

      case :atomics.compare_exchange(atomics_ref, @last_time_ms_atomic_idx, last_ms, now_ms) do
        :ok ->
          # We won the race, also update last_random
          :atomics.put(atomics_ref, @last_random_atomic_idx, new_rand_64)

          {now_ms, new_rand_64}

        _changed_value ->
          # Another process beat us to it, we must retry the entire loop.
          # The next attempt will likely fall into the now_ms <= last_ms branch.
          cas_loop(atomics_ref, now_ms)
      end
    end
  end

  defp check_overflow!(0), do: raise("Overflow in TigerBeetlex.ID")
  defp check_overflow!(n), do: n

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

  @doc false
  # Called during application initialization to initialize the atomics for ID generation
  def initialize_atomics do
    atomics_ref = :atomics.new(2, signed: false)
    :persistent_term.put(@atomics_ref_persistent_term_key, atomics_ref)
  end
end
