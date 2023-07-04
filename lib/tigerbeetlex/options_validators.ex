defmodule TigerBeetlex.OptionsValidators do
  @moduledoc false

  # TODO: should we also accept integers and automatically transform them to binaries?
  def validate_id(<<_::128>> = value) do
    {:ok, value}
  end

  def validate_id(other) do
    {:error, "expected ID (128-bit binary), got: #{inspect(other)}"}
  end
end
