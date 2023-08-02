const beam = @import("beam.zig");
const e = @import("erl_nif.zig");

pub const SelfError = error{NotProcessBound};

pub fn self(env: beam.env) SelfError!beam.pid {
    var result: beam.pid = undefined;
    if (e.enif_self(env, &result) == null) {
        return error.NotProcessBound;
    }

    return result;
}

pub const SendError = error{NotDelivered};

pub fn send(dest: beam.pid, msg_env: beam.env, msg: beam.term) !void {
    // Needed since enif_send is not const-correct
    var to_pid = dest;

    // TODO: make this more general
    // Given our (only) use of the function, we make some assumptions, namely:
    // - We're using a process independent env, so `caller_env` is null
    // - We're clearing the env after the message is sent, so we pass `msg_env` instead of passing
    //   null to copy `msg`
    if (e.enif_send(null, &to_pid, msg_env, msg) == 0) {
        return error.NotDelivered;
    }
}
