defmodule TigerBeetlex.Types do
  @type client :: reference()

  @type account_batch :: reference()

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

  @type add_account_errors ::
          {:error, :invalid_account_batch}
          | {:error, :account_batch_full}

  @type set_function_errors ::
          {:error, :out_of_bounds}
          | {:error, :invalid_account_batch}
end
