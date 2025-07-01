defmodule TigerBeetlex.CDC.TransferFlags do
  @moduledoc """
  A struct representing TransferFlags in a TigerBeetle CDC event, see
  [Change Data Capture](https://docs.tigerbeetle.com/operating/cdc/#message-content)

  This is the same as `TigerBeetlex.TransferFlags`, just moved to the
  `CDC` namespace for consistency.
  """
  use TypedStruct

  # Extract the fields from TigerBeetlex.AccountFlags
  @fields %TigerBeetlex.TransferFlags{} |> Map.from_struct() |> Map.keys()

  # Replicate them here
  typedstruct enforce: true do
    for field <- @fields do
      field field, boolean()
    end
  end

  @doc false
  def cast!(term) when is_integer(term) do
    <<term::unsigned-little-16>>
    |> TigerBeetlex.TransferFlags.from_binary()
    |> Map.from_struct()
    |> then(&struct!(__MODULE__, &1))
  end
end
