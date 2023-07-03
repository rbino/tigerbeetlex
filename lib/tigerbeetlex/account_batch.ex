defmodule TigerBeetlex.AccountBatch do
  use TypedStruct

  typedstruct do
    field :ref, reference(), enforce: true
  end

  alias TigerBeetlex.Account.Flags
  alias TigerBeetlex.AccountBatch
  alias TigerBeetlex.NifAdapter
  alias TigerBeetlex.Types

  @spec new(capacity :: non_neg_integer()) ::
          {:ok, t()} | Types.create_account_batch_errors()
  def new(capacity) when is_integer(capacity) and capacity > 0 do
    with {:ok, ref} <- NifAdapter.create_account_batch(capacity) do
      {:ok, %AccountBatch{ref: ref}}
    end
  end

  @spec add_account(batch :: t(), opts :: keyword()) ::
          {:ok, t()} | Types.add_account_errors() | Types.set_function_errors()
  def add_account(%AccountBatch{} = batch, opts) do
    %AccountBatch{ref: ref} = batch

    with {:ok, new_length} <- NifAdapter.add_account(ref),
         :ok <- set_fields(ref, new_length - 1, opts) do
      {:ok, batch}
    end
  end

  defp set_fields(ref, idx, opts) do
    Enum.reduce_while(opts, :ok, fn {field, value}, _acc ->
      case set_field(ref, idx, field, value) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp set_field(ref, idx, field, value) do
    set_fun(field).(ref, idx, value)
  end

  defp set_fun(:id), do: &NifAdapter.set_account_id/3
  defp set_fun(:user_data), do: &NifAdapter.set_account_user_data/3
  defp set_fun(:ledger), do: &NifAdapter.set_account_ledger/3
  defp set_fun(:code), do: &NifAdapter.set_account_code/3

  defp set_fun(:flags) do
    fn ref, idx, value ->
      flags_u16 = Flags.to_u16!(value)
      NifAdapter.set_account_flags(ref, idx, flags_u16)
    end
  end
end
