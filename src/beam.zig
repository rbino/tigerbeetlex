// The code contained here is taken and/or heavily inspired from https://github.com/E-xyza/zigler.
// Since we're using a subset of all its features, we removed the dependency to be independent
// from API changes (and to experiment ourselves with alternative APIs)

const std = @import("std");
const assert = std.debug.assert;
const e = @import("beam/erl_nif.zig");

pub const allocator = @import("beam/allocator.zig");

pub const Env = e.ErlNifEnv;
pub const Pid = e.ErlNifPid;
pub const ResourceDestructorFn = e.ErlNifResourceDtor;
pub const ResourceType = e.ErlNifResourceType;
pub const Term = e.ERL_NIF_TERM;

/// The raw BEAM allocator with the standard Zig Allocator interface.
pub const raw_allocator = allocator.raw_allocator;

/// An allocator backed by the BEAM allocator that is able to perform allocations with a
/// greater alignment than the machine word. Doesn't release memory when resizing.
pub const large_allocator = allocator.large_allocator;

/// A General Purpose Allocator backed by beam.large_allocator.
pub const general_purpose_allocator = allocator.general_purpose_allocator;

/// Raises a `:badarg` exception
pub fn raise_badarg(env: *Env) Term {
    return e.enif_make_badarg(env);
}

/// Creates a ref
pub fn make_ref(env: *Env) Term {
    return e.enif_make_ref(env);
}

/// Creates an atom from a Zig char slice
pub fn make_atom(env: *Env, atom_str: []const u8) Term {
    return e.enif_make_atom_len(env, atom_str.ptr, atom_str.len);
}

/// Creates a beam `nil` atom
pub fn make_nil(env: *Env) Term {
    return e.enif_make_atom(env, "nil");
}

/// Creates a beam `:ok` atom
pub fn make_ok(env: *Env) Term {
    return e.enif_make_atom(env, "ok");
}

/// Helper to create an `{:ok, term}` tuple
pub fn make_ok_term(env: *Env, val: Term) Term {
    return e.enif_make_tuple(env, 2, make_ok(env), val);
}

/// Creates a beam `:error` atom.
pub fn make_error(env: *Env) Term {
    return e.enif_make_atom(env, "error");
}

/// Helper to create an `{:error, term}` tuple
pub fn make_error_term(env: *Env, val: Term) Term {
    return e.enif_make_tuple(env, 2, make_error(env), val);
}

/// Helper to create an `{:error, atom}` tuple, taking the atom value from a slice
pub fn make_error_atom(env: *Env, atom_str: []const u8) Term {
    return make_error_term(env, make_atom(env, atom_str));
}

/// Creates a binary term from a Zig slice
pub fn make_slice(env: *Env, val: []const u8) Term {
    var result: Term = undefined;
    var bin: [*]u8 = @ptrCast(e.enif_make_new_binary(env, val.len, &result));
    @memcpy(bin[0..val.len], val);

    return result;
}

/// Copies a term to destination_env, creating a new term valid in that env
pub fn make_copy(destination_env: *Env, source_term: Term) Term {
    return e.enif_make_copy(destination_env, source_term);
}

/// Creates a u8 value term.
pub fn make_u8(env: *Env, val: u8) Term {
    return e.enif_make_uint(env, val);
}

/// Creates an BEAM tuple from a Zig tuple of terms
pub fn make_tuple(env: *Env, tuple: anytype) Term {
    const type_info = @typeInfo(@TypeOf(tuple));
    if (type_info != .@"struct" or !type_info.@"struct".is_tuple)
        @compileError("invalid argument to make_tuple: not a tuple");

    var tuple_list: [tuple.len]Term = undefined;
    inline for (&tuple_list, 0..) |*tuple_item, index| {
        const tuple_term = tuple[index];
        tuple_item.* = tuple_term;
    }
    return e.enif_make_tuple_from_array(env, &tuple_list, tuple.len);
}

pub const GetError = error{ArgumentError};

/// Extract a binary from a term, returning it as a slice
pub fn get_char_slice(env: *Env, src_term: Term) GetError![]u8 {
    var bin: e.ErlNifBinary = undefined;
    if (e.enif_inspect_binary(env, src_term, &bin) == 0) {
        return error.ArgumentError;
    }
    assert(bin.data != null);
    return bin.data[0..bin.size];
}

/// Extract a iolist from a term, returning it as a slice of its binary flattening
pub fn get_iolist_as_char_slice(env: *Env, src_term: Term) GetError![]u8 {
    var bin: e.ErlNifBinary = undefined;
    if (e.enif_inspect_iolist_as_binary(env, src_term, &bin) == 0) {
        return error.ArgumentError;
    }
    assert(bin.data != null);
    return bin.data[0..bin.size];
}

