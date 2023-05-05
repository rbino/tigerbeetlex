const beam = @import("beam");

const tb = @import("tigerbeetle");
const Account = tb.Account;
const Transfer = tb.Transfer;

// The resource type for the client
pub var client: beam.resource_type = undefined;

// The resource type for the account batch
pub var account_batch: beam.resource_type = undefined;

// The resource type for the transfer batch
pub var transfer_batch: beam.resource_type = undefined;

pub fn from_batch_type(comptime T: anytype) beam.resource_type {
    return switch (T) {
        Account => account_batch,
        Transfer => transfer_batch,
        else => unreachable,
    };
}
