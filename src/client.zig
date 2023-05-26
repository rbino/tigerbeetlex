const std = @import("std");

const beam = @import("beam");
const e = @import("erl_nif");
const resource = beam.resource;

const tb = @import("tigerbeetle");
const tb_client = @import("tigerbeetle/src/clients/c/tb_client.zig");
const Account = tb.Account;
const Transfer = tb.Transfer;

const batch = @import("batch.zig");
const beam_extras = @import("beam_extras.zig");
const resource_types = @import("resource_types.zig");
const Batch = batch.Batch;

pub const Client = struct {
    zig_client: tb_client.tb_client_t,
};

const RequestContext = struct {
    caller_pid: beam.pid,
    request_ref_binary: beam.binary,
};

pub fn init(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
    if (argc != 3) unreachable;

    const args = @ptrCast([*]const beam.term, argv)[0..@intCast(usize, argc)];

    const cluster_id: u32 = beam.get_u32(env, args[0]) catch
        return beam.raise_function_clause_error(env);

    const addresses = beam.get_char_slice(env, args[1]) catch
        return beam.raise_function_clause_error(env);

    const concurrency_max: u32 = beam.get_u32(env, args[2]) catch
        return beam.raise_function_clause_error(env);

    const zig_client: tb_client.tb_client_t = tb_client.init(
        beam.general_purpose_allocator,
        cluster_id,
        addresses,
        concurrency_max,
        @ptrToInt(e.enif_alloc_env()),
        on_completion,
    ) catch |err| switch (err) {
        error.Unexpected => return beam.make_error_atom(env, "unexpected"),
        error.OutOfMemory => return beam.make_error_atom(env, "out_of_memory"),
        error.AddressInvalid => return beam.make_error_atom(env, "invalid_address"),
        error.AddressLimitExceeded => return beam.make_error_atom(env, "address_limit_exceeded"),
        error.ConcurrencyMaxInvalid => return beam.make_error_atom(env, "invalid_concurrency_max"),
        error.SystemResources => return beam.make_error_atom(env, "system_resources"),
        error.NetworkSubsystemFailed => return beam.make_error_atom(env, "network_subsystem"),
    };

    const client = .{ .zig_client = zig_client };
    const client_resource = resource.create(Client, env, resource_types.client, client) catch |err|
        switch (err) {
        error.OutOfMemory => {
            // Deinit the client
            // TODO: do some refactoring to allow using errdefer
            tb_client.deinit(zig_client);
            return beam.make_error_atom(env, "out_of_memory");
        },
    };

    // We immediately release the resource and just let it be managed by the garbage collector
    // TODO: check all the corner cases to ensure this is the right thing to do
    resource.release(env, resource_types.client, client_resource);

    return beam.make_ok_term(env, client_resource);
}

fn batch_item_type_for_operation(comptime operation: tb_client.tb_operation_t) type {
    return switch (operation) {
        .create_accounts => Account,
        .create_transfers => Transfer,
        .lookup_accounts, .lookup_transfers => u128,
        else => unreachable,
    };
}

