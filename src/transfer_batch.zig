const std = @import("std");

const batch = @import("batch.zig");
const beam = @import("beam");
const beam_extras = @import("beam_extras.zig");
const e = @import("erl_nif");
const resource_types = @import("resource_types.zig");

const tb = @import("tigerbeetle");
const Transfer = tb.Transfer;
const TransferFlags = tb.TransferFlags;
pub const TransferBatch = batch.Batch(Transfer);

pub fn create(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
    if (argc != 1) unreachable;

    const args = @ptrCast([*]const beam.term, argv)[0..@intCast(usize, argc)];

    const capacity: u32 = beam.get_u32(env, args[0]) catch
        return beam.raise_function_clause_error(env);

    return batch.create(Transfer, env, capacity);
}

pub fn add_transfer(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
    if (argc != 1) unreachable;

    const args = @ptrCast([*]const beam.term, argv)[0..@intCast(usize, argc)];

    return batch.add_item(Transfer, env, args[0]) catch |err| switch (err) {
        error.MutexLocked => return e.enif_schedule_nif(env, "add_transfer", 0, add_transfer, argc, argv),
    };
}

fn set_transfer_field(
    comptime field: std.meta.FieldEnum(Transfer),
    env: beam.env,
    argc: c_int,
    argv: [*c]const beam.term,
) !beam.term {
    if (argc != 3) unreachable;

    const args = @ptrCast([*]const beam.term, argv)[0..@intCast(usize, argc)];

    const transfer_batch = beam_extras.resource_ptr(TransferBatch, env, resource_types.transfer_batch, args[0]) catch |err|
        switch (err) {
        error.FetchError => return beam.make_error_atom(env, "invalid_batch"),
    };

    const idx: u32 = beam.get_u32(env, args[1]) catch
        return beam.raise_function_clause_error(env);

    {
        if (!transfer_batch.mutex.tryLock()) {
            return error.MutexLocked;
        }
        defer transfer_batch.mutex.unlock();

        if (idx >= transfer_batch.len) {
            return beam.make_error_atom(env, "out_of_bounds");
        }

        const transfer: *Transfer = &transfer_batch.items[idx];

        switch (field) {
            .id => {
                const id = beam_extras.get_u128(env, args[2]) catch
                    return beam.raise_function_clause_error(env);

                transfer.id = id;
            },
            .debit_account_id => {
                const debit_account_id = beam_extras.get_u128(env, args[2]) catch
                    return beam.raise_function_clause_error(env);

                transfer.debit_account_id = debit_account_id;
            },
            .credit_account_id => {
                const credit_account_id = beam_extras.get_u128(env, args[2]) catch
                    return beam.raise_function_clause_error(env);

                transfer.credit_account_id = credit_account_id;
            },
            .user_data => {
                const user_data = beam_extras.get_u128(env, args[2]) catch
                    return beam.raise_function_clause_error(env);

                transfer.user_data = user_data;
            },
            .pending_id => {
                const pending_id = beam_extras.get_u128(env, args[2]) catch
                    return beam.raise_function_clause_error(env);

                transfer.pending_id = pending_id;
            },
            .timeout => {
                const timeout = beam.get_u64(env, args[2]) catch
                    return beam.raise_function_clause_error(env);

                transfer.timeout = timeout;
            },
            .ledger => {
                const ledger = beam.get_u32(env, args[2]) catch
                    return beam.raise_function_clause_error(env);

                transfer.ledger = ledger;
            },
            .code => {
                const code = beam.get_u16(env, args[2]) catch
                    return beam.raise_function_clause_error(env);

                transfer.code = code;
            },
            .flags => {
                const flags_uint = beam.get_u16(env, args[2]) catch
                    return beam.raise_function_clause_error(env);

                const flags: TransferFlags = @bitCast(TransferFlags, flags_uint);

                transfer.flags = flags;
            },
            .amount => {
                const amount = beam.get_u64(env, args[2]) catch
                    return beam.raise_function_clause_error(env);

                transfer.amount = amount;
            },
            else => unreachable,
        }
    }

    return beam.make_ok(env);
}

pub fn set_transfer_id(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
    return set_transfer_field(.id, env, argc, argv) catch |err| switch (err) {
        error.MutexLocked => return e.enif_schedule_nif(env, "set_transfer_id", 0, set_transfer_id, argc, argv),
    };
}

pub fn set_transfer_debit_account_id(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
    return set_transfer_field(.debit_account_id, env, argc, argv) catch |err| switch (err) {
        error.MutexLocked => return e.enif_schedule_nif(env, "set_transfer_debit_account_id", 0, set_transfer_debit_account_id, argc, argv),
    };
}

pub fn set_transfer_credit_account_id(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
    return set_transfer_field(.credit_account_id, env, argc, argv) catch |err| switch (err) {
        error.MutexLocked => return e.enif_schedule_nif(env, "set_transfer_credit_account_id", 0, set_transfer_credit_account_id, argc, argv),
    };
}

pub fn set_transfer_user_data(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
    return set_transfer_field(.user_data, env, argc, argv) catch |err| switch (err) {
        error.MutexLocked => return e.enif_schedule_nif(env, "set_transfer_user_data", 0, set_transfer_user_data, argc, argv),
    };
}

pub fn set_transfer_pending_id(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
    return set_transfer_field(.pending_id, env, argc, argv) catch |err| switch (err) {
        error.MutexLocked => return e.enif_schedule_nif(env, "set_transfer_pending_id", 0, set_transfer_pending_id, argc, argv),
    };
}

pub fn set_transfer_timeout(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
    return set_transfer_field(.timeout, env, argc, argv) catch |err| switch (err) {
        error.MutexLocked => return e.enif_schedule_nif(env, "set_transfer_timeout", 0, set_transfer_timeout, argc, argv),
    };
}

pub fn set_transfer_ledger(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
    return set_transfer_field(.ledger, env, argc, argv) catch |err| switch (err) {
        error.MutexLocked => return e.enif_schedule_nif(env, "set_transfer_ledger", 0, set_transfer_ledger, argc, argv),
    };
}

pub fn set_transfer_code(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
    return set_transfer_field(.code, env, argc, argv) catch |err| switch (err) {
        error.MutexLocked => return e.enif_schedule_nif(env, "set_transfer_code", 0, set_transfer_code, argc, argv),
    };
}

pub fn set_transfer_flags(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
    return set_transfer_field(.flags, env, argc, argv) catch |err| switch (err) {
        error.MutexLocked => return e.enif_schedule_nif(env, "set_transfer_flags", 0, set_transfer_flags, argc, argv),
    };
}

pub fn set_transfer_amount(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
    return set_transfer_field(.amount, env, argc, argv) catch |err| switch (err) {
        error.MutexLocked => return e.enif_schedule_nif(env, "set_transfer_amount", 0, set_transfer_amount, argc, argv),
    };
}
