const e = @import("../erl_nif.zig");
const beam = @import("../beam.zig");
const Self = @This();

binary: e.ErlNifBinary,

pub fn slice(self: Self) []const u8 {
    return self.binary.data[0..self.binary.size];
}

pub const ToTermError = error{InvalidBinaryTerm};

pub fn to_term(self: Self, env: beam.Env) ToTermError!beam.Term {
    var result: beam.Term = undefined;
    if (e.enif_binary_to_term(env, self.binary.data, self.binary.size, &result, 0) == 0) {
        return error.InvalidBinaryTerm;
    }

    return result;
}

pub fn release(self: *Self) void {
    return e.enif_release_binary(&self.binary);
}
