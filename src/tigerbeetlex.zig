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

const vsr = @import("tigerbeetle/src/vsr.zig");
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
pub const log_level: std.log.Level = .err;

var exported_nifs = [_]nif.FunctionEntry{
    nif.wrap("client_init", client.init),
    nif.wrap("create_accounts", client.create_accounts),
    nif.wrap("create_transfers", client.create_transfers),
    nif.wrap("lookup_accounts", client.lookup_accounts),
    nif.wrap("lookup_transfers", client.lookup_transfers),
    nif.wrap("create_account_batch", account_batch.create),
    nif.wrap("add_account", account_batch.add_account),
    nif.wrap("set_account_id", account_batch.set_account_id),
    nif.wrap("set_account_user_data", account_batch.set_account_user_data),
    nif.wrap("set_account_ledger", account_batch.set_account_ledger),
    nif.wrap("set_account_code", account_batch.set_account_code),
    nif.wrap("set_account_flags", account_batch.set_account_flags),
    nif.wrap("create_transfer_batch", transfer_batch.create),
    nif.wrap("add_transfer", transfer_batch.add_transfer),
    nif.wrap("set_transfer_id", transfer_batch.set_transfer_id),
    nif.wrap("set_transfer_debit_account_id", transfer_batch.set_transfer_debit_account_id),
    nif.wrap("set_transfer_credit_account_id", transfer_batch.set_transfer_credit_account_id),
    nif.wrap("set_transfer_user_data", transfer_batch.set_transfer_user_data),
    nif.wrap("set_transfer_pending_id", transfer_batch.set_transfer_pending_id),
    nif.wrap("set_transfer_timeout", transfer_batch.set_transfer_timeout),
    nif.wrap("set_transfer_ledger", transfer_batch.set_transfer_ledger),
    nif.wrap("set_transfer_code", transfer_batch.set_transfer_code),
    nif.wrap("set_transfer_flags", transfer_batch.set_transfer_flags),
    nif.wrap("set_transfer_amount", transfer_batch.set_transfer_amount),
    nif.wrap("create_id_batch", id_batch.create),
    nif.wrap("add_id", id_batch.add_id),
    nif.wrap("set_id", id_batch.set_id),
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
