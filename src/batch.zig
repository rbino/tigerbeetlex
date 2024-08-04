const std = @import("std");
const RwLock = std.Thread.RwLock;

const beam = @import("beam.zig");
const Resource = beam.resource.Resource;

const tb = @import("tigerbeetle/src/tigerbeetle.zig");
const Account = tb.Account;
const Transfer = tb.Transfer;

pub fn Batch(comptime Item: anytype) type {
    return struct {
        lock: RwLock = .{},
        items: []Item,
        len: u32,
    };
}

pub fn BatchResource(comptime Item: anytype) type {
    return Resource(Batch(Item), batch_resource_deinit_fn(Batch(Item)));
}

pub fn create(comptime Item: anytype, env: beam.Env, capacity: u32) !beam.Term {
    const items = try beam.general_purpose_allocator.alloc(Item, capacity);
    const batch = Batch(Item){
        .items = items,
        .len = 0,
    };
    const batch_resource = try BatchResource(Item).init(batch);
    const term_handle = batch_resource.term_handle(env);
    batch_resource.release();

    return beam.make_ok_term(env, term_handle);
}

pub fn append(
    comptime Item: anytype,
    env: beam.Env,
    batch_resource: BatchResource(Item),
    item_bytes: []const u8,
) !beam.Term {
    const batch = batch_resource.ptr();

    {
        if (!batch.lock.tryLock()) {
            return error.LockFailed;
        }
        defer batch.lock.unlock();
        if (batch.len + 1 > batch.items.len) {
            return error.BatchFull;
        }
        batch.len += 1;

        // We need to pass the item as bytes and copy it with @memcpy
        // because we can't enforce a specifi alignment to the underlying
        // ErlNifBinary, which becomes our slice of bytes

        // Get a pointer to the memory backing the newly inserted item
        const new_batch_item_bytes = std.mem.asBytes(&batch.items[batch.len - 1]);
        // Fill it with the input item bytes
        @memcpy(new_batch_item_bytes, item_bytes);
    }

    return beam.make_ok(env);
}

pub fn fetch(
    comptime Item: anytype,
    env: beam.Env,
    batch_resource: BatchResource(Item),
    idx: u32,
) !beam.Term {
    const batch = batch_resource.ptr();

    {
        if (!batch.lock.tryLockShared()) {
            return error.LockFailed;
        }
        defer batch.lock.unlockShared();
        if (idx >= batch.len) {
            return error.OutOfBounds;
        }
        const batch_item_bytes = std.mem.asBytes(&batch.items[idx]);
        const batch_item_binary = beam.make_slice(env, batch_item_bytes);

        return beam.make_ok_term(env, batch_item_binary);
    }
}

pub fn replace(
    comptime Item: anytype,
    env: beam.Env,
    batch_resource: BatchResource(Item),
    idx: u32,
    replacement_item_bytes: []const u8,
) !beam.Term {
    const batch = batch_resource.ptr();

    {
        if (!batch.lock.tryLock()) {
            return error.LockFailed;
        }
        defer batch.lock.unlock();

        if (idx >= batch.len) {
            return error.OutOfBounds;
        }

        // We need to pass the item as bytes and copy it with @memcpy
        // because we can't enforce a specific alignment to the underlying
        // ErlNifBinary, which becomes our slice of bytes

        // Get a pointer to the memory backing the newly inserted item
        const batch_item_bytes = std.mem.asBytes(&batch.items[idx]);
        // Fill it with the input item bytes
        @memcpy(batch_item_bytes, replacement_item_bytes);
    }

    return beam.make_ok(env);
}

fn batch_resource_deinit_fn(
    comptime Item: anytype,
) fn (env: beam.Env, ptr: ?*anyopaque) callconv(.C) void {
    return struct {
        fn deinit_fn(_: beam.Env, ptr: ?*anyopaque) callconv(.C) void {
            if (ptr) |p| {
                const batch: *Item = @ptrCast(@alignCast(p));
                beam.general_purpose_allocator.free(batch.items);
            } else unreachable;
        }
    }.deinit_fn;
}
