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

  @type client_init_errors ::
          {:error, :unexpected}
          | {:error, :out_of_memory}
          | {:error, :invalid_address}
          | {:error, :address_limit_exceeded}
          | {:error, :system_resources}
          | {:error, :network_subsystem}

  @type create_account_batch_errors ::
          {:error, :out_of_memory}

  @type create_id_batch_errors ::
          {:error, :out_of_memory}

  @type create_transfer_batch_errors ::
          {:error, :out_of_memory}

  @type create_accounts_errors ::
          {:error, :invalid_client}
          | {:error, :invalid_batch}
          | {:error, :out_of_memory}
          | {:error, :too_many_requests}

  @type add_account_errors ::
          {:error, :invalid_batch}
          | {:error, :batch_full}

  @type add_id_errors ::
          {:error, :invalid_batch}
          | {:error, :batch_full}

  @type add_transfer_errors ::
          {:error, :invalid_batch}
          | {:error, :batch_full}

  @type set_function_errors ::
          {:error, :out_of_bounds}
          | {:error, :invalid_account_batch}

  @type create_transfers_errors ::
          {:error, :invalid_client}
          | {:error, :invalid_batch}
          | {:error, :out_of_memory}
          | {:error, :too_many_requests}

  @type lookup_accounts_errors ::
          {:error, :invalid_client}
          | {:error, :invalid_batch}
          | {:error, :out_of_memory}
          | {:error, :too_many_requests}

  @type lookup_transfers_errors ::
          {:error, :invalid_client}
          | {:error, :invalid_batch}
          | {:error, :out_of_memory}
          | {:error, :too_many_requests}
end
