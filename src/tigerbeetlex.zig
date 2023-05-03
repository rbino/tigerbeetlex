const std = @import("std");

pub const beam = @import("beam");
pub const e = @import("erl_nif");
pub const resource = beam.resource;

pub const tb = @import("tigerbeetle");
pub const tb_client = @import("tb_client.zig");
pub const Packet = tb_client.tb_packet_t;

pub const Account = tb.Account;
pub const AccountFlags = tb.AccountFlags;
pub const Transfer = tb.Transfer;

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

// The resource type for the transfer batch
var transfer_batch_resource_type: beam.resource_type = undefined;

fn raise(env: ?*e.ErlNifEnv, reason: []const u8) e.ErlNifTerm {
    return e.enif_raise_exception(env, beam.make_atom(env, reason));
}

// TODO: this is missing from Zigler and it's more ergonomic than doing fetch + update
pub fn resource_ptr(comptime T: type, environment: beam.env, res_typ: beam.resource_type, res_trm: e.ErlNifTerm) !*T {
    var obj: ?*anyopaque = undefined;

    if (0 == e.enif_get_resource(environment, res_trm, res_typ, @ptrCast([*c]?*anyopaque, &obj))) {
        return resource.ResourceError.FetchError;
    }

    // according to the erlang documentation:
    // the pointer received in *objp is guaranteed to be valid at least as long as the
    // resource handle term is valid.

    if (obj == null) {
        unreachable;
    }

    var val: *T = @ptrCast(*T, @alignCast(@alignOf(*T), obj));

    return val;
}

pub fn get_u128(env: beam.env, src_term: e.ErlNifTerm) !u128 {
    const bin = try beam.get_char_slice(env, src_term);
    const required_length = @sizeOf(u128) / @sizeOf(u8);

    // We represent the u128 as a 16 byte binary, little endian (required by TigerBeetle)
    if (bin.len != required_length) return error.InvalidU128;

    return std.mem.readIntNative(u128, bin[0..required_length]);
}

const Client = struct {
    c_client: tb_client.tb_client_t,
    packet_pool: tb_client.tb_packet_list_t,
};

fn Batch(comptime T: anytype) type {
    return struct {
        items: []T,
        len: u32,
    };
}

fn batch_resource_type(comptime T: anytype) beam.resource_type {
    return switch (T) {
        Account => account_batch_resource_type,
        Transfer => transfer_batch_resource_type,
        else => unreachable,
    };
}

const AccountBatch = Batch(Account);
const TransferBatch = Batch(Transfer);

const RequestContext = struct {
    caller_pid: e.ErlNifPid,
    request_ref_binary: e.ErlNifBinary,
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

    return create_batch(Account, env, capacity);
}

export fn create_transfer_batch(env: ?*e.ErlNifEnv, argc: c_int, argv: [*c]const e.ERL_NIF_TERM) e.ERL_NIF_TERM {
    if (argc != 1) unreachable;

    const args = @ptrCast([*]const e.ERL_NIF_TERM, argv)[0..@intCast(usize, argc)];

    const capacity: u32 = beam.get_u32(env, args[0]) catch
        return beam.raise_function_clause_error(env);

    return create_batch(Transfer, env, capacity);
}

fn create_batch(comptime T: anytype, env: ?*e.ErlNifEnv, capacity: u32) e.ERL_NIF_TERM {
    const items = beam.large_allocator.alloc(T, capacity) catch |err|
        switch (err) {
        error.OutOfMemory => return beam.make_error_atom(env, "out_of_memory"),
    };

    const resource_type = batch_resource_type(T);

    const batch = Batch(T){
        .items = items,
        .len = 0,
    };
    const batch_resource = resource.create(Batch(T), env, resource_type, batch) catch |err|
        switch (err) {
        error.OutOfMemory => return beam.make_error_atom(env, "out_of_memory"),
    };

    // We immediately release the resource and just let it be managed by the garbage collector
    // TODO: check all the corner cases to ensure this is the right thing to do
    resource.release(env, resource_type, batch_resource);

    return beam.make_ok_term(env, batch_resource);
}

export fn add_account(env: ?*e.ErlNifEnv, argc: c_int, argv: [*c]const e.ERL_NIF_TERM) e.ERL_NIF_TERM {
    if (argc != 1) unreachable;

    const args = @ptrCast([*]const e.ERL_NIF_TERM, argv)[0..@intCast(usize, argc)];

    const account_batch = resource_ptr(AccountBatch, env, account_batch_resource_type, args[0]) catch |err|
        switch (err) {
        error.FetchError => return beam.make_error_atom(env, "invalid_account_batch"),
    };

    if (account_batch.len + 1 > account_batch.items.len) {
        return beam.make_error_atom(env, "account_batch_full");
    }
    account_batch.len += 1;
    account_batch.items[account_batch.len - 1] = std.mem.zeroInit(Account, .{});

    return beam.make_ok(env);
}

