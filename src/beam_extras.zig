const std = @import("std");
const beam = @import("beam");
const e = @import("erl_nif");
const resource = beam.resource;

/// Raise a generic exception
pub fn raise(env: beam.env, reason: []const u8) beam.term {
    return e.enif_raise_exception(env, beam.make_atom(env, reason));
}

/// Return a pointer to a mutable resource, more ergonomic than doing fetch + update
pub fn resource_ptr(comptime T: type, environment: beam.env, res_typ: beam.resource_type, res_trm: beam.term) !*T {
    var obj: ?*anyopaque = undefined;

    if (0 == e.enif_get_resource(environment, res_trm, res_typ, @ptrCast([*c]?*anyopaque, &obj))) {
        return resource.ResourceError.FetchError;
    }

    // according to the erlang documentation:
    // the pointer received in *objp is guaranteed to be valid at least as long as the
    // resource handle term is valid.

    if (obj == null) {
        unreachable;
    }

    var val: *T = @ptrCast(*T, @alignCast(@alignOf(*T), obj));

    return val;
}

/// Extract a u128 from a binary (little endian) term
pub fn get_u128(env: beam.env, src_term: beam.term) !u128 {
    const bin = try beam.get_char_slice(env, src_term);
    const required_length = @sizeOf(u128) / @sizeOf(u8);

    // We represent the u128 as a 16 byte binary, little endian (required by TigerBeetle)
    if (bin.len != required_length) return error.InvalidU128;

    return std.mem.readIntLittle(u128, bin[0..required_length]);
}
