const beam = @import("beam");

const tb = @import("tigerbeetle");
const tb_client = @import("tigerbeetle/src/clients/c/tb_client.zig");
const Account = tb.Account;
const Client = @import("client.zig").Client;
const Transfer = tb.Transfer;

// The resource type for the client
pub var client: beam.resource_type = undefined;

// The resource type for the account batch
pub var account_batch: beam.resource_type = undefined;

// The resource type for an ID batch
pub var id_batch: beam.resource_type = undefined;

// The resource type for the transfer batch
pub var transfer_batch: beam.resource_type = undefined;

pub fn from_batch_type(comptime T: anytype) beam.resource_type {
    return switch (T) {
        Account => account_batch,
        u128 => id_batch,
        Transfer => transfer_batch,
        else => unreachable,
    };
}

pub fn client_deinit_fn(_: beam.env, ptr: ?*anyopaque) callconv(.C) void {
    if (ptr) |p| {
        const cl: *Client = @ptrCast(*Client, @alignCast(@alignOf(*Client), p));
        // TODO: this can now potentially block for a long time since it waits
        // for all the requests to be drained, investigate what it is blocking
        // and if this needs to be done in a separate thread
        tb_client.deinit(cl.zig_client);
    } else unreachable;
}

pub fn batch_deinit_fn(comptime T: anytype) fn (env: beam.env, ptr: ?*anyopaque) callconv(.C) void {
    return struct {
        fn deinit_fn(_: beam.env, ptr: ?*anyopaque) callconv(.C) void {
            if (ptr) |p| {
                const b: *T = @ptrCast(*T, @alignCast(@alignOf(*T), p));
                beam.general_purpose_allocator.free(b.items);
            } else unreachable;
        }
    }.deinit_fn;
}
