defmodule TigerBeetlex.ResponseTest do
  use ExUnit.Case

  alias TigerBeetlex.{
    Account,
    CreateAccountError,
    CreateTransferError,
    Transfer
  }

  alias TigerBeetlex.Response

  @status TigerBeetlex.PacketStatus.extract_packet_status_map()

  @operation [
    create_accounts: 128,
    create_transfers: 129,
    lookup_accounts: 130,
    lookup_transfers: 131
  ]

  describe "to_stream/1 returns error" do
    for {error_status_name, _error_status_value} <- Map.delete(@status, :ok) do
      test "for status #{error_status_name}" do
        assert {:error, unquote(error_status_name)} ==
                 unquote(error_status_name)
                 |> error_response()
                 |> Response.to_stream()
      end
    end
  end

  describe "to_stream/1 returns empty stream" do
    for {op_name, op_value} <- @operation do
      test "for operation #{op_name} with empty data" do
        assert {:ok, stream} =
                 unquote(op_value)
                 |> ok_response(<<>>)
                 |> Response.to_stream()

        assert Enum.to_list(stream) == []
      end
    end
  end

  describe "to_stream/1" do
    test "returns stream of CreateAccountError for create_accounts operation" do
      assert {:ok, stream} =
               @operation[:create_accounts]
               |> ok_response(<<0::unsigned-little-32, 1::unsigned-little-32>>)
               |> Response.to_stream()

      assert [%CreateAccountError{}] = Enum.to_list(stream)
    end

    test "returns stream of CreateTransferError for create_transfers operation" do
      assert {:ok, stream} =
               @operation[:create_transfers]
               |> ok_response(<<0::unsigned-little-32, 1::unsigned-little-32>>)
               |> Response.to_stream()

      assert [%CreateTransferError{}] = Enum.to_list(stream)
    end

    test "returns stream of Account for lookup_accounts operation" do
      assert {:ok, stream} =
               @operation[:lookup_accounts]
               |> ok_response(:binary.copy(<<0>>, 128))
               |> Response.to_stream()

      assert [%Account{}] = Enum.to_list(stream)
    end

    test "returns stream of Transfer for lookup_transfers operation" do
      assert {:ok, stream} =
               @operation[:lookup_transfers]
               |> ok_response(:binary.copy(<<0>>, 128))
               |> Response.to_stream()

      assert [%Transfer{}] = Enum.to_list(stream)
    end
  end

  defp error_response(error_status_name) do
    {_op_name, op_value} = Enum.random(@operation)
    data = Enum.random(0..16) |> :rand.bytes()

    {@status[error_status_name], op_value, data}
  end

  defp ok_response(operation, data) do
    {@status[:ok], operation, data}
  end
end
