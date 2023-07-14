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

  alias TigerBeetlex.IDBatch
  alias TigerBeetlex.NifAdapter
  alias TigerBeetlex.Types

  @doc """
  Creates a new id batch with the specified capacity.

  The capacity is the maximum number of IDs that can be added to the batch.
  """
  @spec new(capacity :: non_neg_integer()) ::
          {:ok, t()} | {:error, Types.create_id_batch_error()}
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
      {:error, reason} -> raise RuntimeError, inspect(reason)
    end
  end

  @doc """
  Adds an ID to the batch.
  """
  @spec add_id(batch :: t(), id :: Types.uint128()) ::
          {:ok, t()} | {:error, Types.add_id_error()}
  def add_id(%IDBatch{} = batch, id) do
    with {:ok, _new_length} <- NifAdapter.add_id(batch.ref, id) do
      {:ok, batch}
    end
  end

  @doc """
  Adds an ID to the batch, raising in case of an error.
  """
  @spec add_id!(batch :: t(), id :: Types.uint128()) :: t()
  def add_id!(%IDBatch{} = batch, id) do
    case add_id(batch, id) do
      {:ok, batch} -> batch
      {:error, reason} -> raise RuntimeError, inspect(reason)
    end
  end
end
