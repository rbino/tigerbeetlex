defmodule TigerBeetlex.AccountFilterBatch do
  @moduledoc """
  Account Filter Batch creation and manipulation.
  """

  use TypedStruct

  typedstruct do
    field :ref, reference(), enforce: true
  end

  alias TigerBeetlex.AccountFilter
  alias TigerBeetlex.AccountFilterBatch
  alias TigerBeetlex.InvalidBatchError
  alias TigerBeetlex.NifAdapter
  alias TigerBeetlex.OutOfBoundsError
  alias TigerBeetlex.OutOfMemoryError
  alias TigerBeetlex.Types

  @doc """
  Creates a new account batch with the specified capacity.

  The capacity is the maximum number of accounts that can be added to the batch.
  """
  @spec new(filter :: AccountFilter.t()) ::
          {:ok, t()} | {:error, Types.create_batch_error()} | {:error, Types.append_error()}
  def new(filter) do
    binary = AccountFilter.to_batch_item(filter)
    # 1 is the only valid value here - since that's what tigerbeetle expects
    # https://docs.tigerbeetle.com/reference/requests/#batching-events
    with {:ok, ref} <- NifAdapter.create_account_filter_batch(1),
         :ok <- NifAdapter.append_account_filter(ref, binary) do
      {:ok, %AccountFilterBatch{ref: ref}}
    end
  end

  @doc """
  Creates a new account batch with the specified capacity, rasing in case of an error.
  """
  @spec new!(filter :: AccountFilter.t()) :: t()
  def new!(capacity) when is_integer(capacity) and capacity > 0 do
    case new(capacity) do
      {:ok, batch} -> batch
      {:error, :out_of_memory} -> raise OutOfMemoryError
      {:error, :invalid_batch} -> raise InvalidBatchError
      {:error, :batch_full} -> raise BatchFullError
    end
  end
end
