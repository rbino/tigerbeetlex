const std = @import("std");
const assert = std.debug.assert;

const beam = @import("beam.zig");
const resource = beam.resource;
const Resource = resource.Resource;

const tb = @import("vsr").tigerbeetle;
const tb_client = @import("vsr").tb_client;
const AccountFilter = tb.AccountFilter;
const Account = tb.Account;
const Transfer = tb.Transfer;

const ClientInterface = tb_client.ClientInterface;
pub const ClientResource = Resource(*ClientInterface, client_resource_deinit_fn);

const RequestContext = struct {
    caller_pid: beam.Pid,
    request_ref: beam.Term,
    client_raw_obj: *anyopaque,
};

const InitClientError = error{
    AddressInvalid,
    AddressLimitExceeded,
    NetworkSubsystemFailed,
    OutOfMemory,
    SystemResources,
    Unexpected,
};

pub fn init(env: beam.Env, cluster_id: u128, addresses: []const u8) beam.Term {
    return init_client(env, cluster_id, addresses) catch |err| switch (err) {
        error.AddressInvalid => beam.make_error_atom(env, "invalid_address"),
        error.AddressLimitExceeded => beam.make_error_atom(env, "address_limit_exceeded"),
        error.NetworkSubsystemFailed => beam.make_error_atom(env, "network_subsystem"),
        error.OutOfMemory => beam.make_error_atom(env, "out_of_memory"),
        error.SystemResources => beam.make_error_atom(env, "system_resources"),
        error.Unexpected => beam.make_error_atom(env, "unexpected"),
    };
}

fn init_client(env: beam.Env, cluster_id: u128, addresses: []const u8) InitClientError!beam.Term {
    const client = try beam.general_purpose_allocator.create(tb_client.ClientInterface);
    errdefer beam.general_purpose_allocator.destroy(client);

    try tb_client.init(
        beam.general_purpose_allocator,
        client,
        cluster_id,
        addresses,
        @intFromPtr(beam.alloc_env()),
        on_completion,
    );
    errdefer client.deinit() catch unreachable;

    const client_resource = try ClientResource.init(client);
    defer client_resource.release();

    const term_handle = client_resource.term_handle(env);

    return beam.make_ok_term(env, term_handle);
}

const SubmitError = error{
    TooManyRequests,
    Shutdown,
    OutOfMemory,
    ClientInvalid,
    ArgumentError,
};

// These are all comptime generated functions
pub const create_accounts = get_submit_fn(.create_accounts);
pub const create_transfers = get_submit_fn(.create_transfers);
pub const lookup_accounts = get_submit_fn(.lookup_accounts);
pub const lookup_transfers = get_submit_fn(.lookup_transfers);
pub const get_account_transfers = get_submit_fn(.get_account_transfers);
pub const get_account_balances = get_submit_fn(.get_account_balances);

fn get_submit_fn(comptime operation: tb_client.Operation) (fn (
    env: beam.Env,
    client_resource: beam.Term,
    payload_term: beam.Term,
) beam.Term) {
    return struct {
        fn submit_fn(
            env: beam.Env,
            client_term: beam.Term,
            payload_term: beam.Term,
        ) beam.Term {
            const client_resource = ClientResource.from_term_handle(env, client_term) catch
                return beam.make_error_atom(env, "invalid_client_resource");

            return submit(operation, env, client_resource, payload_term) catch |err| switch (err) {
                error.TooManyRequests => beam.make_error_atom(env, "too_many_requests"),
                error.Shutdown => beam.make_error_atom(env, "shutdown"),
                error.OutOfMemory => beam.make_error_atom(env, "out_of_memory"),
                error.ClientInvalid => beam.make_error_atom(env, "client_closed"),
                error.ArgumentError => beam.raise_badarg(env),
            };
        }
    }.submit_fn;
}

fn submit(
    comptime operation: tb_client.Operation,
    env: beam.Env,
    client_resource: ClientResource,
    payload_term: beam.Term,
) SubmitError!beam.Term {
    const client = client_resource.value();

    const ctx = try beam.general_purpose_allocator.create(RequestContext);
    errdefer beam.general_purpose_allocator.destroy(ctx);

    const packet = try beam.general_purpose_allocator.create(tb_client.Packet);
    errdefer beam.general_purpose_allocator.destroy(packet);

    // We're calling this from a process bound env so we expect not to fail
    const caller_pid = beam.self(env) catch unreachable;

    const ref = beam.make_ref(env);
    const completion_ctx = try client.completion_context();
    const tigerbeetle_env: beam.Env = @ptrFromInt(completion_ctx);
    const tigerbeetle_owned_ref = beam.make_copy(tigerbeetle_env, ref);
    const tigerbeetle_owned_payload_term = beam.make_copy(tigerbeetle_env, payload_term);

    const payload = try beam.get_char_slice(tigerbeetle_env, tigerbeetle_owned_payload_term);

    // We do the same with the client to make sure we don't deinit it until all requests
    // have been handled
    client_resource.keep();

    ctx.* = .{
        .caller_pid = caller_pid,
        .request_ref = tigerbeetle_owned_ref,
        .client_raw_obj = client_resource.raw_ptr,
    };

    packet.* = .{
        .user_data = ctx,
        .operation = @intFromEnum(operation),
        .data = payload.ptr,
        .data_size = @intCast(payload.len),
        .user_tag = 0,
        .status = undefined,
    };

    try client.submit(packet);

    return beam.make_ok_term(env, ref);
}

fn on_completion(
    context: usize,
    packet: *tb_client.Packet,
    timestamp: u64,
    result_ptr: ?[*]const u8,
    result_len: u32,
) callconv(.C) void {
    _ = timestamp;
    const ctx: *RequestContext = @ptrCast(@alignCast(packet.user_data.?));
    defer beam.general_purpose_allocator.destroy(ctx);

    // Same for the client
    resource.raw_release(ctx.client_raw_obj);

    const env: beam.Env = @ptrFromInt(context);
    defer beam.clear_env(env);

    const ref = ctx.request_ref;
    const caller_pid = ctx.caller_pid;

    const status = beam.make_u8(env, @intFromEnum(packet.status));
    const operation = beam.make_u8(env, packet.operation);
    beam.general_purpose_allocator.destroy(packet);
    const result = if (result_ptr) |p|
        beam.make_slice(env, p[0..result_len])
    else
        beam.make_nil(env);

    const response = beam.make_tuple(env, .{ status, operation, result });
    const tag = beam.make_atom(env, "tigerbeetlex_response");
    const msg = beam.make_tuple(env, .{ tag, ref, response });

    // Send the result to the caller
    // If it fails, it means that `caller_pid` is not alive anymore.
    // This is a possibly normal condition (all process can possibly crash)
    // so we should handle this gracefully.
    beam.send(caller_pid, env, msg) catch {};
}

fn client_resource_deinit_fn(_: beam.Env, ptr: ?*anyopaque) callconv(.C) void {
    if (ptr) |p| {
        const client: *ClientInterface = @ptrCast(@alignCast(p));
        // The client was already closed, we just return
        defer client.deinit() catch {};

        const completion_ctx = client.completion_context() catch |err| switch (err) {
            // The client was already closed, we just return
            error.ClientInvalid => return,
        };
        const env: beam.Env = @ptrFromInt(completion_ctx);
        beam.free_env(env);
    } else unreachable;
}
