defmodule TigerBeetlex.Types do
  @moduledoc """
  Common typespecs.

  This module provides common types that can be used in any part of the TigerBeetlex library.
  """

  @type client :: reference()

  @type account_batch :: reference()

  @type transfer_batch :: reference()

  @type id_batch :: reference()

  @type uint128 :: <<_::128>>

  @type client_init_error ::
          :unexpected
          | :out_of_memory
          | :invalid_address
          | :address_limit_exceeded
          | :system_resources
          | :network_subsystem

  @type create_account_batch_error :: :out_of_memory

  @type create_id_batch_error ::
          :out_of_memory

  @type create_transfer_batch_error ::
          :out_of_memory

  @type create_accounts_error ::
          :invalid_client
          | :invalid_batch
          | :out_of_memory
          | :too_many_requests

  @type add_account_error ::
          :invalid_batch
          | :batch_full

  @type add_id_error ::
          :invalid_batch
          | :batch_full

  @type add_transfer_error ::
          :invalid_batch
          | :batch_full

  @type set_function_error ::
          :out_of_bounds
          | :invalid_account_batch

  @type create_transfers_error ::
          :invalid_client
          | :invalid_batch
          | :out_of_memory
          | :too_many_requests

  @type lookup_accounts_error ::
          :invalid_client
          | :invalid_batch
          | :out_of_memory
          | :too_many_requests

  @type lookup_transfers_error ::
          :invalid_client
          | :invalid_batch
          | :out_of_memory
          | :too_many_requests

  @type tigerbeetlex_connection_start_option ::
          {:cluster_id, non_neg_integer()}
          | {:addresses, [String.t()]}
          | {:concurrency_max, [pos_integer()]}

  @type partition_supervisor_start_option :: {atom(), any()}

  @type start_option ::
          tigerbeetlex_connection_start_option()
          | partition_supervisor_start_option()

  @type start_options :: [start_option()]
end
