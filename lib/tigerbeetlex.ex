defmodule TigerBeetlex do
  @moduledoc false

  alias TigerBeetlex.Client
  alias TigerBeetlex.Operation

  @deprecated "Use TigerBeetlex.Client.new/2 instead"
  def connect(cluster_id, addresses), do: Client.new(cluster_id, addresses)

  for operation <- Operation.available_operations() do
    @deprecated "Use TigerBeetlex.Client.#{operation}/2 instead"
    def unquote(operation)(client, struct_payload) do
      apply(Client, unquote(operation), [client, struct_payload])
    end
  end

  @deprecated "Use TigerBeetlex.Client.receive_and_decode/1 instead"
  def receive_and_decode(ref), do: Client.receive_and_decode(ref)
end
