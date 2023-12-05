defmodule TigerBeetlex.ID128 do
  @moduledoc false
  def validate(<<_::128>> = value), do: {:ok, value}
  def validate(_other), do: {:error, "not a valid 128-bit binary"}
end
