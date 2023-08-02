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
    nif.function_entry("client_init", 3, client.init),
    nif.function_entry("create_account_batch", 1, account_batch.create),
    nif.function_entry("add_account", 1, account_batch.add_account),
    nif.function_entry("set_account_id", 3, account_batch.set_account_id),
    nif.function_entry("set_account_user_data", 3, account_batch.set_account_user_data),
    nif.function_entry("set_account_ledger", 3, account_batch.set_account_ledger),
    nif.function_entry("set_account_code", 3, account_batch.set_account_code),
    nif.function_entry("set_account_flags", 3, account_batch.set_account_flags),
    nif.function_entry("create_accounts", 2, client.create_accounts),
    nif.function_entry("create_transfer_batch", 1, transfer_batch.create),
    nif.function_entry("add_transfer", 1, transfer_batch.add_transfer),
    nif.function_entry("set_transfer_id", 3, transfer_batch.set_transfer_id),
    nif.function_entry("set_transfer_debit_account_id", 3, transfer_batch.set_transfer_debit_account_id),
    nif.function_entry("set_transfer_credit_account_id", 3, transfer_batch.set_transfer_credit_account_id),
    nif.function_entry("set_transfer_user_data", 3, transfer_batch.set_transfer_user_data),
    nif.function_entry("set_transfer_pending_id", 3, transfer_batch.set_transfer_pending_id),
    nif.function_entry("set_transfer_timeout", 3, transfer_batch.set_transfer_timeout),
    nif.function_entry("set_transfer_ledger", 3, transfer_batch.set_transfer_ledger),
    nif.function_entry("set_transfer_code", 3, transfer_batch.set_transfer_code),
    nif.function_entry("set_transfer_flags", 3, transfer_batch.set_transfer_flags),
    nif.function_entry("set_transfer_amount", 3, transfer_batch.set_transfer_amount),
    nif.function_entry("create_transfers", 2, client.create_transfers),
    nif.function_entry("create_id_batch", 1, id_batch.create),
    nif.function_entry("add_id", 2, id_batch.add_id),
    nif.function_entry("set_id", 3, id_batch.set_id),
    nif.function_entry("lookup_accounts", 2, client.lookup_accounts),
    nif.function_entry("lookup_transfers", 2, client.lookup_transfers),
};

fn nif_load(env: beam.Env, _: [*c]?*anyopaque, _: beam.Term) callconv(.C) c_int {
    ClientResource.create_type(env);
    AccountBatchResource.create_type(env);
    IdBatchResource.create_type(env);
    TransferBatchResource.create_type(env);
    return 0;
}

const entrypoint = nif.entrypoint("Elixir.TigerBeetlex.NifAdapter", &exported_nifs, nif_load);

export fn nif_init() *const nif.Entrypoint {
    return &entrypoint;
}
