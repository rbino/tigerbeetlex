const std = @import("std");

const assert = std.debug.assert;
const beam = @import("beam");
const e = @import("erl_nif");

pub const Error = error{
    InvalidResourceTerm,
    OutOfMemory,
};

const DeinitFn = fn (beam.env, ?*anyopaque) callconv(.C) void;

pub fn Resource(comptime T: anytype, comptime deinit_fn: ?DeinitFn) type {
    return struct {
        const Self = @This();

        const Type = struct {
            beam_type: beam.resource_type,

            pub fn open(env: beam.env) Type {
                const beam_type = e.enif_open_resource_type(
                    env,
                    null,
                    "TigerBeetlex." ++ @typeName(T),
                    deinit_fn,
                    e.ERL_NIF_RT_CREATE | e.ERL_NIF_RT_TAKEOVER,
                    null,
                );

                assert(beam_type != null);

                return .{ .beam_type = beam_type };
            }
        };

        var resource_type: ?Type = null;

        raw_ptr: *anyopaque,

        /// Initializes the type of the resource. This must be called exactly once
        /// in the load or upgrade callback of the NIF.
        pub fn create_type(env: beam.env) void {
            // TODO: is this required or are we allowed to re-open a type?
            assert(resource_type == null);

            resource_type = Type.open(env);
        }

        /// Allocates the memory of the resource
        pub fn alloc() !Self {
            var raw_ptr: ?*anyopaque = e.enif_alloc_resource(res_type(), @sizeOf(T));

            if (raw_ptr) |p| {
                return Self{ .raw_ptr = p };
            } else {
                return error.OutOfMemory;
            }
        }

        /// Allocates the memory of the resource and initializes it with a value
        pub fn init(val: T) !Self {
            const ret = try Self.alloc();

            const value_ptr = ret.ptr();
            value_ptr.* = val;

            return ret;
        }

        /// Recreates the resource from the term handle obtained with `term_handle`
        pub fn from_term_handle(env: beam.env, term: beam.term) !Self {
            var raw_ptr: ?*anyopaque = undefined;

            if (0 == e.enif_get_resource(env, term, res_type(), &raw_ptr)) {
                return error.InvalidResourceTerm;
            }

            return Self{ .raw_ptr = raw_ptr.? };
        }

        /// Obtains a term handle to the resource
        pub fn term_handle(self: Self, env: beam.env) beam.term {
            return e.enif_make_resource(env, self.raw_ptr);
        }

        /// Decreases the refcount of a resource
        pub fn release(self: Self) void {
            e.enif_release_resource(self.raw_ptr);
        }

        /// Increases the refcount of a resource
        pub fn keep(self: Self) void {
            e.enif_keep_resource(self.raw_ptr);
        }

        /// Returns the allocation size of the resource
        pub fn size(self: Self) usize {
            return e.enif_sizeof_resource(self.raw_ptr);
        }

        /// Returns a copy of the resource value
        pub fn value(self: Self) T {
            const value_ptr = self.ptr_const();
            return value_ptr.*;
        }

        /// Returns a const pointer to the resource value
        pub fn ptr_const(self: Self) *const T {
            return @ptrCast(*const T, @alignCast(@alignOf(*const T), self.raw_ptr));
        }

        /// Returns a pointer to the resource value
        pub fn ptr(self: Self) *T {
            return @ptrCast(*T, @alignCast(@alignOf(*T), self.raw_ptr));
        }

        fn res_type() beam.resource_type {
            return resource_type.?.beam_type;
        }
    };
}
