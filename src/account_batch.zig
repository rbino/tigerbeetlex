const std = @import("std");

const batch = @import("batch.zig");
const beam = @import("beam");
const beam_extras = @import("beam_extras.zig");
const e = @import("erl_nif");
const resource_types = @import("resource_types.zig");

const tb = @import("tigerbeetle");
const Account = tb.Account;
const AccountFlags = tb.AccountFlags;
pub const AccountBatch = batch.Batch(Account);

pub fn create(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
    if (argc != 1) unreachable;

    const args = @ptrCast([*]const beam.term, argv)[0..@intCast(usize, argc)];

    const capacity: u32 = beam.get_u32(env, args[0]) catch
        return beam.raise_function_clause_error(env);

    return batch.create(Account, env, capacity);
}

pub fn add_account(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
    if (argc != 1) unreachable;

    const args = @ptrCast([*]const beam.term, argv)[0..@intCast(usize, argc)];

    return batch.add_item(Account, env, args[0]) catch |err| switch (err) {
        error.MutexLocked => return e.enif_schedule_nif(env, "add_account", 0, add_account, argc, argv),
    };
}

fn set_account_field(
    comptime field: std.meta.FieldEnum(Account),
    env: beam.env,
    argc: c_int,
    argv: [*c]const beam.term,
) !beam.term {
    if (argc != 3) unreachable;

    const args = @ptrCast([*]const beam.term, argv)[0..@intCast(usize, argc)];

    const account_batch = beam_extras.resource_ptr(AccountBatch, env, resource_types.account_batch, args[0]) catch |err|
        switch (err) {
        error.FetchError => return beam.make_error_atom(env, "invalid_batch"),
    };

    const idx: u32 = beam.get_u32(env, args[1]) catch
        return beam.raise_function_clause_error(env);

    {
        if (!account_batch.mutex.tryLock()) {
            return error.MutexLocked;
        }
        defer account_batch.mutex.unlock();

        if (idx >= account_batch.len) {
            return beam.make_error_atom(env, "out_of_bounds");
        }

        const account: *Account = &account_batch.items[idx];

        switch (field) {
            .id => {
                const id = beam_extras.get_u128(env, args[2]) catch
                    return beam.raise_function_clause_error(env);

                account.id = id;
            },
            .user_data => {
                const user_data = beam_extras.get_u128(env, args[2]) catch
                    return beam.raise_function_clause_error(env);

                account.user_data = user_data;
            },
            .ledger => {
                const ledger = beam.get_u32(env, args[2]) catch
                    return beam.raise_function_clause_error(env);

                account.ledger = ledger;
            },
            .code => {
                const code = beam.get_u16(env, args[2]) catch
                    return beam.raise_function_clause_error(env);

                account.code = code;
            },
            .flags => {
                const flags_uint = beam.get_u16(env, args[2]) catch
                    return beam.raise_function_clause_error(env);

                const flags: AccountFlags = @bitCast(AccountFlags, flags_uint);

                account.flags = flags;
            },
            else => unreachable,
        }
    }

    return beam.make_ok(env);
}

pub fn set_account_id(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
    return set_account_field(.id, env, argc, argv) catch |err| switch (err) {
        error.MutexLocked => return e.enif_schedule_nif(env, "set_account_id", 0, set_account_id, argc, argv),
    };
}

pub fn set_account_user_data(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
    return set_account_field(.user_data, env, argc, argv) catch |err| switch (err) {
        error.MutexLocked => return e.enif_schedule_nif(env, "set_account_user_data", 0, set_account_user_data, argc, argv),
    };
}

pub fn set_account_ledger(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
    return set_account_field(.ledger, env, argc, argv) catch |err| switch (err) {
        error.MutexLocked => return e.enif_schedule_nif(env, "set_account_ledger", 0, set_account_ledger, argc, argv),
    };
}

pub fn set_account_code(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
    return set_account_field(.code, env, argc, argv) catch |err| switch (err) {
        error.MutexLocked => return e.enif_schedule_nif(env, "set_account_code", 0, set_account_code, argc, argv),
    };
}

pub fn set_account_flags(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
    return set_account_field(.flags, env, argc, argv) catch |err| switch (err) {
        error.MutexLocked => return e.enif_schedule_nif(env, "set_account_flags", 0, set_account_flags, argc, argv),
    };
}
