const std = @import("std");

pub const e = @cImport({
    @cInclude("erl_nif.h");
});

// Taken from tb_client/context.zig
pub const packet_counts_max = 4096;

fn get_u32(env: ?*e.ErlNifEnv, term: e.ERL_NIF_TERM) !u32 {
    var result: c_uint = undefined;
    if (e.enif_get_uint(env, term, &result) != 0) {
        return @intCast(u32, result);
    } else {
        return error.InvalidType;
    }
}

fn get_i32(env: ?*e.ErlNifEnv, term: e.ERL_NIF_TERM) !i32 {
    var result: c_int = undefined;
    if (e.enif_get_int(env, term, &result) != 0) {
        return @intCast(i32, result);
    } else {
        return error.InvalidType;
    }
}

fn get_string(env: ?*e.ErlNifEnv, term: e.ERL_NIF_TERM, buffer: [*]u8, length: c_uint) !u32 {
    const result: c_int = e.enif_get_string(env, term, buffer, length, e.ERL_NIF_LATIN1);
    if (result > 0) {
        return @intCast(u32, result);
    } else if (result == -@intCast(c_int, length)) {
        return error.NoSpaceLeft;
    } else {
        return error.InvalidType;
    }
}

fn make_error_tuple(env: ?*e.ErlNifEnv, reason_slice: []const u8) e.ERL_NIF_TERM {
    const reason = e.enif_make_atom_len(env, @ptrCast([*c]const u8, &reason_slice[0]), reason_slice.len);
    return e.enif_make_tuple2(env, e.enif_make_atom(env, "error"), reason);
}

export fn client_init(env: ?*e.ErlNifEnv, argc: c_int, argv: [*c]const e.ERL_NIF_TERM) e.ERL_NIF_TERM {
    if (argc != 3) unreachable;

    const args = @ptrCast([*]const e.ERL_NIF_TERM, argv)[0..@intCast(usize, argc)];

    const cluster_id: u32 = get_u32(env, args[0]) catch
        return e.enif_make_badarg(env);
    _ = cluster_id;

    // TODO: is this big enough? Should we allocate?
    var addresses: [1024:0]u8 = undefined;
    const written = get_string(env, args[1], &addresses, @intCast(c_uint, addresses.len)) catch
        return e.enif_make_badarg(env);
    // written includes the terminator
    const addresses_len = written - 1;
    _ = addresses_len;

    const max_concurrency: u32 = get_u32(env, args[2]) catch
        return e.enif_make_badarg(env);
    if (max_concurrency > packet_counts_max) return e.enif_make_badarg(env);

    return make_error_tuple(env, "todo");
}

export var __exported_nifs__ = [_]e.ErlNifFunc{
    e.ErlNifFunc{
        .name = "client_init",
        .arity = 3,
        .fptr = client_init,
        .flags = 0,
    },
};

const entry = e.ErlNifEntry{
    .major = 2,
    .minor = 16,
    .name = "Elixir.TigerBeetlex.NifAdapter",
    .num_of_funcs = __exported_nifs__.len,
    .funcs = &(__exported_nifs__[0]),
    .load = null,
    .reload = null, // currently unsupported
    .upgrade = null, // currently unsupported
    .unload = null, // currently unsupported
    .vm_variant = "beam.vanilla",
    .options = 1,
    .sizeof_ErlNifResourceTypeInit = @sizeOf(e.ErlNifResourceTypeInit),
    .min_erts = "erts-13.1.2",
};

export fn nif_init() *const e.ErlNifEntry {
    return &entry;
}
