const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

pub const BuiltinResult = struct {
    status: i32 = 0,
    output: []const u8 = &[_]u8{},
};

pub const Context = struct {
    allocator: Allocator,
    stdout: *std.ArrayListUnmanaged(u8),
};

/// Test TCP connection to host:port
/// Usage: net-test <host> <port>
pub fn netTest(ctx: *Context, args: []const []const u8) !BuiltinResult {
    if (args.len < 3) {
        try ctx.stdout.appendSlice(ctx.allocator, "Usage: net-test <host> <port>\n");
        return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
    }

    const host = args[1];
    const port_str = args[2];
    const port = std.fmt.parseInt(u16, port_str, 10) catch {
        try ctx.stdout.appendSlice(ctx.allocator, "Error: Invalid port number\n");
        return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
    };

    const start_time = std.time.milliTimestamp();

    // Try to connect
    const address = std.net.Address.parseIp(host, port) catch blk: {
        // If not an IP, try to resolve hostname
        const address_list = std.net.getAddressList(ctx.allocator, host, port) catch {
            const msg = try std.fmt.allocPrint(ctx.allocator, "❌ Failed to resolve: {s}\n", .{host});
            defer ctx.allocator.free(msg);
            try ctx.stdout.appendSlice(ctx.allocator, msg);
            return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
        };
        defer address_list.deinit();

        if (address_list.addrs.len == 0) {
            const msg = try std.fmt.allocPrint(ctx.allocator, "❌ No addresses found for: {s}\n", .{host});
            defer ctx.allocator.free(msg);
            try ctx.stdout.appendSlice(ctx.allocator, msg);
            return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
        }

        break :blk address_list.addrs[0];
    };

    const stream = std.net.tcpConnectToAddress(address) catch {
        const elapsed = std.time.milliTimestamp() - start_time;
        const msg = try std.fmt.allocPrint(
            ctx.allocator,
            "❌ Connection failed: {s}:{d} ({d}ms)\n",
            .{ host, port, elapsed },
        );
        defer ctx.allocator.free(msg);
        try ctx.stdout.appendSlice(ctx.allocator, msg);
        return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
    };
    defer stream.close();

    const elapsed = std.time.milliTimestamp() - start_time;
    const msg = try std.fmt.allocPrint(
        ctx.allocator,
        "✅ Connection successful: {s}:{d} ({d}ms)\n",
        .{ host, port, elapsed },
    );
    defer ctx.allocator.free(msg);
    try ctx.stdout.appendSlice(ctx.allocator, msg);

    return BuiltinResult{ .status = 0, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
}

/// DNS resolution with details
/// Usage: net-resolve <hostname>
pub fn netResolve(ctx: *Context, args: []const []const u8) !BuiltinResult {
    if (args.len < 2) {
        try ctx.stdout.appendSlice(ctx.allocator, "Usage: net-resolve <hostname>\n");
        return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
    }

    const hostname = args[1];

    const address_list = std.net.getAddressList(ctx.allocator, hostname, 0) catch |err| {
        const msg = try std.fmt.allocPrint(ctx.allocator, "❌ Failed to resolve {s}: {s}\n", .{ hostname, @errorName(err) });
        defer ctx.allocator.free(msg);
        try ctx.stdout.appendSlice(ctx.allocator, msg);
        return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
    };
    defer address_list.deinit();

    if (address_list.addrs.len == 0) {
        const msg = try std.fmt.allocPrint(ctx.allocator, "❌ No addresses found for: {s}\n", .{hostname});
        defer ctx.allocator.free(msg);
        try ctx.stdout.appendSlice(ctx.allocator, msg);
        return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
    }

    const header = try std.fmt.allocPrint(ctx.allocator, "🔍 DNS Resolution: {s}\n", .{hostname});
    defer ctx.allocator.free(header);
    try ctx.stdout.appendSlice(ctx.allocator, header);

    for (address_list.addrs, 0..) |addr, i| {
        // Format IP address directly to avoid buffer size issues
        const line = switch (addr.any.family) {
            std.posix.AF.INET => blk: {
                const ipv4 = @as(*const [4]u8, @ptrCast(&addr.in.sa.addr));
                break :blk try std.fmt.allocPrint(
                    ctx.allocator,
                    "  [{d}] {d}.{d}.{d}.{d}\n",
                    .{ i + 1, ipv4[0], ipv4[1], ipv4[2], ipv4[3] },
                );
            },
            std.posix.AF.INET6 => blk: {
                // For IPv6, just indicate it's an IPv6 address
                break :blk try std.fmt.allocPrint(ctx.allocator, "  [{d}] [IPv6 address]\n", .{i + 1});
            },
            else => try std.fmt.allocPrint(ctx.allocator, "  [{d}] [Unknown family]\n", .{i + 1}),
        };
        defer ctx.allocator.free(line);
        try ctx.stdout.appendSlice(ctx.allocator, line);
    }

    return BuiltinResult{ .status = 0, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
}

/// Simple HTTP GET request
/// Usage: net-fetch <url>
pub fn netFetch(ctx: *Context, args: []const []const u8) !BuiltinResult {
    if (args.len < 2) {
        try ctx.stdout.appendSlice(ctx.allocator, "Usage: net-fetch <url>\n");
        return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
    }

    const url = args[1];

    const header = try std.fmt.allocPrint(ctx.allocator, "🌐 Fetching: {s}\n\n", .{url});
    defer ctx.allocator.free(header);
    try ctx.stdout.appendSlice(ctx.allocator, header);

    var client = std.http.Client{ .allocator = ctx.allocator };
    defer client.deinit();

    // Create an allocating writer to capture the response body
    var response_buffer: std.ArrayList(u8) = .{};
    var allocating_writer = std.Io.Writer.Allocating.fromArrayList(ctx.allocator, &response_buffer);
    defer allocating_writer.deinit();

    const result = client.fetch(.{
        .location = .{ .url = url },
        .response_writer = &allocating_writer.writer,
    }) catch |err| {
        const msg = try std.fmt.allocPrint(
            ctx.allocator,
            "❌ Failed to fetch: {s}\n",
            .{@errorName(err)},
        );
        defer ctx.allocator.free(msg);
        try ctx.stdout.appendSlice(ctx.allocator, msg);
        return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
    };

    // Convert writer back to ArrayList and output the response body
    var result_list = allocating_writer.toArrayList();
    defer result_list.deinit(ctx.allocator);

    try ctx.stdout.appendSlice(ctx.allocator, result_list.items);
    if (result_list.items.len > 0 and result_list.items[result_list.items.len - 1] != '\n') {
        try ctx.stdout.append(ctx.allocator, '\n');
    }

    const status_msg = try std.fmt.allocPrint(
        ctx.allocator,
        "\n✅ Status: {d} - Fetched {d} bytes\n",
        .{ @intFromEnum(result.status), result_list.items.len },
    );
    defer ctx.allocator.free(status_msg);
    try ctx.stdout.appendSlice(ctx.allocator, status_msg);

    return BuiltinResult{ .status = 0, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
}

/// Network scanner for CIDR ranges
/// Usage: net-scan <cidr>
pub fn netScan(ctx: *Context, args: []const []const u8) !BuiltinResult {
    if (args.len < 2) {
        try ctx.stdout.appendSlice(ctx.allocator, "Usage: net-scan <cidr>\n");
        try ctx.stdout.appendSlice(ctx.allocator, "Example: net-scan 192.168.1.0/24\n");
        return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
    }

    const cidr = args[1];

    // Parse CIDR notation
    const slash_pos = std.mem.indexOf(u8, cidr, "/") orelse {
        try ctx.stdout.appendSlice(ctx.allocator, "❌ Invalid CIDR format (expected: x.x.x.x/mask)\n");
        return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
    };

    const ip_str = cidr[0..slash_pos];
    const mask_str = cidr[slash_pos + 1 ..];

    const base_addr = std.net.Address.parseIp4(ip_str, 0) catch {
        try ctx.stdout.appendSlice(ctx.allocator, "❌ Invalid IP address\n");
        return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
    };

    const mask = std.fmt.parseInt(u8, mask_str, 10) catch {
        try ctx.stdout.appendSlice(ctx.allocator, "❌ Invalid network mask\n");
        return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
    };

    if (mask < 16 or mask > 30) {
        try ctx.stdout.appendSlice(ctx.allocator, "❌ Mask must be between 16 and 30 (safety limit)\n");
        return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
    }

    const header = try std.fmt.allocPrint(ctx.allocator, "🔍 Scanning: {s}\n", .{cidr});
    defer ctx.allocator.free(header);
    try ctx.stdout.appendSlice(ctx.allocator, header);

    const host_bits: u5 = @intCast(32 - mask);
    const host_count = (@as(u32, 1) << host_bits) - 2; // Exclude network and broadcast
    const base_ip = base_addr.in.sa.addr;

    var alive_count: u32 = 0;
    var i: u32 = 1;
    while (i <= host_count and i <= 254) : (i += 1) {
        const test_ip = base_ip + i;
        const addr = std.net.Address.initIp4(
            @as([4]u8, @bitCast(@byteSwap(test_ip))),
            80,
        );

        // Try to connect with very short timeout
        const stream = std.net.tcpConnectToAddress(addr) catch {
            continue;
        };
        stream.close();

        alive_count += 1;
        const ip_msg = try std.fmt.allocPrint(
            ctx.allocator,
            "  ✅ {}.{}.{}.{}\n",
            .{
                (test_ip >> 24) & 0xFF,
                (test_ip >> 16) & 0xFF,
                (test_ip >> 8) & 0xFF,
                test_ip & 0xFF,
            },
        );
        defer ctx.allocator.free(ip_msg);
        try ctx.stdout.appendSlice(ctx.allocator, ip_msg);
    }

    const summary = try std.fmt.allocPrint(
        ctx.allocator,
        "\n📊 Found {d} active host(s)\n",
        .{alive_count},
    );
    defer ctx.allocator.free(summary);
    try ctx.stdout.appendSlice(ctx.allocator, summary);

    return BuiltinResult{ .status = 0, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
}