fn set_account_field(
    comptime field: std.meta.FieldEnum(Account),
    env: ?*e.ErlNifEnv,
    argc: c_int,
    argv: [*c]const e.ERL_NIF_TERM,
) e.ERL_NIF_TERM {
    if (argc != 3) unreachable;

    const args = @ptrCast([*]const e.ERL_NIF_TERM, argv)[0..@intCast(usize, argc)];

    const account_batch = resource_ptr(AccountBatch, env, account_batch_resource_type, args[0]) catch |err|
        switch (err) {
        error.FetchError => return beam.make_error_atom(env, "invalid_account_batch"),
    };

    const idx: u32 = beam.get_u32(env, args[1]) catch
        return beam.raise_function_clause_error(env);

    if (idx >= account_batch.len) {
        return beam.make_error_atom(env, "out_of_bounds");
    }

    const account: *Account = &account_batch.items[idx];

    switch (field) {
        .id => {
            const id = get_u128(env, args[2]) catch
                return beam.raise_function_clause_error(env);
            // These are invalid values according to TigerBeetle's documentation
            if (id == 0 or id == std.math.maxInt(u128)) return beam.raise_function_clause_error(env);

            account.id = id;
        },
        .user_data => {
            const user_data = get_u128(env, args[2]) catch
                return beam.raise_function_clause_error(env);

            account.user_data = user_data;
        },
        .ledger => {
            const ledger = beam.get_u32(env, args[2]) catch
                return beam.raise_function_clause_error(env);

            // Invalid value according to TigerBeetle's documentation
            if (ledger == 0) return beam.raise_function_clause_error(env);

            account.ledger = ledger;
        },
        .code => {
            const code = beam.get_u16(env, args[2]) catch
                return beam.raise_function_clause_error(env);

            // Invalid value according to TigerBeetle's documentation
            if (code == 0) return beam.raise_function_clause_error(env);

            account.code = code;
        },
        .flags => {
            const flags_uint = beam.get_u16(env, args[2]) catch
                return beam.raise_function_clause_error(env);

            const flags: AccountFlags = @bitCast(AccountFlags, flags_uint);

            // Mutually exclusive
            if (flags.debits_must_not_exceed_credits and flags.credits_must_not_exceed_debits)
                return beam.raise_function_clause_error(env);

            account.flags = flags;
        },
        else => unreachable,
    }

    return beam.make_ok(env);
}

export fn set_account_id(env: ?*e.ErlNifEnv, argc: c_int, argv: [*c]const e.ERL_NIF_TERM) e.ERL_NIF_TERM {
    return set_account_field(.id, env, argc, argv);
}

export fn set_account_user_data(env: ?*e.ErlNifEnv, argc: c_int, argv: [*c]const e.ERL_NIF_TERM) e.ERL_NIF_TERM {
    return set_account_field(.user_data, env, argc, argv);
}

export fn set_account_ledger(env: ?*e.ErlNifEnv, argc: c_int, argv: [*c]const e.ERL_NIF_TERM) e.ERL_NIF_TERM {
    return set_account_field(.ledger, env, argc, argv);
}

export fn set_account_code(env: ?*e.ErlNifEnv, argc: c_int, argv: [*c]const e.ERL_NIF_TERM) e.ERL_NIF_TERM {
    return set_account_field(.code, env, argc, argv);
}

export fn set_account_flags(env: ?*e.ErlNifEnv, argc: c_int, argv: [*c]const e.ERL_NIF_TERM) e.ERL_NIF_TERM {
    return set_account_field(.flags, env, argc, argv);
}

