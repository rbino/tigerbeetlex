defmodule TigerBeetlex.AccountBatch do
  @moduledoc """
  Account Batch creation and manipulation.

  This module collects functions to interact with an account batch. An Account Batch represents a
  list of Accounts (with a maximum capacity) that will be used to submit a Create Accounts
  operation on TigerBeetle.

  The Account Batch should be treated as an opaque and underneath it is implemented with a
  mutable NIF resource. It is safe to modify an Account Batch from multiple processes concurrently.
  """

  use TypedStruct

  typedstruct do
    field :ref, reference(), enforce: true
  end

  alias TigerBeetlex.Account
  alias TigerBeetlex.AccountBatch
  alias TigerBeetlex.BatchFullError
  alias TigerBeetlex.InvalidBatchError
  alias TigerBeetlex.NifAdapter
  alias TigerBeetlex.OutOfBoundsError
  alias TigerBeetlex.OutOfMemoryError
  alias TigerBeetlex.Types

  @doc """
  Creates a new account batch with the specified capacity.

  The capacity is the maximum number of accounts that can be added to the batch.
  """
  @spec new(capacity :: non_neg_integer()) ::
          {:ok, t()} | {:error, Types.create_batch_error()}
  def new(capacity) when is_integer(capacity) and capacity > 0 do
    with {:ok, ref} <- NifAdapter.create_account_batch(capacity) do
      {:ok, %AccountBatch{ref: ref}}
    end
  end

  @doc """
  Creates a new account batch with the specified capacity, rasing in case of an error.

  The capacity is the maximum number of accounts that can be added to the batch.
  """
  @spec new!(capacity :: non_neg_integer()) :: t()
  def new!(capacity) when is_integer(capacity) and capacity > 0 do
    case new(capacity) do
      {:ok, batch} -> batch
      {:error, :out_of_memory} -> raise OutOfMemoryError
    end
  end

  @doc """
  Appends an account to the batch.

  The `%Account{}` struct must contain at least `:id`, `:ledger` and `:code`, and may also contain
  `:user_data` and `:flags`. All other fields are ignored since they are server-controlled fields.
  """
  @spec append(batch :: t(), account :: TigerBeetlex.Account.t()) ::
          {:ok, t()} | {:error, Types.append_error()}
  def append(%AccountBatch{} = batch, %Account{} = account) do
    %AccountBatch{ref: ref} = batch

    account_binary = Account.to_batch_item(account)

    with :ok <- NifAdapter.append_account(ref, account_binary) do
      {:ok, batch}
    end
  end

  @doc """
  Appends an account to the batch, raising in case of an error.

  See `append/2` for the supported fields in the `%Account{}` struct.
  """
  @spec append!(batch :: t(), account :: TigerBeetlex.Account.t()) :: t()
  def append!(%AccountBatch{} = batch, %Account{} = account) do
    case append(batch, account) do
      {:ok, batch} -> batch
      {:error, :invalid_batch} -> raise InvalidBatchError
      {:error, :batch_full} -> raise BatchFullError
    end
  end

  @doc """
  Fetches an `%Account{}` from the batch, given its index.
  """
  @spec fetch(batch :: t(), idx :: non_neg_integer()) ::
          {:ok, TigerBeetlex.Account.t()} | {:error, Types.fetch_error()}
  def fetch(%AccountBatch{} = batch, idx) when is_number(idx) and idx >= 0 do
    with {:ok, account_binary} <- NifAdapter.fetch_account(batch.ref, idx) do
      {:ok, Account.from_binary(account_binary)}
    end
  end

  @doc """
  Fetches an `%Account{}` from the batch, given its index. Raises in case of an error.
  """
  @spec fetch!(batch :: t(), idx :: non_neg_integer()) :: TigerBeetlex.Account.t()
  def fetch!(%AccountBatch{} = batch, idx) when is_number(idx) and idx >= 0 do
    case fetch(batch, idx) do
      {:ok, account} -> account
      {:error, :invalid_batch} -> raise InvalidBatchError
      {:error, :out_of_bounds} -> raise OutOfBoundsError
    end
  end

  @doc """
  Replaces the `%Account{}` at index `idx` in the batch.
  """
  @spec replace(batch :: t(), idx :: non_neg_integer(), account :: TigerBeetlex.Account.t()) ::
          {:ok, t()} | {:error, Types.replace_error()}
  def replace(%AccountBatch{} = batch, idx, %Account{} = account)
      when is_number(idx) and idx >= 0 do
    account_binary = Account.to_batch_item(account)

    with :ok <- NifAdapter.replace_account(batch.ref, idx, account_binary) do
      {:ok, batch}
    end
  end

  @doc """
  Replaces the ID at index `idx` in the batch. Raises in case of an error.
  """
  @spec replace!(batch :: t(), idx :: non_neg_integer(), account :: TigerBeetlex.Account.t()) ::
          t()
  def replace!(%AccountBatch{} = batch, idx, %Account{} = account)
      when is_number(idx) and idx >= 0 do
    case replace(batch, idx, account) do
      {:ok, batch} -> batch
      {:error, :invalid_batch} -> raise InvalidBatchError
      {:error, :out_of_bounds} -> raise OutOfBoundsError
    end
  end
end
