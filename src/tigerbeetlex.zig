const std = @import("std");

pub const beam = @import("beam");
pub const e = @import("erl_nif");
pub const resource = beam.resource;

pub const tb = @import("tigerbeetle");
pub const tb_client = @import("tb_client.zig");

pub const Account = tb.Account;

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
var client_resource_type: beam.resource_type = undefined;

// The resource type for the account batch
var account_batch_resource_type: beam.resource_type = undefined;

fn raise(env: ?*e.ErlNifEnv, reason: []const u8) e.ErlNifTerm {
    return e.enif_raise_exception(env, beam.make_atom(env, reason));
}

const Client = struct {
    c_client: tb_client.tb_client_t,
    packet_pool: tb_client.tb_packet_list_t,
};

const AccountBatch = struct {
    accounts: []Account,
    len: u32,
    capacity: u32,
};

export fn client_init(env: ?*e.ErlNifEnv, argc: c_int, argv: [*c]const e.ERL_NIF_TERM) e.ERL_NIF_TERM {
    if (argc != 3) unreachable;

    const args = @ptrCast([*]const e.ERL_NIF_TERM, argv)[0..@intCast(usize, argc)];

    const cluster_id: u32 = beam.get_u32(env, args[0]) catch
        return beam.raise_function_clause_error(env);

    const addresses = beam.get_char_slice(env, args[1]) catch
        return beam.raise_function_clause_error(env);

    const max_concurrency: u32 = beam.get_u32(env, args[2]) catch
        return beam.raise_function_clause_error(env);
    if (max_concurrency > packet_counts_max) return beam.raise_function_clause_error(env);

    var c_client: tb_client.tb_client_t = undefined;
    var packet_pool: tb_client.tb_packet_list_t = undefined;

    // TODO: beam.large_allocator is not thread-safe, is this ok?
    const status = tb_client.client_init(
        beam.large_allocator,
        &c_client,
        &packet_pool,
        cluster_id,
        addresses,
        max_concurrency,
        0,
        on_completion,
    );

    if (status != .success) {
        switch (status) {
            .unexpected => return beam.make_error_atom(env, "unexpected"),
            .out_of_memory => return beam.make_error_atom(env, "out_of_memory"),
            .address_invalid => return beam.make_error_atom(env, "invalid_address"),
            .address_limit_exceeded => return beam.make_error_atom(env, "address_limit_exceeded"),
            // If we're here, we're out of sync with the C client
            .packets_count_invalid => return raise(env, "client_out_of_sync"),
            .system_resources => return beam.make_error_atom(env, "system_resources"),
            .network_subsystem => return beam.make_error_atom(env, "network_subsystem"),
            else => return raise(env, "invalid_error_code"),
        }
    }

    const client = .{ .c_client = c_client, .packet_pool = packet_pool };
    const client_resource = resource.create(Client, env, client_resource_type, client) catch |err|
        switch (err) {
        error.OutOfMemory => return beam.make_error_atom(env, "out_of_memory"),
    };

    // We immediately release the resource and just let it be managed by the garbage collector
    // TODO: check all the corner cases to ensure this is the right thing to do
    resource.release(env, client_resource_type, client_resource);

    return beam.make_ok_term(env, client_resource);
}

export fn create_account_batch(env: ?*e.ErlNifEnv, argc: c_int, argv: [*c]const e.ERL_NIF_TERM) e.ERL_NIF_TERM {
    if (argc != 1) unreachable;

    const args = @ptrCast([*]const e.ERL_NIF_TERM, argv)[0..@intCast(usize, argc)];

    const capacity: u32 = beam.get_u32(env, args[0]) catch
        return beam.raise_function_clause_error(env);

    const accounts = beam.large_allocator.alloc(Account, capacity) catch |err|
        switch (err) {
        error.OutOfMemory => return beam.make_error_atom(env, "out_of_memory"),
    };

    const account_batch = AccountBatch{
        .accounts = accounts,
        .len = 0,
        .capacity = capacity,
    };
    const account_batch_resource = resource.create(AccountBatch, env, account_batch_resource_type, account_batch) catch |err|
        switch (err) {
        error.OutOfMemory => return beam.make_error_atom(env, "out_of_memory"),
    };

    // We immediately release the resource and just let it be managed by the garbage collector
    // TODO: check all the corner cases to ensure this is the right thing to do
    resource.release(env, account_batch_resource_type, account_batch_resource);

    return beam.make_ok_term(env, account_batch_resource);
}

export fn on_completion(
    context: usize,
    client: tb_client.tb_client_t,
    packet: *tb_client.tb_packet_t,
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

export fn client_resource_deinit(_: ?*e.ErlNifEnv, ptr: ?*anyopaque) void {
    if (ptr) |p| {
        const client: *Client = @ptrCast(*Client, @alignCast(@alignOf(*Client), p));
        tb_client.tb_client_deinit(client.c_client);
    } else unreachable;
}

export fn account_batch_resource_deinit(_: ?*e.ErlNifEnv, ptr: ?*anyopaque) void {
    if (ptr) |p| {
        const account_batch: *AccountBatch = @ptrCast(*AccountBatch, @alignCast(@alignOf(*AccountBatch), p));
        beam.large_allocator.free(account_batch.accounts);
    } else unreachable;
}

export var __exported_nifs__ = [_]e.ErlNifFunc{
    e.ErlNifFunc{
        .name = "client_init",
        .arity = 3,
        .fptr = client_init,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "create_account_batch",
        .arity = 1,
        .fptr = create_account_batch,
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

export fn nif_load(env: ?*e.ErlNifEnv, _: [*c]?*anyopaque, _: e.ErlNifTerm) c_int {
    client_resource_type = e.enif_open_resource_type(
        env,
        null,
        "tigerbeetlex_client",
        client_resource_deinit,
        e.ERL_NIF_RT_CREATE | e.ERL_NIF_RT_TAKEOVER,
        null,
    );
    account_batch_resource_type = e.enif_open_resource_type(
        env,
        null,
        "tigerbeetlex_account_batch",
        account_batch_resource_deinit,
        e.ERL_NIF_RT_CREATE | e.ERL_NIF_RT_TAKEOVER,
        null,
    );
    return 0;
}
