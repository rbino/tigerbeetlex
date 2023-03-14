const std = @import("std");

pub const e = @cImport({
    @cInclude("erl_nif.h");
});

pub const tb = @import("tigerbeetle");

// TODO: are these needed?
pub const vsr = @import("vsr");
pub const vsr_options = .{
    .config_base = vsr.config.ConfigBase.default,
    .tracer_backend = vsr.config.TracerBackend.none,
    .hash_log_mode = vsr.config.HashLogMode.none,
};

// Taken from tb_client/context.zig
pub const packet_counts_max = 4096;

// The resource type for the client
var client_resource: ?*e.ErlNifResourceType = undefined;

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

fn make_exception(env: ?*e.ErlNifEnv, reason_slice: []const u8) e.ERL_NIF_TERM {
    const reason = e.enif_make_atom_len(env, @ptrCast([*c]const u8, &reason_slice[0]), reason_slice.len);
    return e.enif_raise_exception(env, reason);
}

fn make_ok_tuple(env: ?*e.ErlNifEnv, term: e.ERL_NIF_TERM) e.ERL_NIF_TERM {
    return e.enif_make_tuple2(env, e.enif_make_atom(env, "ok"), term);
}

const Client = struct {
    c_client: tb.tb_client_t,
    packet_pool: tb.tb_packet_list_t,

    pub fn create(env: ?*e.ErlNifEnv, c_client: tb.tb_client_t, packets: tb.tb_packet_list_t) !e.ERL_NIF_TERM {
        var ptr: ?*anyopaque = e.enif_alloc_resource(client_resource, @sizeOf(Client));
        if (ptr == null) return error.OutOfMemory;

        // We immediately release the resource and just let it be managed by the garbage collector
        // TODO: check all the corner cases to ensure this is the right thing to do
        e.enif_release_resource(ptr);

        var client: *Client = undefined;
        client = @ptrCast(*Client, @alignCast(@alignOf(*Client), ptr));
        client.c_client = c_client;
        client.packet_pool = packets;

        return e.enif_make_resource(env, ptr);
    }

    pub fn fetch(env: ?*e.ErlNifEnv, term: e.ERL_NIF_TERM) !Client {
        var ptr: ?*anyopaque = undefined;

        if (e.enif_get_resource(env, term, client_resource, @ptrCast([*c]?*anyopaque, &ptr)) == 0) {
            return error.InvalidClient;
        }

        // From the Erlang docs (https://www.erlang.org/doc/man/erl_nif.html#enif_get_resource):
        // the pointer received in *objp is guaranteed to be valid at least as long as the
        // resource handle term is valid.

        if (ptr == null) {
            unreachable;
        }

        var client: *Client = @ptrCast(*Client, @alignCast(@alignOf(*Client), ptr));
        return client.*;
    }
};

export fn client_init(env: ?*e.ErlNifEnv, argc: c_int, argv: [*c]const e.ERL_NIF_TERM) e.ERL_NIF_TERM {
    if (argc != 3) unreachable;

    const args = @ptrCast([*]const e.ERL_NIF_TERM, argv)[0..@intCast(usize, argc)];

    const cluster_id: u32 = get_u32(env, args[0]) catch
        return e.enif_make_badarg(env);

    // TODO: is this big enough? Should we allocate?
    var addresses: [1024:0]u8 = undefined;
    const written = get_string(env, args[1], &addresses, @intCast(c_uint, addresses.len)) catch
        return e.enif_make_badarg(env);
    // written includes the terminator
    const addresses_len = written - 1;

    const max_concurrency: u32 = get_u32(env, args[2]) catch
        return e.enif_make_badarg(env);
    if (max_concurrency > packet_counts_max) return e.enif_make_badarg(env);

    var c_client: tb.tb_client_t = undefined;
    var packet_pool: tb.tb_packet_list_t = undefined;

    // TODO: this uses an allocator internally, it would be nice to pass it
    // the BEAM allocator to be able to track the used memory from the Erlang VM
    const status = tb.tb_client_init(
        &c_client,
        &packet_pool,
        cluster_id,
        &addresses,
        addresses_len,
        max_concurrency,
        0,
        on_completion,
    );

    if (status != .success) {
        switch (status) {
            .unexpected => return make_error_tuple(env, "unexpected"),
            .out_of_memory => return make_error_tuple(env, "out_of_memory"),
            .address_invalid => return make_error_tuple(env, "invalid_address"),
            .address_limit_exceeded => return make_error_tuple(env, "address_limit_exceeded"),
            // If we're here, we're out of sync with the C client
            .packets_count_invalid => return make_exception(env, "client_out_of_sync"),
            .system_resources => return make_error_tuple(env, "system_resources"),
            .network_subsystem => return make_error_tuple(env, "network_subsystem"),
            else => return make_exception(env, "invalid_error_code"),
        }
    }

    const client = Client.create(env, c_client, packet_pool) catch |err| switch (err) {
        error.OutOfMemory => return make_error_tuple(env, "out_of_memory"),
    };

    return make_ok_tuple(env, client);
}

export fn on_completion(
    context: usize,
    client: tb.tb_client_t,
    packet: *tb.tb_packet_t,
    result_ptr: ?[*]const u8,
    result_len: u32,
) void {
    _ = context;
    _ = client;
    _ = packet;
    _ = result_ptr;
    _ = result_len;
    // TODO
}

export fn client_deinit(_: ?*e.ErlNifEnv, ptr: ?*anyopaque) void {
    if (ptr) |ptr| {
        const client: *Client = @ptrCast(*Client, @alignCast(@alignOf(*Client), ptr));
        tb.tb_client_deinit(client.c_client);
    } else unreachable;
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
    .load = nif_load,
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

export fn nif_load(env: ?*e.ErlNifEnv, _: [*c]?*anyopaque, _: e.ERL_NIF_TERM) c_int {
    client_resource = e.enif_open_resource_type(
        env,
        null,
        "tigerbeetlex_client",
        client_deinit,
        e.ERL_NIF_RT_CREATE | e.ERL_NIF_RT_TAKEOVER,
        null,
    );
    return 0;
}
