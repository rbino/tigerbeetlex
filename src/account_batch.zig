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

pub fn add_account(env: beam.Env, account_batch_resource: AccountBatchResource) !beam.Term {
    return batch.add_item(Account, env, account_batch_resource) catch |err| switch (err) {
        error.BatchFull => beam.make_error_atom(env, "batch_full"),
        error.MutexLocked => return error.Yield,
    };
}

// These are all comptime generated functions
pub const set_account_id = batch.get_item_field_setter_fn(Account, .id);
pub const set_account_user_data = batch.get_item_field_setter_fn(Account, .user_data);
pub const set_account_ledger = batch.get_item_field_setter_fn(Account, .ledger);
pub const set_account_code = batch.get_item_field_setter_fn(Account, .code);

// set_account_flags must be handled separately since we have to cast the u16
// value to a AccountFlags struct
pub fn set_account_flags(
    env: beam.Env,
    account_batch_resource: AccountBatchResource,
    idx: u32,
    flags_uint: u16,
) !beam.Term {
    const flags = @bitCast(AccountFlags, flags_uint);
    return batch.set_item_field(Account, .flags, env, account_batch_resource, idx, flags);
}