/// Extract a u8 from a term
pub fn get_u8(env: *Env, src_term: Term) GetError!u8 {
    var result: c_uint = undefined;
    if (e.enif_get_uint(env, src_term, &result) == 0) {
        return error.ArgumentError;
    }

    if (result > std.math.maxInt(u8)) {
        return error.ArgumentError;
    }

    return @intCast(result);
}

/// Extract a u128 from a binary (little endian) term
pub fn get_u128(env: *Env, src_term: Term) GetError!u128 {
    const bin = try get_char_slice(env, src_term);
    const required_length = @sizeOf(u128) / @sizeOf(u8);

    // We represent the u128 as a 16 byte binary, little endian (required by TigerBeetle)
    if (bin.len != required_length) return error.ArgumentError;

    return std.mem.readInt(u128, bin[0..required_length], .little);
}

const AllocEnvError = error{OutOfMemory};

/// Allocates a process independent environment
pub fn alloc_env() AllocEnvError!*Env {
    return e.enif_alloc_env() orelse error.OutOfMemory;
}

/// Clears a process independent environment
pub fn clear_env(env: *Env) void {
    e.enif_clear_env(env);
}

/// Frees a process independent environment
pub fn free_env(env: *Env) void {
    e.enif_free_env(env);
}

pub const SelfError = error{NotProcessBound};

/// Returns the self pid of the env. Needs to be called with a process-bound env.
pub fn self(env: *Env) SelfError!Pid {
    var result: Pid = undefined;
    if (e.enif_self(env, &result) == null) {
        return error.NotProcessBound;
    }

    return result;
}

pub const SendError = error{NotDelivered};

/// Sends a message containing the msg term to the dest Pid.
pub fn send(dest: Pid, msg_env: *Env, msg: Term) SendError!void {
    // Needed since enif_send is not const-correct
    var to_pid = dest;

    // Given our (only) use of the function, we make some assumptions, namely:
    // - We're using a process independent env, so `caller_env` is null
    // - We're freeing the env after the message is sent, so we pass `msg_env` instead of passing
    //   null to copy `msg`
    if (e.enif_send(null, &to_pid, msg_env, msg) == 0) {
        return error.NotDelivered;
    }
}

pub fn Resource(
    comptime T: anytype,
    comptime name: [:0]const u8,
    comptime destructor: ResourceDestructorFn,
) type {
    return struct {
        const Self = @This();

        var resource_type: ?*ResourceType = null;

        raw_ptr: *anyopaque,

        const OpenResourceTypeError = error{CannotCreateType};

        /// Initializes the type of the resource. This must be called exactly once
        /// in the load callback of the NIF.
        pub fn open_type(env: *Env) OpenResourceTypeError!void {
            // For now, we assume we want to open type only once
            assert(resource_type == null);

            resource_type = e.enif_open_resource_type(
                env,
                null,
                name.ptr,
                destructor,
                e.ERL_NIF_RT_CREATE | e.ERL_NIF_RT_TAKEOVER,
                null,
            ) orelse return error.CannotCreateType;
        }

        const InitError = error{OutOfMemory};

        /// Allocates the memory of the resource and initializes it with a value
        pub fn init(init_value: T) InitError!Self {
            const raw_ptr = e.enif_alloc_resource(resource_type, @sizeOf(T)) orelse return error.OutOfMemory;
            const resource: Self = .{ .raw_ptr = raw_ptr };

            resource.ptr().* = init_value;

            return resource;
        }

        /// Recreates the resource from the term handle obtained with `term_handle`
        pub fn from_term_handle(env: *Env, term: Term) GetError!Self {
            var raw_ptr: ?*anyopaque = undefined;

            if (e.enif_get_resource(env, term, resource_type, &raw_ptr) == 0) {
                return error.ArgumentError;
            }

            return Self{ .raw_ptr = raw_ptr.? };
        }

        /// Recreates the resource from its resource pointer
        /// This is particularly useful in the destructor function
        pub fn from_resource_pointer(raw_ptr: *anyopaque) Self {
            return Self{ .raw_ptr = raw_ptr };
        }

        /// Obtains a term handle to the resource
        pub fn term_handle(resource: Self, env: *Env) Term {
            return e.enif_make_resource(env, resource.raw_ptr);
        }

        /// Decreases the refcount of a resource
        pub fn release(resource: Self) void {
            e.enif_release_resource(resource.raw_ptr);
        }

        /// Increases the refcount of a resource
        pub fn keep(resource: Self) void {
            e.enif_keep_resource(resource.raw_ptr);
        }

        /// Returns a copy of the resource value
        pub fn value(resource: Self) T {
            return resource.ptr().*;
        }

        /// Returns a pointer to the resource value
        fn ptr(resource: Self) *T {
            return @ptrCast(@alignCast(resource.raw_ptr));
        }
    };
}
