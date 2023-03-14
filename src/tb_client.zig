const std = @import("std");

const tb = @import("tigerbeetle/src/clients/c/tb_client.zig");
pub usingnamespace tb;

const constants = @import("tigerbeetle/src/constants.zig");
const Storage = @import("tigerbeetle/src/storage.zig").Storage;
const MessageBus = @import("tigerbeetle/src/message_bus.zig").MessageBusClient;
const StateMachine = @import("tigerbeetle/src/state_machine.zig").StateMachineType(Storage, .{
    .message_body_size_max = constants.message_body_size_max,
    .lsm_batch_multiple = constants.lsm_batch_multiple,
});

const ContextType = @import("tigerbeetle/src/clients/c/tb_client/context.zig").ContextType;
const ContextImplementation = @import("tigerbeetle/src/clients/c/tb_client/context.zig").ContextImplementation;

const DefaultContext = blk: {
    const Client = @import("tigerbeetle/src/vsr/client.zig").Client(StateMachine, MessageBus);
    break :blk ContextType(Client);
};

// This is mostly taken from tb_client with a couple of differences:
// - Pass an explicit allocator, so we can use the BEAM allocator
// - Directly pass addresses as a slice, so we can pass binaries, which are not null-terminated
pub fn client_init(
    allocator: std.mem.Allocator,
    out_client: *tb.tb_client_t,
    out_packets: *tb.tb_packet_list_t,
    cluster_id: u32,
    addresses: []u8,
    packets_count: u32,
    on_completion_ctx: usize,
    on_completion_fn: tb.tb_completion_t,
) tb.tb_status_t {
    const context = DefaultContext.init(
        allocator,
        cluster_id,
        addresses,
        packets_count,
        on_completion_ctx,
        on_completion_fn,
    ) catch |err| switch (err) {
        error.Unexpected => return .unexpected,
        error.OutOfMemory => return .out_of_memory,
        error.AddressInvalid => return .address_invalid,
        error.AddressLimitExceeded => return .address_limit_exceeded,
        error.PacketsCountInvalid => return .packets_count_invalid,
        error.SystemResources => return .system_resources,
        error.NetworkSubsystemFailed => return .network_subsystem,
    };

    out_client.* = tb.context_to_client(&context.implementation);
    var list = tb.tb_packet_list_t{};
    for (context.packets) |*packet| {
        list.push(tb.tb_packet_list_t.from(packet));
    }

    out_packets.* = list;
    return .success;
}
