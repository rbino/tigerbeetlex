const beam = @import("beam.zig");
const nif = beam.nif;

const client = @import("client.zig");

// Needed to configure VSR
pub const vsr_options = @import("config").vsr_options;

// Reduce log spamminess
pub const std_options = .{
    .log_level = .err,
};

var exported_nifs = [_]nif.FunctionEntry{
    nif.wrap("client_init", client.init),
    nif.wrap("submit", client.submit),
};

fn nif_load(env: ?*beam.Env, priv_data: [*c]?*anyopaque, load_info: beam.Term) callconv(.C) c_int {
    _ = priv_data;
    _ = load_info;

    client.initialize_resources(env.?) catch return -1;

    return 0;
}

const entrypoint = nif.entrypoint("Elixir.TigerBeetlex.NifAdapter", &exported_nifs, nif_load);

export fn nif_init() *const nif.Entrypoint {
    return &entrypoint;
}
