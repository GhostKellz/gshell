const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const net = std.Io.net;
const zhttp = @import("zhttp");

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

    const start_time = (try std.time.Instant.now()).timestamp.nsec;

    // Create Io runtime for networking
    var io_runtime = std.Io.Threaded.init(ctx.allocator);
    defer io_runtime.deinit();
    const io = io_runtime.io();

    // Try to connect
    const address = net.IpAddress.parse(host, port) catch {
        const msg = try std.fmt.allocPrint(ctx.allocator, "❌ Failed to parse IP: {s}\n", .{host});
        defer ctx.allocator.free(msg);
        try ctx.stdout.appendSlice(ctx.allocator, msg);
        return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
    };

    const stream = address.connect(io, .{ .mode = .stream }) catch {
        const elapsed = @divFloor((try std.time.Instant.now()).timestamp.nsec - start_time, 1_000_000);
        const msg = try std.fmt.allocPrint(
            ctx.allocator,
            "❌ Connection failed: {s}:{d} ({d}ms)\n",
            .{ host, port, elapsed },
        );
        defer ctx.allocator.free(msg);
        try ctx.stdout.appendSlice(ctx.allocator, msg);
        return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
    };
    defer stream.close(io);

    const elapsed = @divFloor((try std.time.Instant.now()).timestamp.nsec - start_time, 1_000_000);
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

    // Use getaddrinfo for DNS resolution
    const hostname_z = try ctx.allocator.dupeZ(u8, hostname);
    defer ctx.allocator.free(hostname_z);

    const hints = std.posix.addrinfo{
        .flags = std.posix.AI{},
        .family = std.posix.AF.UNSPEC,
        .socktype = std.posix.SOCK.STREAM,
        .protocol = std.posix.IPPROTO.TCP,
        .addrlen = 0,
        .addr = null,
        .canonname = null,
        .next = null,
    };

    var result: ?*std.posix.addrinfo = null;
    const rc = std.c.getaddrinfo(hostname_z.ptr, null, &hints, &result);
    if (@intFromEnum(rc) != 0 or result == null) {
        const msg = try std.fmt.allocPrint(ctx.allocator, "❌ Failed to resolve {s}\n", .{hostname});
        defer ctx.allocator.free(msg);
        try ctx.stdout.appendSlice(ctx.allocator, msg);
        return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
    }
    defer std.c.freeaddrinfo(result.?);

    const first_result = result.?;

    const header = try std.fmt.allocPrint(ctx.allocator, "🔍 DNS Resolution: {s}\n", .{hostname});
    defer ctx.allocator.free(header);
    try ctx.stdout.appendSlice(ctx.allocator, header);

    var current: ?*std.posix.addrinfo = first_result;
    var index: usize = 1;
    while (current) |addr_info| : (current = addr_info.next) {
        if (addr_info.addr) |sockaddr| {
            const line = switch (sockaddr.family) {
                std.posix.AF.INET => blk: {
                    const addr_in = @as(*const std.posix.sockaddr.in, @ptrCast(@alignCast(sockaddr)));
                    const ip_bytes = @as(*const [4]u8, @ptrCast(&addr_in.addr));
                    break :blk try std.fmt.allocPrint(
                        ctx.allocator,
                        "  [{d}] {d}.{d}.{d}.{d} (IPv4)\n",
                        .{ index, ip_bytes[0], ip_bytes[1], ip_bytes[2], ip_bytes[3] },
                    );
                },
                std.posix.AF.INET6 => blk: {
                    // For IPv6, just indicate it's an IPv6 address
                    break :blk try std.fmt.allocPrint(ctx.allocator, "  [{d}] [IPv6 address]\n", .{index});
                },
                else => try std.fmt.allocPrint(ctx.allocator, "  [{d}] [Unknown family]\n", .{index}),
            };
            defer ctx.allocator.free(line);
            try ctx.stdout.appendSlice(ctx.allocator, line);
            index += 1;
        }
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

    // Use zhttp for HTTP requests
    var response = zhttp.get(ctx.allocator, url) catch |err| {
        const msg = try std.fmt.allocPrint(
            ctx.allocator,
            "❌ Failed to fetch: {s}\n",
            .{@errorName(err)},
        );
        defer ctx.allocator.free(msg);
        try ctx.stdout.appendSlice(ctx.allocator, msg);
        return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
    };
    defer response.deinit();

    // Read the response body
    const body = response.body_reader.readAll(10 * 1024 * 1024) catch {
        const msg = try std.fmt.allocPrint(ctx.allocator, "❌ Failed to read response body\n", .{});
        defer ctx.allocator.free(msg);
        try ctx.stdout.appendSlice(ctx.allocator, msg);
        return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
    };
    defer ctx.allocator.free(body);

    // Output response body
    if (body.len > 0) {
        try ctx.stdout.appendSlice(ctx.allocator, body);
        if (body[body.len - 1] != '\n') {
            try ctx.stdout.append(ctx.allocator, '\n');
        }
    }

    const status_msg = try std.fmt.allocPrint(
        ctx.allocator,
        "\n✅ Status: {d} - Fetched {d} bytes\n",
        .{ response.status, body.len },
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

    // Parse the base IP address
    const base_ip_addr = net.IpAddress.parse(ip_str, 0) catch {
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

    // Create Io runtime for networking
    var io_runtime = std.Io.Threaded.init(ctx.allocator);
    defer io_runtime.deinit();
    const io = io_runtime.io();

    const host_bits: u5 = @intCast(32 - mask);
    const host_count = (@as(u32, 1) << host_bits) - 2; // Exclude network and broadcast

    // Extract base IP bytes
    const base_ip_bytes = switch (base_ip_addr) {
        .ip4 => |ip4| ip4.bytes,
        .ip6 => {
            try ctx.stdout.appendSlice(ctx.allocator, "❌ IPv6 not supported for scanning\n");
            return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
        },
    };

    const base_ip_u32 = @as(u32, base_ip_bytes[0]) << 24 |
                        @as(u32, base_ip_bytes[1]) << 16 |
                        @as(u32, base_ip_bytes[2]) << 8 |
                        @as(u32, base_ip_bytes[3]);

    var alive_count: u32 = 0;
    var i: u32 = 1;
    while (i <= host_count and i <= 254) : (i += 1) {
        const test_ip_u32 = base_ip_u32 + i;
        const test_ip_bytes = [4]u8{
            @intCast((test_ip_u32 >> 24) & 0xFF),
            @intCast((test_ip_u32 >> 16) & 0xFF),
            @intCast((test_ip_u32 >> 8) & 0xFF),
            @intCast(test_ip_u32 & 0xFF),
        };

        const test_addr = net.IpAddress{ .ip4 = .{
            .bytes = test_ip_bytes,
            .port = 80,
        }};

        // Try to connect with very short timeout
        const stream = test_addr.connect(io, .{ .mode = .stream }) catch {
            continue;
        };
        stream.close(io);

        alive_count += 1;
        const ip_msg = try std.fmt.allocPrint(
            ctx.allocator,
            "  ✅ {d}.{d}.{d}.{d}\n",
            .{
                test_ip_bytes[0],
                test_ip_bytes[1],
                test_ip_bytes[2],
                test_ip_bytes[3],
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
