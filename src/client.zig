const std = @import("std");
const assert = std.debug.assert;

const beam = @import("beam.zig");

const tb = @import("vsr").tigerbeetle;
const tb_client = @import("vsr").tb_client;
const AccountFilter = tb.AccountFilter;
const Account = tb.Account;
const Transfer = tb.Transfer;

const ClientInterface = tb_client.ClientInterface;

const ClientResource = beam.Resource(*ClientInterface, "TigerBeetlex.Client", client_resource_deinit_fn);

const RequestContext = struct {
    env: *beam.Env,
    caller_pid: beam.Pid,
    client_resource: ClientResource,
    request_ref: beam.Term,
};

const InitClientError = error{
    AddressInvalid,
    AddressLimitExceeded,
    ArgumentError,
    NetworkSubsystemFailed,
    OutOfMemory,
    SystemResources,
    Unexpected,
};

pub fn initialize_resources(env: *beam.Env) !void {
    try ClientResource.open_type(env);
}

pub fn init(env: *beam.Env, cluster_id_term: beam.Term, addresses_term: beam.Term) beam.Term {
    return init_client(env, cluster_id_term, addresses_term) catch |err| switch (err) {
        error.AddressInvalid => beam.make_error_atom(env, "invalid_address"),
        error.AddressLimitExceeded => beam.make_error_atom(env, "address_limit_exceeded"),
        error.ArgumentError => beam.raise_badarg(env),
        error.NetworkSubsystemFailed => beam.make_error_atom(env, "network_subsystem"),
        error.OutOfMemory => beam.make_error_atom(env, "out_of_memory"),
        error.SystemResources => beam.make_error_atom(env, "system_resources"),
        error.Unexpected => beam.make_error_atom(env, "unexpected"),
    };
}

fn init_client(env: *beam.Env, cluster_id_term: beam.Term, addresses_term: beam.Term) InitClientError!beam.Term {
    const cluster_id = try beam.get_u128(env, cluster_id_term);
    const addresses = try beam.get_char_slice(env, addresses_term);

    const client = try beam.general_purpose_allocator.create(tb_client.ClientInterface);
    errdefer beam.general_purpose_allocator.destroy(client);

    try tb_client.init(
        beam.general_purpose_allocator,
        client,
        cluster_id,
        addresses,
        0,
        on_completion,
    );
    errdefer client.deinit() catch unreachable;

    // We create a NIF resource to store the pointer to our client
    // We use the refcounting feature of resources to ensure we only deinit the client after
    // everyone is done using it.
    const client_resource = try ClientResource.init(client);

    // We create the resource term handle so we can retrieve the client pointer from it
    const term_handle = client_resource.term_handle(env);

    // We release the resource since we're not holding a reference to the client
    defer client_resource.release();

    // We return the term handle
    return beam.make_ok_term(env, term_handle);
}

const SubmitError = error{
    InvalidResourceTerm,
    TooManyRequests,
    Shutdown,
    OutOfMemory,
    ClientInvalid,
    ArgumentError,
};

pub fn create_accounts(env: *beam.Env, client_resource: beam.Term, payload_term: beam.Term) beam.Term {
    return submit(
        env,
        client_resource,
        .create_accounts,
        payload_term,
    ) catch |err| handle_submit_error(env, err);
}

pub fn create_transfers(env: *beam.Env, client_resource: beam.Term, payload_term: beam.Term) beam.Term {
    return submit(
        env,
        client_resource,
        .create_transfers,
        payload_term,
    ) catch |err| handle_submit_error(env, err);
}

pub fn lookup_accounts(env: *beam.Env, client_resource: beam.Term, payload_term: beam.Term) beam.Term {
    return submit(
        env,
        client_resource,
        .lookup_accounts,
        payload_term,
    ) catch |err| handle_submit_error(env, err);
}

pub fn lookup_transfers(env: *beam.Env, client_resource: beam.Term, payload_term: beam.Term) beam.Term {
    return submit(
        env,
        client_resource,
        .lookup_transfers,
        payload_term,
    ) catch |err| handle_submit_error(env, err);
}

pub fn get_account_transfers(env: *beam.Env, client_resource: beam.Term, payload_term: beam.Term) beam.Term {
    return submit(
        env,
        client_resource,
        .get_account_transfers,
        payload_term,
    ) catch |err| handle_submit_error(env, err);
}

pub fn get_account_balances(env: *beam.Env, client_resource: beam.Term, payload_term: beam.Term) beam.Term {
    return submit(
        env,
        client_resource,
        .get_account_balances,
        payload_term,
    ) catch |err| handle_submit_error(env, err);
}

