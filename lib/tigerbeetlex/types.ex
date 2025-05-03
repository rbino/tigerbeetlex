defmodule TigerBeetlex.Types do
  @moduledoc """
  Common typespecs.

  This module provides common types that can be used in any part of the TigerBeetlex library.
  """

  @type client :: reference()

  @type id_128 :: <<_::128>>

  @type init_client_error ::
          :unexpected
          | :out_of_memory
          | :invalid_address
          | :address_limit_exceeded
          | :system_resources
          | :network_subsystem

  @type request_error ::
          :client_closed
          | :out_of_memory

  @type tigerbeetlex_connection_start_option ::
          {:cluster_id, non_neg_integer()}
          | {:addresses, [String.t()]}

  @type partition_supervisor_start_option :: {atom(), any()}

  @type start_option ::
          tigerbeetlex_connection_start_option()
          | partition_supervisor_start_option()

  @type start_options :: [start_option()]
end
