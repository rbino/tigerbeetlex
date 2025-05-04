defmodule TigerBeetlex.Receiver do
  @moduledoc false

  use GenServer

  alias TigerBeetlex.Client
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
  def handle_call({operation, payload}, from, state) do
    case apply(Client, operation, [state.client, payload]) do
      {:ok, ref} ->
        {:noreply, %{state | pending_requests: Map.put(state.pending_requests, ref, from)}}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_info({:tigerbeetlex_response, ref, response}, state) do
    {from, new_pending_requests} = Map.pop!(state.pending_requests, ref)
    response = Response.decode(response)
    GenServer.reply(from, response)
    {:noreply, %{state | pending_requests: new_pending_requests}}
  end
end
