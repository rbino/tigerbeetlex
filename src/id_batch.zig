const std = @import("std");
const assert = std.debug.assert;

const batch = @import("batch.zig");
const beam = @import("beam.zig");
const scheduler = beam.scheduler;

pub const IdBatch = batch.Batch(u128);
pub const IdBatchResource = batch.BatchResource(u128);

pub fn create(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
    assert(argc == 1);

    const args = @ptrCast([*]const beam.term, argv)[0..@intCast(usize, argc)];

    const capacity: u32 = beam.get_u32(env, args[0]) catch
        return beam.raise_function_clause_error(env);

    return batch.create(u128, env, capacity);
}

pub fn add_id(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
    // We don't use beam.add_item since we increase len and directly add the id in a single call
    assert(argc == 2);

    const args = @ptrCast([*]const beam.term, argv)[0..@intCast(usize, argc)];

    const id = beam.get_u128(env, args[1]) catch
        return beam.raise_function_clause_error(env);

    const batch_term = args[0];
    const id_batch_resource = IdBatchResource.from_term_handle(env, batch_term) catch |err|
        switch (err) {
        error.InvalidResourceTerm => return beam.make_error_atom(env, "invalid_batch"),
    };
    const id_batch = id_batch_resource.ptr();

    {
        if (!id_batch.mutex.tryLock()) {
            return scheduler.reschedule(env, "add_id", add_id, argc, argv);
        }
        defer id_batch.mutex.unlock();

        if (id_batch.len + 1 > id_batch.items.len) {
            return beam.make_error_atom(env, "batch_full");
        }
        id_batch.len += 1;
        id_batch.items[id_batch.len - 1] = id;

        return beam.make_ok_term(env, beam.make_u32(env, id_batch.len));
    }
}

pub fn set_id(env: beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term {
    assert(argc == 3);

    const args = @ptrCast([*]const beam.term, argv)[0..@intCast(usize, argc)];

    const batch_term = args[0];
    const id_batch_resource = IdBatchResource.from_term_handle(env, batch_term) catch |err|
        switch (err) {
        error.InvalidResourceTerm => return beam.make_error_atom(env, "invalid_batch"),
    };
    const id_batch = id_batch_resource.ptr();

    const idx: u32 = beam.get_u32(env, args[1]) catch
        return beam.raise_function_clause_error(env);

    {
        if (!id_batch.mutex.tryLock()) {
            return scheduler.reschedule(env, "set_id", set_id, argc, argv);
        }
        defer id_batch.mutex.unlock();

        if (idx >= id_batch.len) {
            return beam.make_error_atom(env, "out_of_bounds");
        }

        const id = beam.get_u128(env, args[2]) catch
            return beam.raise_function_clause_error(env);

        id_batch.items[idx] = id;
    }

    return beam.make_ok(env);
}
