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
  alias TigerBeetlex.Transfer.Flags
  alias TigerBeetlex.TransferBatch
  alias TigerBeetlex.NifAdapter
  alias TigerBeetlex.Types

  @doc """
  Creates a new transfer batch with the specified capacity.

  The capacity is the maximum number of transfers that can be added to the batch.
  """
  @spec new(capacity :: non_neg_integer()) ::
          {:ok, t()} | {:error, Types.create_transfer_batch_error()}
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
      {:error, reason} -> raise RuntimeError, inspect(reason)
    end
  end

  @add_transfer_opts_schema [
    id: [
      required: true,
      type: :binary,
      type_doc: "a 128-bit binary ID",
      doc: "The ID of the transfer."
    ],
    debit_account_id: [
      type: :binary,
      type_doc: "a 128-bit binary ID",
      doc: "The ID of the debit account."
    ],
    credit_account_id: [
      type: :binary,
      type_doc: "a 128-bit binary ID",
      doc: "The ID of the credit account."
    ],
    user_data: [
      type: :binary,
      type_doc: "a 128-bit binary ID",
      doc: "An ID used to reference external user data."
    ],
    pending_id: [
      type: :binary,
      type_doc: "a 128-bit binary ID",
      doc: "The ID of the pending transfer to be posted or voided."
    ],
    timeout: [
      type: :non_neg_integer,
      doc: "The timeout for the transfer."
    ],
    ledger: [
      type: :non_neg_integer,
      doc: "The ledger of the transfer."
    ],
    code: [
      type: :non_neg_integer,
      doc: "The code of the transfer."
    ],
    flags: [
      type: {:struct, Flags},
      doc: "The flags for the transfer."
    ],
    amount: [
      type: :non_neg_integer,
      doc: "The amount of the transfer."
    ]
  ]

  @doc """
  Adds a transfer to the batch. The fields of the transfer are passed as a keyword list.

  ## Fields

  These are the supported fields that can be passed in `opts` for the transfer

  #{NimbleOptions.docs(@add_transfer_opts_schema)}

  See [TigerBeetle docs](https://docs.tigerbeetle.com/reference/transfers) for the meaning of the
  fields.
  """
  @spec add_transfer(batch :: t(), opts :: keyword()) ::
          {:ok, t()}
          | {:error, Types.add_transfer_error() | Types.set_function_error()}
  def add_transfer(%TransferBatch{} = batch, opts) do
    %TransferBatch{ref: ref} = batch

    with {:ok, new_length} <- NifAdapter.add_transfer(ref),
         :ok <- set_fields(ref, new_length - 1, opts) do
      {:ok, batch}
    end
  end

  @doc """
  Adds a transfer to the batch, raising in case of an error. The fields of the transfer are passed
  as a keyword list.

  See `add_transfer/2` for the supported options.
  """
  @spec add_transfer!(batch :: t(), opts :: keyword()) :: t()
  def add_transfer!(%TransferBatch{} = batch, opts) do
    case add_transfer(batch, opts) do
      {:ok, batch} -> batch
      {:error, reason} -> raise RuntimeError, inspect(reason)
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
          {:ok, t()} | {:error, Types.append_transfer_error()}
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

  defp set_fun(:id), do: &NifAdapter.set_transfer_id/3
  defp set_fun(:debit_account_id), do: &NifAdapter.set_transfer_debit_account_id/3
  defp set_fun(:credit_account_id), do: &NifAdapter.set_transfer_credit_account_id/3
  defp set_fun(:user_data), do: &NifAdapter.set_transfer_user_data/3
  defp set_fun(:pending_id), do: &NifAdapter.set_transfer_pending_id/3
  defp set_fun(:timeout), do: &NifAdapter.set_transfer_timeout/3
  defp set_fun(:ledger), do: &NifAdapter.set_transfer_ledger/3
  defp set_fun(:code), do: &NifAdapter.set_transfer_code/3

  defp set_fun(:flags) do
    fn ref, idx, value ->
      flags_u16 = Flags.to_u16!(value)
      NifAdapter.set_transfer_flags(ref, idx, flags_u16)
    end
  end

  defp set_fun(:amount), do: &NifAdapter.set_transfer_amount/3
end
