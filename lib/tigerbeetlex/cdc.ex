defmodule TigerBeetlex.CDC do
  @moduledoc false

  alias TigerBeetlex.ID

  # Utility functions used across CDC structs
  def cast_struct!(struct_module, field_and_cast_fun_list, params) do
    field_and_cast_fun_list
    |> Enum.map(fn {key, cast_fun} ->
      cast_value =
        params
        |> Map.fetch!(to_string(key))
        |> cast_fun.()

      {key, cast_value}
    end)
    |> then(&struct!(struct_module, &1))
  end

  def cast_int!(term) when is_integer(term), do: term

  def cast_int!(term) when is_binary(term) do
    String.to_integer(term)
  end

  def cast_id!(term) do
    term
    |> cast_int!()
    |> ID.from_int()
  end
end
