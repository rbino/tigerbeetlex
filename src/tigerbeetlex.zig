const beam = @import("beam");
const e = @import("erl_nif");

const account_batch = @import("account_batch.zig");
const client = @import("client.zig");
const resource_types = @import("resource_types.zig");
const transfer_batch = @import("transfer_batch.zig");
const AccountBatch = account_batch.AccountBatch;
const TransferBatch = transfer_batch.TransferBatch;
const Client = client.Client;

const tb_client = @import("tb_client.zig");
const vsr = @import("vsr");
pub const vsr_options = .{
    .config_base = vsr.config.ConfigBase.default,
    .tracer_backend = vsr.config.TracerBackend.none,
    .hash_log_mode = vsr.config.HashLogMode.none,
};

fn client_resource_deinit(_: ?*e.ErlNifEnv, ptr: ?*anyopaque) callconv(.C) void {
    if (ptr) |p| {
        const cl: *Client = @ptrCast(*Client, @alignCast(@alignOf(*Client), p));
        tb_client.tb_client_deinit(cl.c_client);
    } else unreachable;
}

fn batch_deinit_fn(comptime T: anytype) fn (env: ?*e.ErlNifEnv, ptr: ?*anyopaque) callconv(.C) void {
    return struct {
        pub fn deinit_fn(_: ?*e.ErlNifEnv, ptr: ?*anyopaque) callconv(.C) void {
            if (ptr) |p| {
                const b: *T = @ptrCast(*T, @alignCast(@alignOf(*T), p));
                beam.general_purpose_allocator.free(b.items);
            } else unreachable;
        }
    }.deinit_fn;
}

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

export fn nif_load(env: ?*e.ErlNifEnv, _: [*c]?*anyopaque, _: e.ErlNifTerm) c_int {
    resource_types.client = e.enif_open_resource_type(
        env,
        null,
        "tigerbeetlex_client",
        client_resource_deinit,
        e.ERL_NIF_RT_CREATE | e.ERL_NIF_RT_TAKEOVER,
        null,
    );
    resource_types.account_batch = e.enif_open_resource_type(
        env,
        null,
        "tigerbeetlex_account_batch",
        batch_deinit_fn(AccountBatch),
        e.ERL_NIF_RT_CREATE | e.ERL_NIF_RT_TAKEOVER,
        null,
    );
    resource_types.transfer_batch = e.enif_open_resource_type(
        env,
        null,
        "tigerbeetlex_transfer_batch",
        batch_deinit_fn(TransferBatch),
        e.ERL_NIF_RT_CREATE | e.ERL_NIF_RT_TAKEOVER,
        null,
    );
    return 0;
}
