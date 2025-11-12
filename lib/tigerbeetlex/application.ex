defmodule TigerBeetlex.Application do
  @moduledoc false

  use Application

  alias TigerBeetlex.ID

  def start(_type, _args) do
    ID.initialize_atomics()

    Supervisor.start_link([], strategy: :one_for_one)
  end
end
