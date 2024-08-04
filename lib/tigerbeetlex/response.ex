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
    PacketStatus,
    Transfer
  }

  @status_map PacketStatus.extract_packet_status_map()
  @type status :: unquote(PacketStatus.result_map_to_typespec(@status_map))

  @type operation_create_accounts :: 129
  @type operation_create_transfers :: 130
  @type operation_lookup_accounts :: 131
  @type operation_lookup_transfers :: 132

  @type operation ::
          operation_create_accounts()
          | operation_create_transfers()
          | operation_lookup_accounts()
          | operation_lookup_transfers()

  @operation_create_accounts 129
  @operation_create_transfers 130
  @operation_lookup_accounts 131
  @operation_lookup_transfers 132

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
  for {status, status_integer} <- @status_map do
    if status == :ok do
      def to_stream({unquote(status_integer), operation, data}) do
        unfold_fun = unfold_function(operation)

        {:ok, Stream.unfold(data, unfold_fun)}
      end
    else
      def to_stream({unquote(status_integer), _operation, _data}) do
        {:error, unquote(status)}
      end
    end
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
