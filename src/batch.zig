const std = @import("std");
const Mutex = std.Thread.Mutex;

const beam = @import("beam");
const beam_extras = @import("beam_extras.zig");
const e = @import("erl_nif");
const Resource = @import("resource.zig").Resource;

const tb = @import("tigerbeetle");
const Account = tb.Account;
const Transfer = tb.Transfer;

pub fn Batch(comptime T: anytype) type {
    return struct {
        mutex: Mutex = .{},
        items: []T,
        len: u32,
    };
}

pub fn create(comptime T: anytype, env: beam.env, capacity: u32) beam.term {
    const items = beam.general_purpose_allocator.alloc(T, capacity) catch |err|
        switch (err) {
        error.OutOfMemory => return beam.make_error_atom(env, "out_of_memory"),
    };

    const batch = Batch(T){
        .items = items,
        .len = 0,
    };

    const batch_resource = BatchResource(T).init(batch) catch |err|
        switch (err) {
        error.OutOfMemory => return beam.make_error_atom(env, "out_of_memory"),
    };
    const term_handle = batch_resource.term_handle(env);
    batch_resource.release();

    return beam.make_ok_term(env, term_handle);
}

pub fn add_item(comptime T: anytype, env: beam.env, batch_term: beam.term) !beam.term {
    const batch_resource = BatchResource(T).from_term_handle(env, batch_term) catch |err|
        switch (err) {
        error.InvalidResourceTerm => return beam.make_error_atom(env, "invalid_batch"),
    };
    const batch = batch_resource.ptr();

    {
        if (!batch.mutex.tryLock()) {
            return error.MutexLocked;
        }
        defer batch.mutex.unlock();
        if (batch.len + 1 > batch.items.len) {
            return beam.make_error_atom(env, "batch_full");
        }
        batch.len += 1;
        batch.items[batch.len - 1] = std.mem.zeroInit(T, .{});

        return beam.make_ok_term(env, beam.make_u32(env, batch.len));
    }
}

pub fn BatchResource(comptime T: anytype) type {
    return Resource(Batch(T), batch_resource_deinit_fn(Batch(T)));
}

fn batch_resource_deinit_fn(
    comptime T: anytype,
) fn (env: beam.env, ptr: ?*anyopaque) callconv(.C) void {
    return struct {
        fn deinit_fn(_: beam.env, ptr: ?*anyopaque) callconv(.C) void {
            if (ptr) |p| {
                const batch: *T = @ptrCast(*T, @alignCast(@alignOf(*T), p));
                beam.general_purpose_allocator.free(batch.items);
            } else unreachable;
        }
    }.deinit_fn;
}
