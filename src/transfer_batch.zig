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

pub fn add_transfer(env: beam.Env, transfer_batch_resource: TransferBatchResource) !beam.Term {
    return batch.add_item(Transfer, env, transfer_batch_resource) catch |err| switch (err) {
        error.BatchFull => beam.make_error_atom(env, "batch_full"),
        error.MutexLocked => return error.Yield,
    };
}

// These are all comptime generated functions
pub const set_transfer_id = batch.get_item_field_setter_fn(Transfer, .id);
pub const set_transfer_debit_account_id = batch.get_item_field_setter_fn(Transfer, .debit_account_id);
pub const set_transfer_credit_account_id = batch.get_item_field_setter_fn(Transfer, .credit_account_id);
pub const set_transfer_user_data = batch.get_item_field_setter_fn(Transfer, .user_data);
pub const set_transfer_pending_id = batch.get_item_field_setter_fn(Transfer, .pending_id);
pub const set_transfer_timeout = batch.get_item_field_setter_fn(Transfer, .timeout);
pub const set_transfer_ledger = batch.get_item_field_setter_fn(Transfer, .ledger);
pub const set_transfer_code = batch.get_item_field_setter_fn(Transfer, .code);
pub const set_transfer_amount = batch.get_item_field_setter_fn(Transfer, .amount);

// set_transfer_flags must be handled separately since we have to cast the u16
// value to a TransferFlags struct
pub fn set_transfer_flags(
    env: beam.Env,
    transfer_batch_resource: TransferBatchResource,
    idx: u32,
    flags_uint: u16,
) !beam.Term {
    const flags = @bitCast(TransferFlags, flags_uint);
    return batch.set_item_field(Transfer, .flags, env, transfer_batch_resource, idx, flags);
}
