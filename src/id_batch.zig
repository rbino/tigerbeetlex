const std = @import("std");
const assert = std.debug.assert;

const batch = @import("batch.zig");
const beam = @import("beam.zig");
const scheduler = beam.scheduler;

pub const IdBatch = batch.Batch(u128);
pub const IdBatchResource = batch.BatchResource(u128);

pub fn create(env: beam.Env, capacity: u32) beam.Term {
    return batch.create(u128, env, capacity) catch |err| switch (err) {
        error.OutOfMemory => return beam.make_error_atom(env, "out_of_memory"),
    };
}

pub fn append(env: beam.Env, id_batch_resource: IdBatchResource, id: u128) !beam.Term {
    const id_batch = id_batch_resource.ptr();

    {
        if (!id_batch.lock.tryLock()) {
            return error.Yield;
        }
        defer id_batch.lock.unlock();

        if (id_batch.len + 1 > id_batch.items.len) {
            return beam.make_error_atom(env, "batch_full");
        }
        id_batch.len += 1;
        id_batch.items[id_batch.len - 1] = id;
    }

    return beam.make_ok(env);
}

pub fn fetch(
    env: beam.Env,
    id_batch_resource: IdBatchResource,
    idx: u32,
) !beam.Term {
    return batch.fetch(
        u128,
        env,
        id_batch_resource,
        idx,
    ) catch |err| switch (err) {
        error.OutOfBounds => beam.make_error_atom(env, "out_of_bounds"),
        error.LockFailed => return error.Yield,
    };
}

pub fn replace(
    env: beam.Env,
    id_batch_resource: IdBatchResource,
    idx: u32,
    id: u128,
) !beam.Term {
    const id_batch = id_batch_resource.ptr();

    {
        if (!id_batch.lock.tryLock()) {
            return error.Yield;
        }
        defer id_batch.lock.unlock();

        if (idx >= id_batch.len) {
            return beam.make_error_atom(env, "out_of_bounds");
        }

        id_batch.items[idx] = id;
    }

    return beam.make_ok(env);
}
