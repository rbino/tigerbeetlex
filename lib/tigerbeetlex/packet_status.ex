defmodule TigerBeetlex.PacketStatus do
  @moduledoc false

  @src_path "src/tigerbeetle/src/clients/c/tb_client/packet.zig"
  # Ensure we recompile this module whe tigerbeetle.zig changes
  @external_resource @src_path

  def extract_packet_status_map do
    File.cwd!()
    |> Path.join(@src_path)
    |> File.read!()
    |> Zig.Parser.parse()
    |> Map.fetch!(:code)
    |> Enum.find_value(fn
      %Zig.Parser.Const{name: :Packet, value: %Zig.Parser.Struct{decls: decls}} ->
        decls

      _ ->
        false
    end)
    |> Enum.find_value(fn
      %Zig.Parser.Const{name: :Status, value: %Zig.Parser.Enum{fields: fields}} ->
        fields

      _ ->
        false
    end)
    |> Enum.with_index()
    |> Enum.into(%{})
  end

  def result_map_to_typespec(status_map) do
    Map.values(status_map)
    |> Enum.reduce(&{:|, [], [&1, &2]})
  end
end
