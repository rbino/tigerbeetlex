defmodule TigerBeetlex.BatchFullError do
  defexception message: "batch full"
end

defmodule TigerBeetlex.InvalidBatchError do
  defexception message: "invalid batch"
end

defmodule TigerBeetlex.OutOfBoundsError do
  defexception message: "out of bounds"
end

defmodule TigerBeetlex.OutOfMemoryError do
  defexception message: "out of memory"
end
