const std = @import("std");
const beam = @import("beam");
const e = @import("erl_nif");

const account_batch = @import("account_batch.zig");
const client = @import("client.zig");
const id_batch = @import("id_batch.zig");
const resource = @import("resource.zig");
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
    .config_base = vsr.config.ConfigBase.default,
    .config_log_level = std.log.Level.info,
    .tracer_backend = vsr.config.TracerBackend.none,
    .hash_log_mode = vsr.config.HashLogMode.none,
    .config_aof_record = false,
    .config_aof_recovery = false,
};

// Lower the log level since currently Zig output screws up
// Elixir output, especially in interactive shells
// TODO: investigate why.
pub const log_level: std.log.Level = .err;

export var __exported_nifs__ = [_]e.ErlNifFunc{
    e.ErlNifFunc{
        .name = "client_init",
        .arity = 3,
        .fptr = client.init,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "create_account_batch",
        .arity = 1,
        .fptr = account_batch.create,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "add_account",
        .arity = 1,
        .fptr = account_batch.add_account,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "set_account_id",
        .arity = 3,
        .fptr = account_batch.set_account_id,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "set_account_user_data",
        .arity = 3,
        .fptr = account_batch.set_account_user_data,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "set_account_ledger",
        .arity = 3,
        .fptr = account_batch.set_account_ledger,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "set_account_code",
        .arity = 3,
        .fptr = account_batch.set_account_code,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "set_account_flags",
        .arity = 3,
        .fptr = account_batch.set_account_flags,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "create_accounts",
        .arity = 2,
        .fptr = client.create_accounts,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "create_transfer_batch",
        .arity = 1,
        .fptr = transfer_batch.create,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "add_transfer",
        .arity = 1,
        .fptr = transfer_batch.add_transfer,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "set_transfer_id",
        .arity = 3,
        .fptr = transfer_batch.set_transfer_id,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "set_transfer_debit_account_id",
        .arity = 3,
        .fptr = transfer_batch.set_transfer_debit_account_id,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "set_transfer_credit_account_id",
        .arity = 3,
        .fptr = transfer_batch.set_transfer_credit_account_id,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "set_transfer_user_data",
        .arity = 3,
        .fptr = transfer_batch.set_transfer_user_data,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "set_transfer_pending_id",
        .arity = 3,
        .fptr = transfer_batch.set_transfer_pending_id,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "set_transfer_timeout",
        .arity = 3,
        .fptr = transfer_batch.set_transfer_timeout,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "set_transfer_ledger",
        .arity = 3,
        .fptr = transfer_batch.set_transfer_ledger,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "set_transfer_code",
        .arity = 3,
        .fptr = transfer_batch.set_transfer_code,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "set_transfer_flags",
        .arity = 3,
        .fptr = transfer_batch.set_transfer_flags,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "set_transfer_amount",
        .arity = 3,
        .fptr = transfer_batch.set_transfer_amount,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "create_transfers",
        .arity = 2,
        .fptr = client.create_transfers,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "create_id_batch",
        .arity = 1,
        .fptr = id_batch.create,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "add_id",
        .arity = 2,
        .fptr = id_batch.add_id,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "set_id",
        .arity = 3,
        .fptr = id_batch.set_id,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "lookup_accounts",
        .arity = 2,
        .fptr = client.lookup_accounts,
        .flags = 0,
    },
    e.ErlNifFunc{
        .name = "lookup_transfers",
        .arity = 2,
        .fptr = client.lookup_transfers,
        .flags = 0,
    },
};

const entry = e.ErlNifEntry{
    .major = 2,
    .minor = 16,
    .name = "Elixir.TigerBeetlex.NifAdapter",
    .num_of_funcs = __exported_nifs__.len,
    .funcs = &(__exported_nifs__[0]),
    .load = nif_load,
    .reload = null, // currently unsupported
    .upgrade = null, // currently unsupported
    .unload = null, // currently unsupported
    .vm_variant = "beam.vanilla",
    .options = 1,
    .sizeof_ErlNifResourceTypeInit = @sizeOf(e.ErlNifResourceTypeInit),
    .min_erts = "erts-13.1.2",
};

export fn nif_init() *const e.ErlNifEntry {
    return &entry;
}

export fn nif_load(env: beam.env, _: [*c]?*anyopaque, _: beam.term) c_int {
    ClientResource.create_type(env);
    AccountBatchResource.create_type(env);
    IdBatchResource.create_type(env);
    TransferBatchResource.create_type(env);
    return 0;
}
