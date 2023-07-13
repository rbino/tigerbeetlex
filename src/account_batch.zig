const std = @import("std");
const assert = std.debug.assert;

const batch = @import("batch.zig");
const beam = @import("beam");
const beam_extras = @import("beam_extras.zig");
const e = @import("erl_nif");

const tb = @import("tigerbeetle");
const Account = tb.Account;
const AccountFlags = tb.AccountFlags;
pub const AccountBatch = batch.Batch(Account);
pub const AccountBatchResource = batch.BatchResource(Account);

pub fn create(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
    assert(argc == 1);

    const args = @ptrCast([*]const beam.term, argv)[0..@intCast(usize, argc)];

    const capacity: u32 = beam.get_u32(env, args[0]) catch
        return beam.raise_function_clause_error(env);

    return batch.create(Account, env, capacity);
}

pub fn add_account(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
    assert(argc == 1);

    const args = @ptrCast([*]const beam.term, argv)[0..@intCast(usize, argc)];

    return batch.add_item(Account, env, args[0]) catch |err| switch (err) {
        error.MutexLocked => return e.enif_schedule_nif(env, "add_account", 0, add_account, argc, argv),
    };
}

pub const set_account_id = field_setter_fn(.id);
pub const set_account_user_data = field_setter_fn(.user_data);
pub const set_account_ledger = field_setter_fn(.ledger);
pub const set_account_code = field_setter_fn(.code);
pub const set_account_flags = field_setter_fn(.flags);

fn field_setter_fn(comptime field: std.meta.FieldEnum(Account)) fn (
    beam.env,
    c_int,
    [*c]const beam.term,
) callconv(.C) beam.term {
    const field_name = @tagName(field);
    const setter_name = "set_account_" ++ field_name;

    return struct {
        fn setter_fn(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
            assert(argc == 3);

            const args = @ptrCast([*]const beam.term, argv)[0..@intCast(usize, argc)];

            const batch_term = args[0];
            const account_batch_resource = AccountBatchResource.from_term_handle(env, batch_term) catch |err|
                switch (err) {
                error.InvalidResourceTerm => return beam.make_error_atom(env, "invalid_batch"),
            };
            const account_batch = account_batch_resource.ptr();

            const idx: u32 = beam.get_u32(env, args[1]) catch
                return beam.raise_function_clause_error(env);

            const term_to_value = term_to_value_fn(field);
            const new_value = term_to_value(env, args[2]) catch
                return beam.raise_function_clause_error(env);

            {
                if (!account_batch.mutex.tryLock()) {
                    return e.enif_schedule_nif(env, setter_name, 0, setter_fn, argc, argv);
                }
                defer account_batch.mutex.unlock();

                if (idx >= account_batch.len) {
                    return beam.make_error_atom(env, "out_of_bounds");
                }

                const account: *Account = &account_batch.items[idx];

                @field(account, field_name) = new_value;
            }

            return beam.make_ok(env);
        }
    }.setter_fn;
}

fn term_to_value_fn(
    comptime field: std.meta.FieldEnum(Account),
) fn (beam.env, beam.term) beam.Error!std.meta.fieldInfo(Account, field).field_type {
    return switch (field) {
        .id, .user_data => beam_extras.get_u128,
        .ledger => beam.get_u32,
        .code => beam.get_u16,
        .flags => term_to_account_flags,
        else => unreachable,
    };
}

fn term_to_account_flags(env: beam.env, term: beam.term) beam.Error!AccountFlags {
    const flags_uint = beam.get_u16(env, term) catch
        return beam.Error.FunctionClauseError;

    return @bitCast(AccountFlags, flags_uint);
}
