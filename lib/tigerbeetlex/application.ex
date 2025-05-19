defmodule TigerBeetlex.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      TigerBeetlex.ID.Server
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
