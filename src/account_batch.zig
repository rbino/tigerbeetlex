const std = @import("std");
const assert = std.debug.assert;

const batch = @import("batch.zig");
const beam = @import("beam.zig");
const scheduler = beam.scheduler;

const tb = @import("tigerbeetle");
const Account = tb.Account;
const AccountFlags = tb.AccountFlags;
pub const AccountBatch = batch.Batch(Account);
pub const AccountBatchResource = batch.BatchResource(Account);

pub fn create(env: beam.Env, capacity: u32) beam.Term {
    return batch.create(Account, env, capacity) catch |err| switch (err) {
        error.OutOfMemory => return beam.make_error_atom(env, "out_of_memory"),
    };
}

pub fn append(
    env: beam.Env,
    account_batch_resource: AccountBatchResource,
    account_bytes: []const u8,
) !beam.Term {
    if (account_bytes.len != @sizeOf(Account)) return beam.raise_badarg(env);

    return batch.append(
        Account,
        env,
        account_batch_resource,
        account_bytes,
    ) catch |err| switch (err) {
        error.BatchFull => beam.make_error_atom(env, "batch_full"),
        error.LockFailed => return error.Yield,
    };
}

pub fn fetch(
    env: beam.Env,
    account_batch_resource: AccountBatchResource,
    idx: u32,
) !beam.Term {
    return batch.fetch(
        Account,
        env,
        account_batch_resource,
        idx,
    ) catch |err| switch (err) {
        error.OutOfBounds => beam.make_error_atom(env, "out_of_bounds"),
        error.LockFailed => return error.Yield,
    };
}

pub fn replace(
    env: beam.Env,
    account_batch_resource: AccountBatchResource,
    idx: u32,
    account_bytes: []const u8,
) !beam.Term {
    return batch.replace(
        Account,
        env,
        account_batch_resource,
        idx,
        account_bytes,
    ) catch |err| switch (err) {
        error.OutOfBounds => beam.make_error_atom(env, "out_of_bounds"),
        error.LockFailed => return error.Yield,
    };
}
