defmodule TigerBeetlex.Receiver do
  @moduledoc false

  use GenServer

  alias TigerBeetlex
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
  def handle_call({:create_accounts, accounts}, from, state) do
    send_request(from, :create_accounts, [state.client, accounts], state)
  end

  def handle_call({:create_transfers, transfers}, from, state) do
    send_request(from, :create_transfers, [state.client, transfers], state)
  end

  def handle_call({:lookup_accounts, ids}, from, state) do
    send_request(from, :lookup_accounts, [state.client, ids], state)
  end

  def handle_call({:lookup_transfers, ids}, from, state) do
    send_request(from, :lookup_transfers, [state.client, ids], state)
  end

  def handle_call({:get_account_balances, account_filter}, from, state) do
    send_request(from, :get_account_balances, [state.client, account_filter], state)
  end

  def handle_call({:get_account_transfers, account_filter}, from, state) do
    send_request(from, :get_account_transfers, [state.client, account_filter], state)
  end

  def handle_call({:query_accounts, query_filter}, from, state) do
    send_request(from, :query_accounts, [state.client, query_filter], state)
  end

  def handle_call({:query_transfers, query_filter}, from, state) do
    send_request(from, :query_transfers, [state.client, query_filter], state)
  end

  defp send_request(from, function, arguments, state) do
    case apply(TigerBeetlex, function, arguments) do
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
