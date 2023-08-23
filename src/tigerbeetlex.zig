const std = @import("std");
const beam = @import("beam.zig");
const nif = beam.nif;
const resource = beam.resource;

const account_batch = @import("account_batch.zig");
const client = @import("client.zig");
const id_batch = @import("id_batch.zig");
const transfer_batch = @import("transfer_batch.zig");
const AccountBatch = account_batch.AccountBatch;
const IdBatch = id_batch.IdBatch;
const TransferBatch = transfer_batch.TransferBatch;
const Client = client.Client;

const ClientResource = client.ClientResource;
const AccountBatchResource = account_batch.AccountBatchResource;
const IdBatchResource = id_batch.IdBatchResource;
const TransferBatchResource = transfer_batch.TransferBatchResource;

pub const vsr_options = .{
    .config_base = .default,
    .config_log_level = std.log.Level.info,
    .tracer_backend = .none,
    .hash_log_mode = .none,
    .config_aof_record = false,
    .config_aof_recovery = false,
};

// Lower the log level since currently Zig output screws up
// Elixir output, especially in interactive shells
// TODO: investigate why.
pub const std_options = struct {
    pub const log_level = .err;
};

var exported_nifs = [_]nif.FunctionEntry{
    nif.wrap("client_init", client.init),
    nif.wrap("create_accounts", client.create_accounts),
    nif.wrap("create_transfers", client.create_transfers),
    nif.wrap("lookup_accounts", client.lookup_accounts),
    nif.wrap("lookup_transfers", client.lookup_transfers),
    nif.wrap("create_account_batch", account_batch.create),
    nif.wrap("append_account", account_batch.append),
    nif.wrap("fetch_account", account_batch.fetch),
    nif.wrap("replace_account", account_batch.replace),
    nif.wrap("create_transfer_batch", transfer_batch.create),
    nif.wrap("append_transfer", transfer_batch.append),
    nif.wrap("fetch_transfer", transfer_batch.fetch),
    nif.wrap("replace_transfer", transfer_batch.replace),
    nif.wrap("create_id_batch", id_batch.create),
    nif.wrap("append_id", id_batch.append),
    nif.wrap("fetch_id", id_batch.fetch),
    nif.wrap("replace_id", id_batch.replace),
};

fn nif_load(env: beam.Env, _: [*c]?*anyopaque, _: beam.Term) callconv(.C) c_int {
    ClientResource.create_type(env, "TigerBeetlex.Client");
    AccountBatchResource.create_type(env, "TigerBeetlex.AccountBatch");
    IdBatchResource.create_type(env, "TigerBeetlex.IdBatch");
    TransferBatchResource.create_type(env, "TigerBeetlex.TransferBatch");
    return 0;
}

const entrypoint = nif.entrypoint("Elixir.TigerBeetlex.NifAdapter", &exported_nifs, nif_load);

export fn nif_init() *const nif.Entrypoint {
    return &entrypoint;
}
