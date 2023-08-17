defmodule TigerBeetlex.IDBatch do
  @moduledoc """
  ID Batch creation and manipulation.

  This module collects functions to interact with an id batch. An ID Batch represents a list of
  IDs (with a maximum capacity) that will be used to submit a Lookup Accounts or Lookup Transfers
  operation on TigerBeetle.

  The ID Batch should be treated as an opaque and underneath it is implemented with a mutable NIF
  resource. It is safe to modify an ID Batch from multiple processes concurrently.
  """

  use TypedStruct

  typedstruct do
    field :ref, reference(), enforce: true
  end

  alias TigerBeetlex.BatchFullError
  alias TigerBeetlex.IDBatch
  alias TigerBeetlex.InvalidBatchError
  alias TigerBeetlex.OutOfBoundsError
  alias TigerBeetlex.OutOfMemoryError
  alias TigerBeetlex.NifAdapter
  alias TigerBeetlex.Types

  @doc """
  Creates a new id batch with the specified capacity.

  The capacity is the maximum number of IDs that can be added to the batch.
  """
  @spec new(capacity :: non_neg_integer()) ::
          {:ok, t()} | {:error, Types.create_batch_error()}
  def new(capacity) when is_integer(capacity) and capacity > 0 do
    with {:ok, ref} <- NifAdapter.create_id_batch(capacity) do
      {:ok, %IDBatch{ref: ref}}
    end
  end

  @doc """
  Creates a new id batch with the specified capacity, raising in case of an error.

  The capacity is the maximum number of IDs that can be added to the batch.
  """
  @spec new!(capacity :: non_neg_integer()) :: t()
  def new!(capacity) when is_integer(capacity) and capacity > 0 do
    case new(capacity) do
      {:ok, batch} -> batch
      {:error, :out_of_memory} -> raise OutOfMemoryError
    end
  end

  @doc """
  Appends an ID to the batch.
  """
  @spec append(batch :: t(), id :: Types.uint128()) ::
          {:ok, t()} | {:error, Types.append_error()}
  def append(%IDBatch{} = batch, id) do
    with :ok <- NifAdapter.append_id(batch.ref, id) do
      {:ok, batch}
    end
  end

  @doc """
  Appends an ID to the batch, raising in case of an error.
  """
  @spec append!(batch :: t(), id :: Types.uint128()) :: t()
  def append!(%IDBatch{} = batch, id) do
    case append(batch, id) do
      {:ok, batch} -> batch
      {:error, :invalid_batch} -> raise InvalidBatchError
      {:error, :batch_full} -> raise BatchFullError
    end
  end

  @doc """
  Fetches an ID from the batch, given its index.
  """
  @spec fetch(batch :: t(), idx :: non_neg_integer()) ::
          {:ok, Types.uint128()} | {:error, Types.fetch_error()}
  def fetch(%IDBatch{} = batch, idx) when is_number(idx) and idx >= 0 do
    NifAdapter.fetch_id(batch.ref, idx)
  end

  @doc """
  Fetches an ID from the batch, given its index. Raises in case of an error.
  """
  @spec fetch!(batch :: t(), idx :: non_neg_integer()) :: Types.uint128()
  def fetch!(%IDBatch{} = batch, idx) when is_number(idx) and idx >= 0 do
    case fetch(batch, idx) do
      {:ok, id} -> id
      {:error, :invalid_batch} -> raise InvalidBatchError
      {:error, :out_of_bounds} -> raise OutOfBoundsError
    end
  end

  @doc """
  Replaces the ID at index `idx` in the batch.
  """
  @spec replace(batch :: t(), idx :: non_neg_integer(), id :: Types.uint128()) ::
          {:ok, t()} | {:error, Types.replace_error()}
  def replace(%IDBatch{} = batch, idx, <<_::128>> = id) when is_number(idx) and idx >= 0 do
    with :ok <- NifAdapter.replace_id(batch.ref, idx, id) do
      {:ok, batch}
    end
  end

  @doc """
  Replaces the ID at index `idx` in the batch. Raises in case of an error.
  """
  @spec replace!(batch :: t(), idx :: non_neg_integer(), id :: Types.uint128()) :: t()
  def replace!(%IDBatch{} = batch, idx, <<_::128>> = id) when is_number(idx) and idx >= 0 do
    case replace(batch, idx, id) do
      {:ok, batch} -> batch
      {:error, :invalid_batch} -> raise InvalidBatchError
      {:error, :out_of_bounds} -> raise OutOfBoundsError
    end
  end
end
