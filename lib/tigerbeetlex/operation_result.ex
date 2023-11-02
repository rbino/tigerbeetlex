defmodule TigerBeetlex.OperationResult do
  @moduledoc false

  # Ensure we recompile this module whe tigerbeetle.zig changes
  @external_resource "src/tigerbeetle/src/tigerbeetle.zig"

  def extract_result_map(enum_name) do
    File.cwd!()
    |> Path.join("src/tigerbeetle/src/tigerbeetle.zig")
    |> File.read!()
    |> Zig.Parser.parse()
    |> Map.fetch!(:code)
    |> Enum.find_value(fn
      %Zig.Parser.Const{name: ^enum_name, value: %Zig.Parser.Enum{fields: fields}} ->
        fields

      _ ->
        false
    end)
    |> Enum.into(%{}, fn {error_name, {:integer, value}} ->
      {value, error_name}
    end)
  end

  def result_map_to_typespec(result_map) do
    Map.values(result_map)
    |> Enum.reduce(&{:|, [], [&1, &2]})
  end
end
