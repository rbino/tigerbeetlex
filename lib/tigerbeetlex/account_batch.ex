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
  alias TigerBeetlex.NifAdapter
  alias TigerBeetlex.Types

  @doc """
  Creates a new account batch with the specified capacity.

  The capacity is the maximum number of accounts that can be added to the batch.
  """
  @spec new(capacity :: non_neg_integer()) ::
          {:ok, t()} | {:error, Types.create_account_batch_error()}
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
      {:error, reason} -> raise RuntimeError, inspect(reason)
    end
  end

  @doc """
  Appends an account to the batch.

  The `%Account{}` struct must contain at least `:id`, `:ledger` and `:code`, and may also contain
  `:user_data` and `:flags`. All other fields are ignored since they are server-controlled fields.
  """
  @spec append(batch :: t(), account :: TigerBeetlex.Account.t()) ::
          {:ok, t()} | {:error, Types.append_account_error()}
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
      {:error, reason} -> raise RuntimeError, inspect(reason)
    end
  end
end
