const std = @import("std");
const assert = std.debug.assert;

const batch = @import("batch.zig");
const beam = @import("beam.zig");
const scheduler = beam.scheduler;

const tb = @import("tigerbeetle");
const Transfer = tb.Transfer;
const TransferFlags = tb.TransferFlags;
pub const TransferBatch = batch.Batch(Transfer);
pub const TransferBatchResource = batch.BatchResource(Transfer);

pub fn create(env: beam.Env, capacity: u32) beam.Term {
    return batch.create(Transfer, env, capacity) catch |err| switch (err) {
        error.OutOfMemory => return beam.make_error_atom(env, "out_of_memory"),
    };
}

pub fn append(
    env: beam.Env,
    transfer_batch_resource: TransferBatchResource,
    transfer_bytes: []const u8,
) !beam.Term {
    if (transfer_bytes.len != @sizeOf(Transfer)) return beam.raise_badarg(env);

    return batch.append(
        Transfer,
        env,
        transfer_batch_resource,
        transfer_bytes,
    ) catch |err| switch (err) {
        error.BatchFull => beam.make_error_atom(env, "batch_full"),
        error.MutexLocked => return error.Yield,
    };
}
