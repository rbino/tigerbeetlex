defmodule TigerBeetlex.TransferBatch do
  @moduledoc """
  Transfer Batch creation and manipulation.

  This module collects functions to interact with a transfer batch. A Transfer Batch represents a
  list of Transfers (with a maximum capacity) that will be used to submit a Create Transfers
  operation on TigerBeetle.

  The Transfer Batch should be treated as an opaque and underneath it is implemented with a
  mutable NIF resource. It is safe to modify a Transfer Batch from multiple processes concurrently.
  """

  use TypedStruct

  typedstruct do
    field :ref, reference(), enforce: true
  end

  alias TigerBeetlex.Transfer
  alias TigerBeetlex.TransferBatch
  alias TigerBeetlex.BatchFullError
  alias TigerBeetlex.InvalidBatchError
  alias TigerBeetlex.OutOfMemoryError
  alias TigerBeetlex.NifAdapter
  alias TigerBeetlex.Types

  @doc """
  Creates a new transfer batch with the specified capacity.

  The capacity is the maximum number of transfers that can be added to the batch.
  """
  @spec new(capacity :: non_neg_integer()) ::
          {:ok, t()} | {:error, Types.create_batch_error()}
  def new(capacity) when is_integer(capacity) and capacity > 0 do
    with {:ok, ref} <- NifAdapter.create_transfer_batch(capacity) do
      {:ok, %TransferBatch{ref: ref}}
    end
  end

  @doc """
  Creates a new transfer batch with the specified capacity, rasing in case of an error..

  The capacity is the maximum number of transfers that can be added to the batch.
  """
  @spec new!(capacity :: non_neg_integer()) :: t()
  def new!(capacity) when is_integer(capacity) and capacity > 0 do
    case new(capacity) do
      {:ok, batch} -> batch
      {:error, :out_of_memory} -> raise OutOfMemoryError
    end
  end

  @doc """
  Appends a transfer to the batch.

  The `%Transfer{}` struct must contain at least `:id`, see [TigerBeetle
  documentation](https://docs.tigerbeetle.com/reference/transfers#modes) for the other required
  fields depending on the mode of operation. The `:timestamp` field is ignored since it is
  server-controlled.
  """
  @spec append(batch :: t(), transfer :: TigerBeetlex.Transfer.t()) ::
          {:ok, t()} | {:error, Types.append_error()}
  def append(%TransferBatch{} = batch, %Transfer{} = transfer) do
    %TransferBatch{ref: ref} = batch

    transfer_binary = Transfer.to_batch_item(transfer)

    with :ok <- NifAdapter.append_transfer(ref, transfer_binary) do
      {:ok, batch}
    end
  end

  @doc """
  Appends a transfer to the batch, raising in case of an error.

  See `append/2` for the supported fields in the `%Transfer{}` struct.
  """
  @spec append!(batch :: t(), transfer :: TigerBeetlex.Transfer.t()) :: t()
  def append!(%TransferBatch{} = batch, %Transfer{} = transfer) do
    case append(batch, transfer) do
      {:ok, batch} -> batch
      {:error, :invalid_batch} -> raise InvalidBatchError
      {:error, :batch_full} -> raise BatchFullError
    end
  end

  @doc """
  Fetches a `%Transfer{}` from the batch, given its index.
  """
  @spec fetch(batch :: t(), idx :: non_neg_integer()) ::
          {:ok, TigerBeetlex.Transfer.t()} | {:error, Types.fetch_error()}
  def fetch(batch, idx) when is_number(idx) and idx >= 0 do
    with {:ok, transfer_binary} <- NifAdapter.fetch_transfer(batch.ref, idx) do
      {:ok, Transfer.from_binary(transfer_binary)}
    end
  end
end
