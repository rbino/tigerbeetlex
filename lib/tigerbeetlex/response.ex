defmodule TigerBeetlex.Response do
  @moduledoc """
  NIF Response parsing.

  This module is responsible to convert a response received from the TigerBeetle NIF to either
  an error or a stream.
  """

  use TypedStruct

  alias TigerBeetlex.{
    Account,
    CreateAccountError,
    CreateTransferError,
    Transfer
  }

  @type status_ok :: 0
  @type status_too_much_data :: 1
  @type status_invalid_operation :: 2
  @type status_invalid_data_size :: 3

  @type status ::
          status_ok()
          | status_too_much_data()
          | status_invalid_operation()
          | status_invalid_data_size()

  @type operation_create_accounts :: 128
  @type operation_create_transfers :: 129
  @type operation_lookup_accounts :: 130
  @type operation_lookup_transfers :: 131

  @type operation ::
          operation_create_accounts()
          | operation_create_transfers()
          | operation_lookup_accounts()
          | operation_lookup_transfers()

  # Taken from packet.zig
  @status_ok 0
  @status_too_much_data 1
  @status_invalid_operation 2
  @status_invalid_data_size 3
  @operation_create_accounts 128
  @operation_create_transfers 129
  @operation_lookup_accounts 130
  @operation_lookup_transfers 131

  typedstruct opaque: true do
    field :operation, non_neg_integer()
    field :data, binary()
  end

  @doc """
  Converts a NIF message response to a stream.

  If the response contains an error, `{:error, reason}` is returned.

  If successful, it returns `{:ok, stream}`. The type of the items of the stream depend on the
  operation.

  - `operation_create_accounts`: a stream of `%TigerBeetlex.CreateAccountError{}`.
  - `operation_create_transfer`: a stream of `%TigerBeetlex.CreateTransferError{}`.
  - `operation_lookup_accounts`: a stream of `%TigerBeetlex.Account{}`.
  - `operation_lookup_transfers`: a stream of `%TigerBeetlex.Transfer{}`.
  """
  @spec to_stream(response :: {status :: status(), operation :: operation(), data :: binary()}) ::
          {:ok, Enumerable.t()} | {:error, reason :: atom()}
  def to_stream({@status_ok, operation, data}) do
    unfold_fun = unfold_function(operation)

    {:ok, Stream.unfold(data, unfold_fun)}
  end

  def to_stream({@status_too_much_data, _operation, _data}) do
    {:error, :too_much_data}
  end

  def to_stream({@status_invalid_operation, _operation, _data}) do
    {:error, :invalid_operation}
  end

  def to_stream({@status_invalid_data_size, _operation, _data}) do
    {:error, :invalid_data_size}
  end

  defp unfold_function(@operation_create_accounts) do
    fn
      <<>> -> nil
      <<error::binary-size(8), rest::binary>> -> {CreateAccountError.from_binary(error), rest}
    end
  end

  defp unfold_function(@operation_create_transfers) do
    fn
      <<>> -> nil
      <<error::binary-size(8), rest::binary>> -> {CreateTransferError.from_binary(error), rest}
    end
  end

  defp unfold_function(@operation_lookup_accounts) do
    fn
      <<>> -> nil
      <<account::binary-size(128), rest::binary>> -> {Account.from_binary(account), rest}
    end
  end

  defp unfold_function(@operation_lookup_transfers) do
    fn
      <<>> -> nil
      <<transfer::binary-size(128), rest::binary>> -> {Transfer.from_binary(transfer), rest}
    end
  end
end
