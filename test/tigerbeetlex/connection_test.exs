defmodule TigerBeetlex.ConnectionTest do
  use ExUnit.Case, async: true

  alias TigerBeetlex.Connection
  alias TigerBeetlex.ID

  describe "start_link/1" do
    setup do
      valid_opts = [
        name: :tb_connection_test,
        cluster_id: ID.from_int(0),
        addresses: ["3000"]
      ]

      {:ok, valid_opts: valid_opts}
    end

    test "raises with invalid cluster_id", %{valid_opts: opts} do
      opts = Keyword.put(opts, :cluster_id, 0)

      assert_raise NimbleOptions.ValidationError, fn ->
        Connection.start_link(opts)
      end
    end

    test "raises with invalid addresses", %{valid_opts: opts} do
      opts = Keyword.put(opts, :addresses, 42)

      assert_raise NimbleOptions.ValidationError, fn ->
        Connection.start_link(opts)
      end
    end

    test "raises if :name is nt passoed", %{valid_opts: opts} do
      opts = Keyword.delete(opts, :name)

      assert_raise NimbleOptions.ValidationError, fn ->
        Connection.start_link(opts)
      end
    end

    test "returns {:ok, pid} with valid options", %{valid_opts: opts} do
      {:ok, pid} = start_supervised({Connection, opts})
      assert Process.alive?(pid)
    end

    test "relays additional options to PartitionSupervisor", %{valid_opts: opts} do
      opts = opts ++ [partitions: 3]

      _pid = start_supervised!({Connection, opts})
      assert Process.whereis(:tb_connection_test) != nil
      assert PartitionSupervisor.partitions(:tb_connection_test) == 3
    end
  end
end
