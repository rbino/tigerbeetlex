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

pub fn create(env: beam.Env, argc: c_int, argv: [*c]const beam.Term) callconv(.C) beam.Term {
    assert(argc == 1);

    const args = @ptrCast([*]const beam.Term, argv)[0..@intCast(usize, argc)];

    const capacity: u32 = beam.get_u32(env, args[0]) catch
        return beam.raise_function_clause_error(env);

    return batch.create(Transfer, env, capacity);
}

pub fn add_transfer(env: beam.Env, argc: c_int, argv: [*c]const beam.Term) callconv(.C) beam.Term {
    assert(argc == 1);

    const args = @ptrCast([*]const beam.Term, argv)[0..@intCast(usize, argc)];

    return batch.add_item(Transfer, env, args[0]) catch |err| switch (err) {
        error.MutexLocked => return scheduler.reschedule(env, "add_transfer", add_transfer, argc, argv),
    };
}

pub const set_transfer_id = field_setter_fn(.id);
pub const set_transfer_debit_account_id = field_setter_fn(.debit_account_id);
pub const set_transfer_credit_account_id = field_setter_fn(.credit_account_id);
pub const set_transfer_user_data = field_setter_fn(.user_data);
pub const set_transfer_pending_id = field_setter_fn(.pending_id);
pub const set_transfer_timeout = field_setter_fn(.timeout);
pub const set_transfer_ledger = field_setter_fn(.ledger);
pub const set_transfer_code = field_setter_fn(.code);
pub const set_transfer_flags = field_setter_fn(.flags);
pub const set_transfer_amount = field_setter_fn(.amount);

fn field_setter_fn(comptime field: std.meta.FieldEnum(Transfer)) fn (
    beam.Env,
    c_int,
    [*c]const beam.Term,
) callconv(.C) beam.Term {
    const field_name = @tagName(field);
    const setter_name = "set_transfer_" ++ field_name;

    return struct {
        fn setter_fn(env: beam.Env, argc: c_int, argv: [*c]const beam.Term) callconv(.C) beam.Term {
            assert(argc == 3);

            const args = @ptrCast([*]const beam.Term, argv)[0..@intCast(usize, argc)];

            const batch_term = args[0];
            const transfer_batch_resource = TransferBatchResource.from_term_handle(env, batch_term) catch |err|
                switch (err) {
                error.InvalidResourceTerm => return beam.make_error_atom(env, "invalid_batch"),
            };
            const transfer_batch = transfer_batch_resource.ptr();

            const idx: u32 = beam.get_u32(env, args[1]) catch
                return beam.raise_function_clause_error(env);

            const term_to_value = term_to_value_fn(field);
            const new_value = term_to_value(env, args[2]) catch
                return beam.raise_function_clause_error(env);

            {
                if (!transfer_batch.mutex.tryLock()) {
                    return scheduler.reschedule(env, setter_name, add_transfer, argc, argv);
                }
                defer transfer_batch.mutex.unlock();

                if (idx >= transfer_batch.len) {
                    return beam.make_error_atom(env, "out_of_bounds");
                }

                const transfer: *Transfer = &transfer_batch.items[idx];

                @field(transfer, field_name) = new_value;
            }

            return beam.make_ok(env);
        }
    }.setter_fn;
}

fn term_to_value_fn(
    comptime field: std.meta.FieldEnum(Transfer),
) fn (beam.Env, beam.Term) beam.GetError!std.meta.fieldInfo(Transfer, field).field_type {
    return switch (field) {
        .id, .debit_account_id, .credit_account_id, .user_data, .pending_id => beam.get_u128,
        .timeout, .amount => beam.get_u64,
        .ledger => beam.get_u32,
        .code => beam.get_u16,
        .flags => term_to_transfer_flags,
        else => unreachable,
    };
}

fn term_to_transfer_flags(env: beam.Env, term: beam.Term) beam.GetError!TransferFlags {
    const flags_uint = beam.get_u16(env, term) catch
        return beam.GetError.ArgumentError;

    return @bitCast(TransferFlags, flags_uint);
}
