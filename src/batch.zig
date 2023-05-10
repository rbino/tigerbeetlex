const std = @import("std");

const beam = @import("beam");
const beam_extras = @import("beam_extras.zig");
const resource = beam.resource;
const resource_types = @import("resource_types.zig");

const tb = @import("tigerbeetle");
const Account = tb.Account;
const Transfer = tb.Transfer;

pub const AccountBatch = Batch(Account);
pub const TransferBatch = Batch(Transfer);

pub fn Batch(comptime T: anytype) type {
    return struct {
        items: []T,
        len: u32,
    };
}

pub fn create(comptime T: anytype, env: beam.env, capacity: u32) beam.term {
    const items = beam.general_purpose_allocator.alloc(T, capacity) catch |err|
        switch (err) {
        error.OutOfMemory => return beam.make_error_atom(env, "out_of_memory"),
    };

    const resource_type = resource_types.from_batch_type(T);

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

pub fn add_item(comptime T: anytype, env: beam.env, batch_term: beam.term) beam.term {
    const resource_type = resource_types.from_batch_type(T);
    const batch = beam_extras.resource_ptr(Batch(T), env, resource_type, batch_term) catch |err|
        switch (err) {
        error.FetchError => return beam.make_error_atom(env, "invalid_batch"),
    };

    if (batch.len + 1 > batch.items.len) {
        return beam.make_error_atom(env, "batch_full");
    }
    batch.len += 1;
    batch.items[batch.len - 1] = std.mem.zeroInit(T, .{});

    return beam.make_ok(env);
}
