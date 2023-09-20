defmodule TigerBeetlex.OperationResult do
  @moduledoc false

  def extract_result_map(operation_name) do
    enum_name = "#{operation_name}_RESULT"

    File.cwd!()
    |> Path.join("src/tigerbeetle/src/clients/c/tb_client.h")
    |> File.stream!()
    |> Stream.drop_while(&(not (&1 =~ "typedef enum #{enum_name}")))
    |> Stream.drop(1)
    |> Stream.take_while(&(not (&1 =~ enum_name)))
    |> Stream.map(fn enum_line ->
      [error_name, value] =
        enum_line
        |> String.trim()
        |> String.trim_trailing(",")
        |> String.replace_prefix("#{operation_name}_", "")
        |> String.downcase()
        |> String.split(" = ")

      {int_value, ""} = Integer.parse(value)

      {int_value, String.to_atom(error_name)}
    end)
    |> Enum.into(%{})
  end

  def result_map_to_typespec(result_map) do
    Map.values(result_map)
    |> Enum.reduce(&{:|, [], [&1, &2]})
  end
end
