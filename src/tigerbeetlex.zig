const std = @import("std");
const beam = @import("beam.zig");
const nif = beam.nif;
const resource = beam.resource;

const client = @import("client.zig");
const ClientResource = client.ClientResource;

// Needed to configure VSR
pub const vsr_options = @import("config").vsr_options;

// Reduce log spamminess
pub const std_options = .{
    .log_level = .err,
};

var exported_nifs = [_]nif.FunctionEntry{
    nif.wrap("client_init", client.init),
    nif.wrap("create_accounts", client.create_accounts),
    nif.wrap("create_transfers", client.create_transfers),
    nif.wrap("lookup_accounts", client.lookup_accounts),
    nif.wrap("lookup_transfers", client.lookup_transfers),
    nif.wrap("get_account_balances", client.get_account_balances),
    nif.wrap("get_account_transfers", client.get_account_transfers),
    nif.wrap("query_accounts", client.query_accounts),
    nif.wrap("query_transfers", client.query_transfers),
};

fn nif_load(env: beam.Env, _: [*c]?*anyopaque, _: beam.Term) callconv(.C) c_int {
    ClientResource.create_type(env, "TigerBeetlex.Client");
    return 0;
}

const entrypoint = nif.entrypoint("Elixir.TigerBeetlex.NifAdapter", &exported_nifs, nif_load);

export fn nif_init() *const nif.Entrypoint {
    return &entrypoint;
}
