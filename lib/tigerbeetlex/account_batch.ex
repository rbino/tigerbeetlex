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

  alias TigerBeetlex.Account.Flags
  alias TigerBeetlex.AccountBatch
  alias TigerBeetlex.NifAdapter
  alias TigerBeetlex.Types

  @doc """
  Creates a new account batch with the specified capacity.

  The capacity is the maximum number of accounts that can be added to the batch.
  """
  @spec new(capacity :: non_neg_integer()) ::
          {:ok, t()} | Types.create_account_batch_errors()
  def new(capacity) when is_integer(capacity) and capacity > 0 do
    with {:ok, ref} <- NifAdapter.create_account_batch(capacity) do
      {:ok, %AccountBatch{ref: ref}}
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
          | Types.add_account_errors()
          | Types.set_function_errors()
          | {:error, NimbleOptions.ValidationError.t()}
  def add_account(%AccountBatch{} = batch, opts) do
    %AccountBatch{ref: ref} = batch

    with {:ok, new_length} <- NifAdapter.add_account(ref),
         :ok <- set_fields(ref, new_length - 1, opts) do
      {:ok, batch}
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
