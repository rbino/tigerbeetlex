const std = @import("std");
const beam = @import("beam");
const e = @import("erl_nif");

/// Raise a generic exception
pub fn raise(env: beam.env, reason: []const u8) beam.term {
    return e.enif_raise_exception(env, beam.make_atom(env, reason));
}

/// Extract a u128 from a binary (little endian) term
pub fn get_u128(env: beam.env, src_term: beam.term) beam.Error!u128 {
    const bin = try beam.get_char_slice(env, src_term);
    const required_length = @sizeOf(u128) / @sizeOf(u8);

    // We represent the u128 as a 16 byte binary, little endian (required by TigerBeetle)
    if (bin.len != required_length) return beam.Error.FunctionClauseError;

    return std.mem.readIntLittle(u128, bin[0..required_length]);
}
