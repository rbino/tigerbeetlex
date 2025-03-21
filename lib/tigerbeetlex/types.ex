defmodule TigerBeetlex.Types do
  @moduledoc """
  Common typespecs.

  This module provides common types that can be used in any part of the TigerBeetlex library.
  """

  @type client :: reference()

  @type account_binary :: <<_::1024>>

  @type account_filter_binary :: <<_::1024>>

  @type transfer_binary :: <<_::1024>>

  @type id_128 :: <<_::128>>

  @type user_data_128 :: <<_::128>>

  @type user_data_64 :: <<_::64>>

  @type user_data_32 :: <<_::32>>

  @type client_init_error ::
          :unexpected
          | :out_of_memory
          | :invalid_address
          | :address_limit_exceeded
          | :system_resources
          | :network_subsystem

  @type request_error ::
          :invalid_client_resource
          | :too_many_requests
          | :shutdown
          | :out_of_memory
          | :client_closed

  @type tigerbeetlex_connection_start_option ::
          {:cluster_id, non_neg_integer()}
          | {:addresses, [String.t()]}

  @type partition_supervisor_start_option :: {atom(), any()}

  @type start_option ::
          tigerbeetlex_connection_start_option()
          | partition_supervisor_start_option()

  @type start_options :: [start_option()]
end
