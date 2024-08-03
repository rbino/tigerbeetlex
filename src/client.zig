const std = @import("std");
const assert = std.debug.assert;

const beam = @import("beam.zig");
const process = beam.process;
const resource = beam.resource;
const Resource = resource.Resource;

const tb = @import("tigerbeetle/src/tigerbeetle.zig");
const tb_client = @import("tigerbeetle/src/clients/c/tb_client.zig");
const Account = tb.Account;
const Transfer = tb.Transfer;

const batch = @import("batch.zig");
const Batch = batch.Batch;
const BatchResource = batch.BatchResource;

pub const Client = tb_client.tb_client_t;
pub const ClientResource = Resource(Client, client_resource_deinit_fn);

const RequestContext = struct {
    caller_pid: beam.Pid,
    request_ref_binary: beam.Binary,
    payload_raw_obj: *anyopaque,
};

pub fn init(env: beam.Env, cluster_id: u128, addresses: []const u8, concurrency_max: u32) beam.Term {
    const client: tb_client.tb_client_t = tb_client.init(
        beam.general_purpose_allocator,
        cluster_id,
        addresses,
        concurrency_max,
        @intFromPtr(beam.alloc_env()),
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

    const client_resource = ClientResource.init(client) catch |err|
        switch (err) {
        error.OutOfMemory => {
            // Deinit the client
            // TODO: do some refactoring to allow using errdefer
            tb_client.deinit(client);
            return beam.make_error_atom(env, "out_of_memory");
        },
    };
    const term_handle = client_resource.term_handle(env);
    client_resource.release();

    return beam.make_ok_term(env, term_handle);
}

fn OperationBatchItemType(comptime operation: tb_client.tb_operation_t) type {
    return switch (operation) {
        .create_accounts => Account,
        .create_transfers => Transfer,
        .lookup_accounts, .lookup_transfers => u128,
        .get_account_transfers, .get_account_history => @panic("TODO"),
    };
}

const SubmitError = error{
    TooManyRequests,
    Shutdown,
    OutOfMemory,
};

// These are all comptime generated functions
pub const create_accounts = get_submit_fn(.create_accounts);
pub const create_transfers = get_submit_fn(.create_transfers);
pub const lookup_accounts = get_submit_fn(.lookup_accounts);
pub const lookup_transfers = get_submit_fn(.lookup_transfers);

fn get_submit_fn(comptime operation: tb_client.tb_operation_t) (fn (
    env: beam.Env,
    client_resource: beam.Term,
    payload_term: beam.Term,
) beam.Term) {
    const Item = OperationBatchItemType(operation);

    return struct {
        fn submit_fn(
            env: beam.Env,
            client_term: beam.Term,
            payload_term: beam.Term,
        ) beam.Term {
            const client_resource = ClientResource.from_term_handle(env, client_term) catch
                return beam.make_error_atom(env, "invalid_client_resource");

            const payload_resource = BatchResource(Item).from_term_handle(env, payload_term) catch
                return beam.make_error_atom(env, "invalid_batch_resource");

            return submit(operation, env, client_resource, payload_resource) catch |err| switch (err) {
                error.TooManyRequests => beam.make_error_atom(env, "too_many_requests"),
                error.Shutdown => beam.make_error_atom(env, "shutdown"),
                error.OutOfMemory => beam.make_error_atom(env, "out_of_memory"),
            };
        }
    }.submit_fn;
}

fn submit(
    comptime operation: tb_client.tb_operation_t,
    env: beam.Env,
    client_resource: ClientResource,
    payload_resource: BatchResource(OperationBatchItemType(operation)),
) SubmitError!beam.Term {
    const Item = OperationBatchItemType(operation);
    const client = client_resource.value();
    const payload = payload_resource.ptr_const();

    var out_packet: ?*tb_client.tb_packet_t = undefined;
    const status = tb_client.acquire_packet(client, &out_packet);
    const packet = switch (status) {
        .ok => if (out_packet) |pkt| pkt else @panic("acquire packet returned null"),
        .concurrency_max_exceeded => return error.TooManyRequests,
        .shutdown => return error.Shutdown,
    };
    errdefer tb_client.release_packet(client, packet);

    var ctx: *RequestContext = try beam.general_purpose_allocator.create(RequestContext);

    // We're calling this from a process bound env so we expect not to fail
    ctx.caller_pid = process.self(env) catch unreachable;

    const ref = beam.make_ref(env);
    // We serialize the reference to binary since we would need an env created in
    // TigerBeetle's thread to copy the ref into, but we don't have it and don't
    // have any way to create it from this side, pass it to the completion function
    // and free it
    ctx.request_ref_binary = try beam.term_to_binary(env, ref);

    // We increase the reference count on the payload resource so it doesn't get garbage
    // collected until we release it
    payload_resource.keep();

    // We save the raw pointer in the context so we can release it later
    ctx.payload_raw_obj = payload_resource.raw_ptr;

    packet.operation = @intFromEnum(operation);
    packet.data = payload.items.ptr;
    packet.data_size = @sizeOf(Item) * payload.len;
    packet.user_data = ctx;
    packet.status = .ok;

    tb_client.submit(client, packet);

    return beam.make_ok_term(env, ref);
}

fn on_completion(
    context: usize,
    client: tb_client.tb_client_t,
    packet: *tb_client.tb_packet_t,
    result_ptr: ?[*]const u8,
    result_len: u32,
) callconv(.C) void {
    var ctx: *RequestContext = @ptrCast(@alignCast(packet.user_data.?));
    defer beam.general_purpose_allocator.destroy(ctx);

    // We don't need the payload anymore, let the garbage collector take care of it
    resource.raw_release(ctx.payload_raw_obj);

    const env: beam.Env = @ptrFromInt(context);
    defer beam.clear_env(env);

    var ref_binary = ctx.request_ref_binary;
    defer ref_binary.release();
    const ref = ref_binary.to_term(env) catch unreachable;

    const caller_pid = ctx.caller_pid;

    const status = beam.make_u8(env, @intFromEnum(packet.status));
    const operation = beam.make_u8(env, packet.operation);
    const result = if (result_ptr) |p|
        beam.make_slice(env, p[0..result_len])
    else
        beam.make_nil(env);

    const response = beam.make_tuple(env, .{ status, operation, result });
    const tag = beam.make_atom(env, "tigerbeetlex_response");
    const msg = beam.make_tuple(env, .{ tag, ref, response });

    // We're done with the packet, put it back in the pool
    tb_client.release_packet(client, packet);

    // Send the result to the caller
    process.send(caller_pid, env, msg) catch unreachable;
}

fn client_resource_deinit_fn(_: beam.Env, ptr: ?*anyopaque) callconv(.C) void {
    if (ptr) |p| {
        const cl: *Client = @ptrCast(@alignCast(p));
        // TODO: this can now potentially block for a long time since it waits
        // for all the requests to be drained, investigate what it is blocking
        // and if this needs to be done in a separate thread
        tb_client.deinit(cl.*);
    } else unreachable;
}
