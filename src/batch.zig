const std = @import("std");
const Mutex = std.Thread.Mutex;

const beam = @import("beam.zig");
const Resource = beam.resource.Resource;

const tb = @import("tigerbeetle");
const Account = tb.Account;
const Transfer = tb.Transfer;

pub fn Batch(comptime Item: anytype) type {
    return struct {
        mutex: Mutex = .{},
        items: []Item,
        len: u32,
    };
}

pub fn BatchResource(comptime Item: anytype) type {
    return Resource(Batch(Item), batch_resource_deinit_fn(Batch(Item)));
}

pub fn create(comptime Item: anytype, env: beam.Env, capacity: u32) !beam.Term {
    const items = try beam.general_purpose_allocator.alloc(Item, capacity);
    const batch = Batch(Item){
        .items = items,
        .len = 0,
    };
    const batch_resource = try BatchResource(Item).init(batch);
    const term_handle = batch_resource.term_handle(env);
    batch_resource.release();

    return beam.make_ok_term(env, term_handle);
}

pub fn add_item(
    comptime Item: anytype,
    env: beam.Env,
    batch_resource: BatchResource(Item),
) !beam.Term {
    const batch = batch_resource.ptr();

    {
        if (!batch.mutex.tryLock()) {
            return error.MutexLocked;
        }
        defer batch.mutex.unlock();
        if (batch.len + 1 > batch.items.len) {
            return error.BatchFull;
        }
        batch.len += 1;
        batch.items[batch.len - 1] = std.mem.zeroInit(Item, .{});

        return beam.make_ok_term(env, beam.make_u32(env, batch.len));
    }
}

pub fn get_item_field_setter_fn(comptime Item: type, comptime field: std.meta.FieldEnum(Item)) (fn (
    env: beam.Env,
    batch_resource: BatchResource(Item),
    idx: u32,
    value: std.meta.fieldInfo(Item, field).field_type,
) error{Yield}!beam.Term) {
    const FieldType = std.meta.fieldInfo(Item, field).field_type;

    return struct {
        fn setter_fn(
            env: beam.Env,
            batch_resource: BatchResource(Item),
            idx: u32,
            value: FieldType,
        ) !beam.Term {
            return set_item_field(Item, field, env, batch_resource, idx, value);
        }
    }.setter_fn;
}

pub fn set_item_field(
    comptime Item: type,
    comptime field: std.meta.FieldEnum(Item),
    env: beam.Env,
    batch_resource: BatchResource(Item),
    idx: u32,
    value: std.meta.fieldInfo(Item, field).field_type,
) error{Yield}!beam.Term {
    const field_name = @tagName(field);
    const batch = batch_resource.ptr();

    {
        if (!batch.mutex.tryLock()) {
            return error.Yield;
        }
        defer batch.mutex.unlock();

        if (idx >= batch.len) {
            return beam.make_error_atom(env, "out_of_bounds");
        }

        const item: *Item = &batch.items[idx];

        @field(item, field_name) = value;
    }

    return beam.make_ok(env);
}

fn batch_resource_deinit_fn(
    comptime Item: anytype,
) fn (env: beam.Env, ptr: ?*anyopaque) callconv(.C) void {
    return struct {
        fn deinit_fn(_: beam.Env, ptr: ?*anyopaque) callconv(.C) void {
            if (ptr) |p| {
                const batch: *Item = @ptrCast(*Item, @alignCast(@alignOf(*Item), p));
                beam.general_purpose_allocator.free(batch.items);
            } else unreachable;
        }
    }.deinit_fn;
}