fn submit(
    comptime operation: tb_client.tb_operation_t,
    env: beam.env,
    client_term: beam.term,
    payload_term: beam.term,
) beam.term {
    const client = beam_extras.resource_ptr(Client, env, resource_types.client, client_term) catch |err|
        switch (err) {
        error.FetchError => return beam.make_error_atom(env, "invalid_client"),
    };

    const T = batch_item_type_for_operation(operation);
    var payload: Batch(T) = resource.fetch(Batch(T), env, resource_types.from_batch_type(T), payload_term) catch |err|
        switch (err) {
        error.FetchError => return beam.make_error_atom(env, "invalid_batch"),
    };

    var out_packet: ?*tb_client.tb_packet_t = undefined;
    const status = tb_client.acquire_packet(client.zig_client, &out_packet);
    const packet = switch (status) {
        .ok => if (out_packet) |pkt| pkt else @panic("acquire packet returned null"),
        .concurrency_max_exceeded => return beam.make_error_atom(env, "too_many_requests"),
        .shutdown => return beam.make_error_atom(env, "shutdown"),
    };

    var ctx: *RequestContext = beam.general_purpose_allocator.create(RequestContext) catch {
        // TODO: do some refactoring to allow using errdefer
        tb_client.release_packet(client.zig_client, packet);
        return beam.make_error_atom(env, "out_of_memory");
    };

    if (e.enif_self(env, &ctx.caller_pid) == null) unreachable;

    const ref = beam.make_ref(env);
    // We serialize the reference to binary since we would need an env created in
    // TigerBeetle's thread to copy the ref into, but we don't have it and don't
    // have any way to create it from this side, pass it to the completion function
    // and free it
    if (e.enif_term_to_binary(env, ref, &ctx.request_ref_binary) == 0) {
        // TODO: do some refactoring to allow using errdefer
        tb_client.release_packet(client.zig_client, packet);
        return beam.make_error_atom(env, "out_of_memory");
    }

    packet.operation = @enumToInt(operation);

    // TODO: how much does this need to be valid? Should we increment the refcount on the
    // resource to avoid it gets garbage collected while this is in-flight?
    packet.data = payload.items.ptr;
    packet.data_size = @sizeOf(T) * payload.len;
    packet.user_data = ctx;
    packet.status = .ok;

    tb_client.submit(client.zig_client, packet);

    return beam.make_ok_term(env, ref);
}

pub fn create_accounts(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
    if (argc != 2) unreachable;

    const args = @ptrCast([*]const beam.term, argv)[0..@intCast(usize, argc)];

    return submit(.create_accounts, env, args[0], args[1]);
}

pub fn create_transfers(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
    if (argc != 2) unreachable;

    const args = @ptrCast([*]const beam.term, argv)[0..@intCast(usize, argc)];

    return submit(.create_transfers, env, args[0], args[1]);
}

pub fn lookup_accounts(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
    if (argc != 2) unreachable;

    const args = @ptrCast([*]const beam.term, argv)[0..@intCast(usize, argc)];

    return submit(.lookup_accounts, env, args[0], args[1]);
}

pub fn lookup_transfers(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
    if (argc != 2) unreachable;

    const args = @ptrCast([*]const beam.term, argv)[0..@intCast(usize, argc)];

    return submit(.lookup_transfers, env, args[0], args[1]);
}

fn on_completion(
    context: usize,
    client: tb_client.tb_client_t,
    packet: *tb_client.tb_packet_t,
    result_ptr: ?[*]const u8,
    result_len: u32,
) callconv(.C) void {
    var ctx = @ptrCast(*RequestContext, @alignCast(@alignOf(*RequestContext), packet.user_data.?));
    defer beam.general_purpose_allocator.destroy(ctx);

    const env = @intToPtr(*e.ErlNifEnv, context);
    defer e.enif_clear_env(env);

    const ref_binary = &ctx.request_ref_binary;
    defer e.enif_release_binary(ref_binary);
    var ref: beam.term = undefined;
    if (e.enif_binary_to_term(env, ref_binary.data, ref_binary.size, &ref, 0) == 0) unreachable;

    const caller_pid = ctx.caller_pid;

    const operation = packet.operation;
    const status = packet.status;
    const result = if (result_ptr) |p|
        beam.make_slice(env, p[0..result_len])
    else
        beam.make_nil(env);

    const response =
        e.enif_make_tuple3(
        env,
        beam.make_u8(env, @enumToInt(status)),
        beam.make_u8(env, operation),
        result,
    );

    const msg =
        e.enif_make_tuple3(
        env,
        beam.make_atom(env, "tigerbeetlex_response"),
        ref,
        response,
    );

    if (e.enif_send(null, &caller_pid, env, msg) == 0) unreachable;

    // We're done with the packet, put it back in the pool
    tb_client.release_packet(client, packet);
}
