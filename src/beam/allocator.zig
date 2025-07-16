// Taken from https://github.com/E-xyza/zigler/blob/master/priv/beam/allocator.zig

const std = @import("std");
const assert = std.debug.assert;
const e = @import("erl_nif.zig");

const Allocator = std.mem.Allocator;

pub const MAX_ALIGN = @sizeOf(usize);

pub const raw_allocator = Allocator{
    .ptr = undefined,
    .vtable = &raw_beam_allocator_vtable,
};
const raw_beam_allocator_vtable = Allocator.VTable{
    .alloc = raw_beam_alloc,
    .resize = raw_beam_resize,
    .remap = raw_beam_remap,
    .free = raw_beam_free,
};

pub var general_purpose_allocator_instance = make_general_purpose_allocator_instance();
pub const general_purpose_allocator = general_purpose_allocator_instance.allocator();

fn raw_beam_alloc(
    ctx: *anyopaque,
    len: usize,
    alignment: std.mem.Alignment,
    ret_addr: usize,
) ?[*]u8 {
    _ = ctx;
    _ = ret_addr;
    assert(alignment.compare(.lte, comptime .fromByteUnits(MAX_ALIGN)));
    assert(len > 0);
    return @ptrCast(e.enif_alloc(len));
}

fn raw_beam_resize(
    ctx: *anyopaque,
    buf: []u8,
    alignment: std.mem.Alignment,
    new_len: usize,
    return_address: usize,
) bool {
    _ = ctx;
    _ = buf;
    _ = alignment;
    _ = new_len;
    _ = return_address;

    return false;
}

fn raw_beam_remap(
    ctx: *anyopaque,
    memory: []u8,
    alignment: std.mem.Alignment,
    new_len: usize,
    return_address: usize,
) ?[*]u8 {
    _ = ctx;
    _ = alignment;
    _ = return_address;
    return @ptrCast(e.enif_realloc(memory.ptr, new_len)); // can't remap with raw allocator
}

fn raw_beam_free(
    ctx: *anyopaque,
    memory: []u8,
    alignment: std.mem.Alignment,
    return_address: usize,
) void {
    _ = ctx;
    _ = alignment;
    _ = return_address;
    e.enif_free(memory.ptr);
}

pub const large_allocator = Allocator{
    .ptr = undefined,
    .vtable = &large_beam_allocator_vtable,
};
const large_beam_allocator_vtable = Allocator.VTable{
    .alloc = large_beam_alloc,
    .resize = large_beam_resize,
    .remap = large_beam_remap,
    .free = large_beam_free,
};

fn large_beam_alloc(
    ctx: *anyopaque,
    len: usize,
    alignment: std.mem.Alignment,
    return_address: usize,
) ?[*]u8 {
    _ = ctx;
    _ = return_address;
    assert(len > 0);
    return aligned_alloc(len, alignment);
}

fn large_beam_resize(
    ctx: *anyopaque,
    buf: []u8,
    alignment: std.mem.Alignment,
    new_len: usize,
    ret_addr: usize,
) bool {
    _ = ctx;
    _ = alignment;
    _ = ret_addr;
    // we can shrink buffers but we can't grow them
    return new_len < buf.len;
}

fn large_beam_remap(
    ctx: *anyopaque,
    memory: []u8,
    alignment: std.mem.Alignment,
    new_len: usize,
    ret_addr: usize,
) ?[*]u8 {
    // can't use realloc directly because it might not respect alignment.
    return if (large_beam_resize(ctx, memory, alignment, new_len, ret_addr)) memory.ptr else null;
}

fn large_beam_free(
    ctx: *anyopaque,
    buf: []u8,
    alignment: std.mem.Alignment,
    return_address: usize,
) void {
    _ = ctx;
    _ = alignment;
    _ = return_address;
    aligned_free(buf.ptr);
}

fn aligned_alloc(len: usize, alignment: std.mem.Alignment) ?[*]u8 {
    const alignment_bytes = alignment.toByteUnits();
    const unaligned_ptr: [*]u8 = @ptrCast(e.enif_alloc(len + alignment_bytes - 1 + @sizeOf(usize)) orelse return null);
    const unaligned_addr = @intFromPtr(unaligned_ptr);
    const aligned_addr = std.mem.alignForward(usize, unaligned_addr + @sizeOf(usize), alignment_bytes);
    const aligned_ptr = unaligned_ptr + (aligned_addr - unaligned_addr);
    get_header(aligned_ptr).* = unaligned_ptr;

    return aligned_ptr;
}

fn aligned_free(ptr: [*]u8) void {
    const unaligned_ptr = get_header(ptr).*;
    e.enif_free(unaligned_ptr);
}

fn get_header(ptr: [*]u8) *[*]u8 {
    return @alignCast(@ptrCast(ptr - @sizeOf(usize)));
}

const BeamGpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true });

pub fn make_general_purpose_allocator_instance() BeamGpa {
    return BeamGpa{ .backing_allocator = large_allocator };
}
