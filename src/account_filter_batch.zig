const std = @import("std");
const assert = std.debug.assert;

const batch = @import("batch.zig");
const beam = @import("beam.zig");
const scheduler = beam.scheduler;

const tb = @import("vsr").tigerbeetle;
const AccountFilter = tb.AccountFilter;
pub const AccountFilterBatch = batch.Batch(AccountFilter);
pub const AccountFilterBatchResource = batch.BatchResource(AccountFilter);

pub fn create(env: beam.Env, capacity: u32) beam.Term {
    return batch.create(AccountFilter, env, capacity) catch |err| switch (err) {
        error.OutOfMemory => return beam.make_error_atom(env, "out_of_memory"),
    };
}

pub fn append(
    env: beam.Env,
    transfer_batch_resource: AccountFilterBatchResource,
    transfer_bytes: []const u8,
) !beam.Term {
    if (transfer_bytes.len != @sizeOf(AccountFilter)) return beam.raise_badarg(env);

    return batch.append(
        AccountFilter,
        env,
        transfer_batch_resource,
        transfer_bytes,
    ) catch |err| switch (err) {
        error.BatchFull => beam.make_error_atom(env, "batch_full"),
        error.LockFailed => return error.Yield,
    };
}
