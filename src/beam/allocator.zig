// Taken from https://github.com/E-xyza/zigler/blob/master/priv/beam/allocator.zig

const std = @import("std");
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
    .free = raw_beam_free,
};

pub var general_purpose_allocator_instance = make_general_purpose_allocator_instance();
pub const general_purpose_allocator = general_purpose_allocator_instance.allocator();

fn raw_beam_alloc(
    ctx: *anyopaque,
    len: usize,
    log2_ptr_align: u8,
    ret_addr: usize,
) ?[*]u8 {
    _ = ctx;
    _ = ret_addr;
    const ptr_align = @as(usize, 1) << @as(Allocator.Log2Align, @intCast(log2_ptr_align));
    if (ptr_align > MAX_ALIGN) {
        return null;
    }
    const ptr = e.enif_alloc(len) orelse return null;
    return @ptrCast(ptr);
}

fn raw_beam_resize(
    ctx: *anyopaque,
    buf: []u8,
    log2_buf_align: u8,
    new_len: usize,
    return_address: usize,
) ?usize {
    _ = ctx;
    _ = log2_buf_align;
    _ = return_address;
    if (new_len <= buf.len) {
        return true;
    }

    return false;
}

fn raw_beam_free(
    ctx: *anyopaque,
    buf: []u8,
    log2_buf_align: u8,
    return_address: usize,
) void {
    _ = ctx;
    _ = log2_buf_align;
    _ = return_address;
    e.enif_free(buf.ptr);
}

pub const large_allocator = Allocator{
    .ptr = undefined,
    .vtable = &large_beam_allocator_vtable,
};
const large_beam_allocator_vtable = Allocator.VTable{
    .alloc = large_beam_alloc,
    .resize = large_beam_resize,
    .free = large_beam_free,
};

fn large_beam_alloc(
    ctx: *anyopaque,
    len: usize,
    log2_align: u8,
    return_address: usize,
) ?[*]u8 {
    _ = ctx;
    _ = return_address;
    return aligned_alloc(len, log2_align);
}

fn large_beam_resize(
    ctx: *anyopaque,
    buf: []u8,
    log2_buf_align: u8,
    new_len: usize,
    ret_addr: usize,
) bool {
    _ = ctx;
    _ = log2_buf_align;
    _ = ret_addr;
    if (new_len <= buf.len) {
        return true;
    }
    return false;
}

fn large_beam_free(
    ctx: *anyopaque,
    buf: []u8,
    log2_buf_align: u8,
    return_address: usize,
) void {
    _ = ctx;
    _ = log2_buf_align;
    _ = return_address;
    aligned_free(buf.ptr);
}

fn aligned_alloc(len: usize, log2_align: u8) ?[*]u8 {
    const alignment = @as(usize, 1) << @as(Allocator.Log2Align, @intCast(log2_align));
    var unaligned_ptr: [*]u8 = @ptrCast(e.enif_alloc(len + alignment - 1 + @sizeOf(usize)) orelse return null);
    const unaligned_addr = @intFromPtr(unaligned_ptr);
    const aligned_addr = std.mem.alignForward(usize, unaligned_addr + @sizeOf(usize), alignment);
    var aligned_ptr = unaligned_ptr + (aligned_addr - unaligned_addr);
    get_header(aligned_ptr).* = unaligned_ptr;

    return aligned_ptr;
}

fn aligned_free(ptr: [*]u8) void {
    const unaligned_ptr = get_header(ptr).*;
    e.enif_free(unaligned_ptr);
}

fn get_header(ptr: [*]u8) *[*]u8 {
    return @ptrFromInt(@intFromPtr(ptr) - @sizeOf(usize));
}

const BeamGpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true });

pub fn make_general_purpose_allocator_instance() BeamGpa {
    return BeamGpa{ .backing_allocator = large_allocator };
}