pub fn query_accounts(env: *beam.Env, client_resource: beam.Term, payload_term: beam.Term) beam.Term {
    return submit(
        env,
        client_resource,
        .query_accounts,
        payload_term,
    ) catch |err| handle_submit_error(env, err);
}

pub fn query_transfers(env: *beam.Env, client_resource: beam.Term, payload_term: beam.Term) beam.Term {
    return submit(
        env,
        client_resource,
        .query_transfers,
        payload_term,
    ) catch |err| handle_submit_error(env, err);
}

fn submit(
    env: *beam.Env,
    client_term: beam.Term,
    operation: tb_client.Operation,
    payload_term: beam.Term,
) SubmitError!beam.Term {
    assert(operation != .pulse);

    const client_resource = try ClientResource.from_term_handle(env, client_term);
    const client = client_resource.value();

    const ctx = try beam.general_purpose_allocator.create(RequestContext);
    errdefer beam.general_purpose_allocator.destroy(ctx);

    const packet = try beam.general_purpose_allocator.create(tb_client.Packet);
    errdefer beam.general_purpose_allocator.destroy(packet);

    // We're calling this from a process bound env so we expect not to fail
    const caller_pid = beam.self(env) catch unreachable;

    // Create a unique ref that will identify this specific request
    const ref = beam.make_ref(env);

    // Allocate a process independent environment for the request
    const request_env: *beam.Env = try beam.alloc_env();

    // Copy over the ref and the payload term in the process independent environment
    // Those need to be accessible in the on_completion callback, so we must copy them over
    // because the terms bound to the process bound environment (env) are not valid anymore
    // once the NIF returns.
    const request_owned_ref = beam.make_copy(request_env, ref);
    // Note that copying the payload term _does not_ copy the whole binary, since it's a
    // refcounted binary. It just copies a new reference to it.
    const request_owned_payload_term = beam.make_copy(request_env, payload_term);

    // Get a pointer to the actual binary data from the payload term
    const payload = try beam.get_char_slice(request_env, request_owned_payload_term);

    // We increase the refcount of the client resource so we can be sure the destructor is not
    // called until all requests have been completed
    client_resource.keep();

    ctx.* = .{
        .env = request_env,
        .caller_pid = caller_pid,
        .client_resource = client_resource,
        .request_ref = request_owned_ref,
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

    // Return the ref to the caller
    return beam.make_ok_term(env, ref);
}

fn handle_submit_error(env: *beam.Env, err: SubmitError) beam.Term {
    return switch (err) {
        error.InvalidResourceTerm => beam.make_error_atom(env, "invalid_client_resource"),
        error.TooManyRequests => beam.make_error_atom(env, "too_many_requests"),
        error.Shutdown => beam.make_error_atom(env, "shutdown"),
        error.OutOfMemory => beam.make_error_atom(env, "out_of_memory"),
        error.ClientInvalid => beam.make_error_atom(env, "client_closed"),
        error.ArgumentError => beam.raise_badarg(env),
    };
}

fn on_completion(
    context: usize,
    packet: *tb_client.Packet,
    timestamp: u64,
    result_ptr: ?[*]const u8,
    result_len: u32,
) callconv(.C) void {
    _ = context;
    assert(packet.user_data != null);
    const ctx: *RequestContext = @ptrCast(@alignCast(packet.user_data));
    defer beam.general_purpose_allocator.destroy(ctx);

    // Decrease client resource refcount after we exit
    defer ctx.client_resource.release();

    const env: *beam.Env = ctx.env;
    // Free the request env when we finish
    defer beam.free_env(env);

    const ref = ctx.request_ref;
    const caller_pid = ctx.caller_pid;

    // Extract the packet details before freeing it.
    const packet_operation = packet.operation;
    const packet_status = packet.status;
    beam.general_purpose_allocator.destroy(packet);

    if (packet_status != .ok) {
        assert(timestamp == 0);
        assert(result_ptr == null);
        assert(result_len == 0);
    }

    const status = beam.make_u8(env, @intFromEnum(packet_status));
    const operation = beam.make_u8(env, packet_operation);
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

fn client_resource_deinit_fn(env: ?*beam.Env, resource_pointer: ?*anyopaque) callconv(.C) void {
    _ = env;
    const client_resource = ClientResource.from_resource_pointer(resource_pointer.?);
    const client = client_resource.value();
    // If deinit fails, the client was already closed, so we just ignore it
    defer client.deinit() catch {};
}
