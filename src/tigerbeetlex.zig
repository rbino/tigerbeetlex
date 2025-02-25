const std = @import("std");
const beam = @import("beam.zig");
const nif = beam.nif;
const resource = beam.resource;

const account_batch = @import("account_batch.zig");
const client = @import("client.zig");
const id_batch = @import("id_batch.zig");
const transfer_batch = @import("transfer_batch.zig");
const account_filter_batch = @import("account_filter_batch.zig");
const AccountBatch = account_batch.AccountBatch;
const IdBatch = id_batch.IdBatch;
const TransferBatch = transfer_batch.TransferBatch;
const AccountFilterBatch = account_filter_batch.TransferBatch;
const Client = client.Client;

const ClientResource = client.ClientResource;
const AccountBatchResource = account_batch.AccountBatchResource;
const IdBatchResource = id_batch.IdBatchResource;
const TransferBatchResource = transfer_batch.TransferBatchResource;
const AccountFilterBatchResource = account_filter_batch.AccountFilterBatchResource;

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
    nif.wrap("create_account_filter_batch", account_filter_batch.create),
    nif.wrap("append_account_filter", account_filter_batch.append),
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
    AccountFilterBatchResource.create_type(env, "TigerBeetlex.AccountFilterBatch");
    return 0;
}

const entrypoint = nif.entrypoint("Elixir.TigerBeetlex.NifAdapter", &exported_nifs, nif_load);

export fn nif_init() *const nif.Entrypoint {
    return &entrypoint;
}
