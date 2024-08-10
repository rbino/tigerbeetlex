const std = @import("std");
const assert = std.debug.assert;

const vsr = @import("vsr");
const tb = vsr.tigerbeetle;

const auto_generated_code_notice =
    \\#######################################################
    \\# This file was auto-generated by elixir_bindings.zig #
    \\#              Do not manually modify.                #
    \\#######################################################
    \\
;

const TypeMapping = struct {
    file_name: []const u8,
    module_name: []const u8,
    hidden_fields: []const []const u8 = &.{},
    docs_link: ?[]const u8 = null,

    pub fn hidden(comptime self: @This(), name: []const u8) bool {
        inline for (self.hidden_fields) |field| {
            if (std.mem.eql(u8, field, name)) {
                return true;
            }
        } else return false;
    }
};

const type_mappings = .{
    .{ tb.AccountFlags, TypeMapping{
        .file_name = "account_flags",
        .module_name = "AccountFlags",
        .hidden_fields = &.{"padding"},
        .docs_link = "reference/account#flags",
    } },
    .{ tb.TransferFlags, TypeMapping{
        .file_name = "transfer_flags",
        .module_name = "TransferFlags",
        .hidden_fields = &.{"padding"},
        .docs_link = "reference/transfer#flags",
    } },
    .{ tb.AccountFilterFlags, TypeMapping{
        .file_name = "account_filter_flags",
        .module_name = "AccountFilterFlags",
        .hidden_fields = &.{"padding"},
        .docs_link = "reference/account-filter#flags",
    } },
    .{ tb.QueryFilterFlags, TypeMapping{
        .file_name = "query_filter_flags",
        .module_name = "QueryFilterFlags",
        .hidden_fields = &.{"padding"},
        .docs_link = "reference/query-filter#flags",
    } },
    .{ tb.Account, TypeMapping{
        .file_name = "account",
        .module_name = "Account",
        .docs_link = "reference/account#",
    } },
    .{ tb.AccountBalance, TypeMapping{
        .file_name = "account_balance",
        .module_name = "AccountBalance",
        .hidden_fields = &.{"reserved"},
        .docs_link = "reference/account-balances#",
    } },
    .{ tb.Transfer, TypeMapping{
        .file_name = "transfer",
        .module_name = "Transfer",
        .docs_link = "reference/transfer#",
    } },
    .{ tb.QueryFilter, TypeMapping{
        .file_name = "query_filter",
        .module_name = "QueryFilter",
        .hidden_fields = &.{"reserved"},
        .docs_link = "reference/query-filter#",
    } },
    .{ tb.AccountFilter, TypeMapping{
        .file_name = "account_filter",
        .module_name = "AccountFilter",
        .hidden_fields = &.{"reserved"},
        .docs_link = "reference/account-filter#",
    } },
};

fn emit_flags(
    buffer: *std.ArrayList(u8),
    comptime type_info: anytype,
    comptime mapping: TypeMapping,
) !void {
    assert(type_info.layout == .@"packed");

    try buffer.writer().print(
        \\{[notice]s}
        \\defmodule TigerBeetlex.{[module_name]s} do
        \\  import Bitwise
        \\
        \\
    , .{
        .notice = auto_generated_code_notice,
        .module_name = mapping.module_name,
    });

    try emit_docs(buffer, mapping, null);

    inline for (type_info.fields, 0..) |field, i| {
        if (comptime mapping.hidden(field.name)) continue;

        try buffer.writer().print("\n\n", .{});

        try emit_docs(buffer, mapping, field.name);

        // TODO: we're assuming the initial value of packet structs is always 0
        // Is this a reasonable assumption?
        try buffer.writer().print(
            \\
            \\  def {[function_name]s}(current \\ 0) do
            \\    current ||| 1 <<< {[shift]d}
            \\  end
        , .{
            .function_name = field.name,
            .shift = i,
        });
    }

    try buffer.writer().print(
        \\
        \\end
        \\
    , .{});
}

fn emit_struct(
    buffer: *std.ArrayList(u8),
    comptime type_info: anytype,
    comptime mapping: TypeMapping,
) !void {
    assert(type_info.layout == .@"extern");

    try buffer.writer().print(
        \\{[notice]s}
        \\defmodule TigerBeetlex.{[module_name]s} do
        \\
    , .{
        .notice = auto_generated_code_notice,
        .module_name = mapping.module_name,
    });

    try emit_docs(buffer, mapping, null);

    try buffer.writer().print(
        \\
        \\  defstruct [
    , .{});

    inline for (type_info.fields, 0..) |field, i| {
        if (comptime mapping.hidden(field.name)) continue;

        const leading_separator = if (i == 0) "\n" else ",\n";

        try buffer.writer().print("{[leading_separator]s}    :{[field]s}", .{
            .leading_separator = leading_separator,
            .field = field.name,
        });
    }

    try buffer.writer().print(
        \\
        \\  ]
        \\end
        \\
    , .{});
}

fn emit_docs(
    buffer: anytype,
    comptime mapping: TypeMapping,
    comptime field: ?[]const u8,
) !void {
    if (mapping.docs_link) |docs_link| {
        try buffer.writer().print(
            \\  @{[doc_type]s} """
            \\  See [{[name]s}](https://docs.tigerbeetle.com/{[docs_link]s}{[field]s}).
            \\  """
        , .{
            .doc_type = if (field == null) "moduledoc" else "doc",
            .name = field orelse mapping.module_name,
            .docs_link = docs_link,
            .field = field orelse "",
        });
    }
}

pub fn generate_bindings(
    comptime ZigType: type,
    comptime mapping: TypeMapping,
    buffer: *std.ArrayList(u8),
) !void {
    @setEvalBranchQuota(100_000);

    switch (@typeInfo(ZigType)) {
        .Struct => |info| switch (info.layout) {
            .auto => @compileError(
                "Only packed or extern structs are supported: " ++ @typeName(ZigType),
            ),
            .@"packed" => try emit_flags(buffer, info, mapping),
            .@"extern" => try emit_struct(buffer, info, mapping),
        },
        .Enum => @panic("TODO"),
        else => @compileError("Type cannot be represented: " ++ @typeName(ZigType)),
    }
}

// TODO: accept this from the build system
const target_dir_path = "lib/tigerbeetlex/bindings";

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var target_dir = try std.fs.cwd().openDir(target_dir_path, .{});
    defer target_dir.close();

    // Emit Elixir declarations.
    inline for (type_mappings) |type_mapping| {
        const ZigType = type_mapping[0];
        const mapping = type_mapping[1];

        var buffer = std.ArrayList(u8).init(allocator);
        try generate_bindings(ZigType, mapping, &buffer);

        try target_dir.writeFile(.{
            .sub_path = mapping.file_name ++ ".ex",
            .data = buffer.items,
        });
    }
}
