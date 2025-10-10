defmodule TigerBeetlex.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    atomics = :atomics.new(2, signed: false)
    :persistent_term.put(:tigerbeetlex_id_atomics, atomics)
    Supervisor.start_link([], strategy: :one_for_one)
  end
end
