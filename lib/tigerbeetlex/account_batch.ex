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
  alias TigerBeetlex.Account.Flags
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

  @add_account_opts_schema [
    id: [
      required: true,
      type: :binary,
      type_doc: "a 128-bit binary ID",
      doc: "The ID of the account."
    ],
    ledger: [
      required: true,
      type: :pos_integer,
      doc: "The ledger of the account."
    ],
    code: [
      required: true,
      type: :pos_integer,
      doc: "The code of the account."
    ],
    user_data: [
      type: :binary,
      type_doc: "a 128-bit binary ID",
      doc: "An ID used to reference external user data."
    ],
    flags: [
      type: {:struct, Flags},
      doc: "The flags for the account."
    ]
  ]

  @doc """
  Adds an account to the batch. The fields of the account are passed as a keyword list.

  ## Fields

  These are the supported fields that can be passed in `opts` for the account

  #{NimbleOptions.docs(@add_account_opts_schema)}

  See [TigerBeetle docs](https://docs.tigerbeetle.com/reference/accounts) for the meaning of the
  fields.
  """
  @spec add_account(batch :: t(), opts :: keyword()) ::
          {:ok, t()}
          | {:error, Types.add_account_error() | Types.set_function_error()}
  def add_account(%AccountBatch{} = batch, opts) do
    %AccountBatch{ref: ref} = batch

    with {:ok, new_length} <- NifAdapter.add_account(ref),
         :ok <- set_fields(ref, new_length - 1, opts) do
      {:ok, batch}
    end
  end

  @doc """
  Adds an account to the batch, raising in case of an error. The fields of the account are passed
  as a keyword list.

  See `add_account/2` for the supported options.
  """
  @spec add_account!(batch :: t(), opts :: keyword()) :: t()
  def add_account!(%AccountBatch{} = batch, opts) do
    case add_account(batch, opts) do
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

  defp set_fields(ref, idx, opts) do
    Enum.reduce_while(opts, :ok, fn {field, value}, _acc ->
      case set_field(ref, idx, field, value) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp set_field(ref, idx, field, value) do
    set_fun(field).(ref, idx, value)
  end

  defp set_fun(:id), do: &NifAdapter.set_account_id/3
  defp set_fun(:user_data), do: &NifAdapter.set_account_user_data/3
  defp set_fun(:ledger), do: &NifAdapter.set_account_ledger/3
  defp set_fun(:code), do: &NifAdapter.set_account_code/3

  defp set_fun(:flags) do
    fn ref, idx, value ->
      flags_u16 = Flags.to_u16!(value)
      NifAdapter.set_account_flags(ref, idx, flags_u16)
    end
  end
end
