defmodule TigerBeetlex.Receiver do
  use GenServer

  alias TigerBeetlex.Processless, as: Client
  alias TigerBeetlex.Response

  defstruct [
    :client,
    :pending_requests
  ]

  def start_link(client_ref) do
    GenServer.start_link(__MODULE__, client_ref)
  end

  @impl true
  def init(client) do
    {:ok, %{client: client, pending_requests: %{}}}
  end

  @impl true
  def handle_call({:create_accounts, account_batch}, from, state) do
    send_request(from, :create_accounts, [state.client, account_batch], state)
  end

  def handle_call({:create_transfers, transfer_batch}, from, state) do
    send_request(from, :create_transfers, [state.client, transfer_batch], state)
  end

  def handle_call({:lookup_accounts, id_batch}, from, state) do
    send_request(from, :lookup_accounts, [state.client, id_batch], state)
  end

  def handle_call({:lookup_transfers, id_batch}, from, state) do
    send_request(from, :lookup_transfers, [state.client, id_batch], state)
  end

  defp send_request(from, function, arguments, state) do
    case apply(Client, function, arguments) do
      {:ok, ref} ->
        {:noreply, %{state | pending_requests: Map.put(state.pending_requests, ref, from)}}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_info({:tigerbeetlex_response, ref, response}, state) do
    {from, new_pending_requests} = Map.pop!(state.pending_requests, ref)
    response = Response.to_stream(response)
    GenServer.reply(from, response)
    {:noreply, %{state | pending_requests: new_pending_requests}}
  end
end