export fn create_accounts(env: ?*e.ErlNifEnv, argc: c_int, argv: [*c]const e.ERL_NIF_TERM) e.ERL_NIF_TERM {
    if (argc != 2) unreachable;

    const args = @ptrCast([*]const e.ERL_NIF_TERM, argv)[0..@intCast(usize, argc)];

    const client = resource_ptr(Client, env, client_resource_type, args[0]) catch |err|
        switch (err) {
        error.FetchError => return beam.make_error_atom(env, "invalid_client"),
    };

    var account_batch: AccountBatch = resource.fetch(AccountBatch, env, account_batch_resource_type, args[1]) catch |err|
        switch (err) {
        error.FetchError => return beam.make_error_atom(env, "invalid_account_batch"),
    };

    var ctx: *RequestContext = beam.allocator.create(RequestContext) catch
        return beam.make_error_atom(env, "out_of_memory");

    if (e.enif_self(env, &ctx.caller_pid) == null) unreachable;

    if (client.packet_pool.pop()) |packet| {
        const ref = beam.make_ref(env);
        // We serialize the reference to binary since we would need an env created in
        // TigerBeetle's thread to copy the ref into, but we don't have it and don't
        // have any way to create it from this side, pass it to the completion function
        // and free it
        if (e.enif_term_to_binary(env, ref, &ctx.request_ref_binary) == 0)
            return beam.make_error_atom(env, "out_of_memory");

        packet.operation = @enumToInt(tb_client.tb_operation_t.create_accounts);
        // TODO: how much does this need to be valid? Should we increment the refcount on the
        // resource to avoid it gets garbage collected while this is in-flight?
        packet.data = account_batch.items.ptr;
        packet.data_size = @sizeOf(Account) * account_batch.len;
        packet.user_data = ctx;
        packet.status = .ok;

        var packets: tb_client.tb_packet_list_t = .{};
        packets.head = packet;
        packets.tail = packet;

        tb_client.tb_client_submit(client.c_client, &packets);

        if (packet.status != .ok) {
            beam.allocator.destroy(ctx);
        }

        return switch (packet.status) {
            .ok => beam.make_ok_term(env, ref),
            .too_much_data => beam.make_error_atom(env, "too_much_data"),
            .invalid_operation => beam.make_error_atom(env, "invalid_operation"),
            .invalid_data_size => beam.make_error_atom(env, "invalid_data_size"),
        };
    } else {
        beam.allocator.destroy(ctx);
        return beam.make_error_atom(env, "too_many_requests");
    }
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
    var ctx = @ptrCast(*RequestContext, @alignCast(@alignOf(RequestContext), packet.user_data.?));
    defer beam.allocator.destroy(ctx);

    const env = e.enif_alloc_env();
    defer e.enif_free_env(env);

    const ref_binary = &ctx.request_ref_binary;
    defer e.enif_release_binary(ref_binary);
    var ref: e.ERL_NIF_TERM = undefined;
    if (e.enif_binary_to_term(env, ref_binary.data, ref_binary.size, &ref, 0) == 0) unreachable;

    const caller_pid = ctx.caller_pid;

    const operation = packet.operation;
    const status = packet.status;
    const result = if (result_ptr) |p|
        beam.make_slice(env, p[0..result_len])
    else
        beam.make_nil(env);

    const msg =
        e.enif_make_tuple5(
        env,
        beam.make_atom(env, "tb_response"),
        ref,
        beam.make_u8(env, operation),
        beam.make_u8(env, @enumToInt(status)),
        result,
    );

    if (e.enif_send(null, &caller_pid, env, msg) == 0) unreachable;
}

export fn client_resource_deinit(_: ?*e.ErlNifEnv, ptr: ?*anyopaque) void {
    if (ptr) |p| {
        const client: *Client = @ptrCast(*Client, @alignCast(@alignOf(*Client), p));
        tb_client.tb_client_deinit(client.c_client);
    } else unreachable;
}

fn batch_deinit_fn(comptime T: anytype) fn (env: ?*e.ErlNifEnv, ptr: ?*anyopaque) callconv(.C) void {
    return struct {
        pub fn deinit_fn(_: ?*e.ErlNifEnv, ptr: ?*anyopaque) callconv(.C) void {
            if (ptr) |p| {
                const batch: *T = @ptrCast(*T, @alignCast(@alignOf(*T), p));
                beam.large_allocator.free(batch.items);
            } else unreachable;
        }
    }.deinit_fn;
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
    e.ErlNifFunc{
        .name = "add_account",
        .arity = 1,
        .fptr = add_account,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "set_account_id",
        .arity = 3,
        .fptr = set_account_id,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "set_account_user_data",
        .arity = 3,
        .fptr = set_account_user_data,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "set_account_ledger",
        .arity = 3,
        .fptr = set_account_ledger,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "set_account_code",
        .arity = 3,
        .fptr = set_account_code,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "set_account_flags",
        .arity = 3,
        .fptr = set_account_flags,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "create_accounts",
        .arity = 2,
        .fptr = create_accounts,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "create_transfer_batch",
        .arity = 1,
        .fptr = create_transfer_batch,
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
        batch_deinit_fn(AccountBatch),
        e.ERL_NIF_RT_CREATE | e.ERL_NIF_RT_TAKEOVER,
        null,
    );
    transfer_batch_resource_type = e.enif_open_resource_type(
        env,
        null,
        "tigerbeetlex_transfer_batch",
        batch_deinit_fn(TransferBatch),
        e.ERL_NIF_RT_CREATE | e.ERL_NIF_RT_TAKEOVER,
        null,
    );
    return 0;
}
