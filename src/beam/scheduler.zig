const e = @import("../erl_nif.zig");
const beam = @import("../beam.zig");

pub fn reschedule(
    env_: beam.env,
    name: [*c]const u8,
    fun: *const fn (beam.env, argc: c_int, argv: [*c]const beam.term) callconv(.C) beam.term,
    argc: c_int,
    argv: [*c]const beam.term,
) beam.term {
    return e.enif_schedule_nif(env_, name, 0, fun, argc, argv);
}
