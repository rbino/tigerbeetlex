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

pub fn create(env: beam.Env, argc: c_int, argv: [*c]const beam.Term) callconv(.C) beam.Term {
    assert(argc == 1);

    const args = @ptrCast([*]const beam.Term, argv)[0..@intCast(usize, argc)];

    const capacity: u32 = beam.get_u32(env, args[0]) catch
        return beam.raise_function_clause_error(env);

    return batch.create(Account, env, capacity);
}

pub fn add_account(env: beam.Env, argc: c_int, argv: [*c]const beam.Term) callconv(.C) beam.Term {
    assert(argc == 1);

    const args = @ptrCast([*]const beam.Term, argv)[0..@intCast(usize, argc)];

    return batch.add_item(Account, env, args[0]) catch |err| switch (err) {
        error.MutexLocked => return scheduler.reschedule(env, "add_account", add_account, argc, argv),
    };
}

pub const set_account_id = field_setter_fn(.id);
pub const set_account_user_data = field_setter_fn(.user_data);
pub const set_account_ledger = field_setter_fn(.ledger);
pub const set_account_code = field_setter_fn(.code);
pub const set_account_flags = field_setter_fn(.flags);

fn field_setter_fn(comptime field: std.meta.FieldEnum(Account)) fn (
    beam.Env,
    c_int,
    [*c]const beam.Term,
) callconv(.C) beam.Term {
    const field_name = @tagName(field);
    const setter_name = "set_account_" ++ field_name;

    return struct {
        fn setter_fn(env: beam.Env, argc: c_int, argv: [*c]const beam.Term) callconv(.C) beam.Term {
            assert(argc == 3);

            const args = @ptrCast([*]const beam.Term, argv)[0..@intCast(usize, argc)];

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
                    return scheduler.reschedule(env, setter_name, setter_fn, argc, argv);
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
) fn (beam.Env, beam.Term) beam.GetError!std.meta.fieldInfo(Account, field).field_type {
    return switch (field) {
        .id, .user_data => beam.get_u128,
        .ledger => beam.get_u32,
        .code => beam.get_u16,
        .flags => term_to_account_flags,
        else => unreachable,
    };
}

fn term_to_account_flags(env: beam.Env, term: beam.Term) beam.GetError!AccountFlags {
    const flags_uint = beam.get_u16(env, term) catch
        return beam.GetError.ArgumentError;

    return @bitCast(AccountFlags, flags_uint);
}
