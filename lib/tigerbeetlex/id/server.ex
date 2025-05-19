defmodule TigerBeetlex.ID.Server do
  @moduledoc false
  use Agent

  def start_link(_opts) do
    initial_time_ms = 0
    <<initial_random::unsigned-little-integer-size(80)>> = :rand.bytes(10)
    Agent.start_link(fn -> {initial_time_ms, initial_random} end, name: __MODULE__)
  end

  def generate_id do
    Agent.get_and_update(__MODULE__, &generate_and_update_state/1)
  end

  defp generate_and_update_state({last_time_ms, last_random} = _state) do
    current_time_ms = System.system_time(:millisecond)

    {time_ms, random} =
      if current_time_ms <= last_time_ms do
        incremented_random = check_overflow!(last_random + 1)
        {last_time_ms, incremented_random}
      else
        <<new_random::unsigned-little-integer-size(80)>> = :rand.bytes(10)
        {current_time_ms, new_random}
      end

    generated_id = <<random::unsigned-little-integer-size(80), time_ms::unsigned-little-integer-size(48)>>

    {generated_id, {time_ms, random}}
  end

  defp check_overflow!(n) do
    if <<n::unsigned-little-integer-size(80)>> == <<0::80>> do
      raise "Overflow in TigerBeetlex.ID.Server"
    else
      n
    end
  end
end
