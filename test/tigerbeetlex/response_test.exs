defmodule TigerBeetlex.ResponseTest do
  use ExUnit.Case, async: true

  alias TigerBeetlex.{
    Account,
    CreateAccountsResult,
    CreateTransfersResult,
    Transfer
  }

  alias TigerBeetlex.Response

  describe "decode/1 returns error" do
    for {error_status_name, error_status_value} <- Map.delete(Response.status_map(), :ok) do
      test "for status #{error_status_name}" do
        assert {:error, unquote(error_status_name)} ==
                 unquote(error_status_value)
                 |> error_response()
                 |> Response.decode()
      end
    end
  end

  describe "decode/1 returns empty list" do
    for {op_name, op_value} <- Response.operation_map() do
      test "for operation #{op_name} with empty data" do
        assert {:ok, []} =
                 unquote(op_value)
                 |> ok_response(<<>>)
                 |> Response.decode()
      end
    end
  end

  describe "decode/1" do
    test "returns list of CreateAccountsResult for create_accounts operation" do
      assert {:ok, [%CreateAccountsResult{}]} =
               :create_accounts
               |> operation()
               |> ok_response(<<0::unsigned-little-32, 1::unsigned-little-32>>)
               |> Response.decode()
    end

    test "returns list of CreateTransfersResult for create_transfers operation" do
      assert {:ok, [%CreateTransfersResult{}]} =
               :create_transfers
               |> operation()
               |> ok_response(<<0::unsigned-little-32, 1::unsigned-little-32>>)
               |> Response.decode()
    end

    test "returns list of Account for lookup_accounts operation" do
      assert {:ok, [%Account{}]} =
               :lookup_accounts
               |> operation()
               |> ok_response(:binary.copy(<<0>>, 128))
               |> Response.decode()
    end

    test "returns list of Transfer for lookup_transfers operation" do
      assert {:ok, [%Transfer{}]} =
               :lookup_transfers
               |> operation()
               |> ok_response(:binary.copy(<<0>>, 128))
               |> Response.decode()
    end
  end

  defp error_response(error_status_value) do
    {_op_name, op_value} = Response.operation_map() |> Enum.random()
    data = Enum.random(0..16) |> :rand.bytes()

    {error_status_value, op_value, data}
  end

  defp ok_response(operation, data) do
    {status(:ok), operation, data}
  end

  defp status(status_name), do: Response.status_map() |> Map.fetch!(status_name)
  defp operation(operation_name), do: Response.operation_map() |> Map.fetch!(operation_name)
end
