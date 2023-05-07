defmodule TigerBeetlex.Processless.Response do
  use TypedStruct

  alias TigerBeetlex.{
    Account,
    CreateAccountError,
    CreateTransferError,
    Transfer
  }

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
      <<error::binary-size(8), rest::binary>> -> {CreateAccountError.from_binary!(error), rest}
    end
  end

  defp unfold_function(@operation_create_transfers) do
    fn
      <<>> -> nil
      <<error::binary-size(8), rest::binary>> -> {CreateTransferError.from_binary!(error), rest}
    end
  end

  defp unfold_function(@operation_lookup_accounts) do
    fn
      <<>> -> nil
      <<account::binary-size(128), rest::binary>> -> {Account.from_binary!(account), rest}
    end
  end

  defp unfold_function(@operation_lookup_transfers) do
    fn
      <<>> -> nil
      <<transfer::binary-size(128), rest::binary>> -> {Transfer.from_binary!(transfer), rest}
    end
  end
end
