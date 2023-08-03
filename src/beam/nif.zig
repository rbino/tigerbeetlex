const e = @import("erl_nif.zig");
const beam = @import("../beam.zig");

pub const Nif = *const fn (beam.Env, argc: c_int, argv: [*c]const beam.Term) callconv(.C) beam.Term;
pub const NifLoadFn = *const fn (beam.Env, [*c]?*anyopaque, beam.Term) callconv(.C) c_int;

pub const FunctionEntry = e.ErlNifFunc;
pub const Entrypoint = e.ErlNifEntry;

pub fn function_entry(
    comptime name: [*c]const u8,
    comptime arity: c_uint,
    comptime fun: Nif,
) FunctionEntry {
    return .{ .name = name, .arity = arity, .fptr = fun, .flags = 0 };
}

pub fn entrypoint(
    name: [*c]const u8,
    comptime exported_nifs: []e.ErlNifFunc,
    load: NifLoadFn,
) Entrypoint {
    return .{
        .major = 2,
        .minor = 16,
        .name = name,
        .num_of_funcs = exported_nifs.len,
        .funcs = exported_nifs.ptr,
        .load = load,
        .reload = null, // currently unsupported
        .upgrade = null, // currently unsupported
        .unload = null, // currently unsupported
        .vm_variant = "beam.vanilla",
        .options = 1,
        .sizeof_ErlNifResourceTypeInit = @sizeOf(e.ErlNifResourceTypeInit),
        .min_erts = "erts-13.1.2",
    };
}
