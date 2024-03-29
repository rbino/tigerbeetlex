const e = @import("erl_nif.zig");
const beam = @import("../beam.zig");
const Nif = @import("nif.zig").Nif;

pub fn reschedule(
    env: beam.Env,
    name: [*c]const u8,
    fun: Nif,
    argc: c_int,
    argv: [*c]const beam.Term,
) beam.Term {
    return e.enif_schedule_nif(env, name, 0, fun, argc, argv);
}
