defmodule TigerBeetlex.IDBatch do
  use TypedStruct

  typedstruct do
    field :ref, reference(), enforce: true
  end

  alias TigerBeetlex.IDBatch
  alias TigerBeetlex.NifAdapter
  alias TigerBeetlex.Types

  @spec new(capacity :: non_neg_integer()) ::
          {:ok, t()} | Types.create_id_batch_errors()
  def new(capacity) when is_integer(capacity) and capacity > 0 do
    with {:ok, ref} <- NifAdapter.create_id_batch(capacity) do
      {:ok, %IDBatch{ref: ref}}
    end
  end

  @spec add_id(batch :: t(), id :: Types.uint128()) ::
          {:ok, t()} | Types.add_id_errors()
  def add_id(%IDBatch{} = batch, id) do
    with :ok <- NifAdapter.add_id(batch.ref, id) do
      {:ok, batch}
    end
  end
end
