const std = @import("std");
const state = @import("state.zig");
const networking = @import("builtins/networking.zig");

pub const BuiltinResult = struct {
    status: i32 = 0,
    output: []const u8 = &[_]u8{},
};

pub const Context = struct {
    allocator: std.mem.Allocator,
    stdout: *std.ArrayListUnmanaged(u8),
    stdin_data: []const u8,
    shell_state: *state.ShellState,
};

pub const Handler = *const fn (*Context, []const []const u8) anyerror!BuiltinResult;

pub fn lookup(name: []const u8) ?Handler {
    // Core built-ins
    if (std.mem.eql(u8, name, "cd")) return cd;
    if (std.mem.eql(u8, name, "exit")) return exit;
    if (std.mem.eql(u8, name, "echo")) return echo;
    if (std.mem.eql(u8, name, "pwd")) return pwd;
    if (std.mem.eql(u8, name, "jobs")) return jobs;
    if (std.mem.eql(u8, name, "fg")) return fg;
    if (std.mem.eql(u8, name, "bg")) return bg;
    if (std.mem.eql(u8, name, "alias")) return alias;
    if (std.mem.eql(u8, name, "unalias")) return unalias;

    // Networking utilities
    if (std.mem.eql(u8, name, "net-test")) return netTest;
    if (std.mem.eql(u8, name, "net-resolve")) return netResolve;
    if (std.mem.eql(u8, name, "net-fetch")) return netFetch;
    if (std.mem.eql(u8, name, "net-scan")) return netScan;

    return null;
}

fn cd(ctx: *Context, args: []const []const u8) !BuiltinResult {
    const target = if (args.len > 1)
        args[1]
    else if (ctx.shell_state.getEnv("HOME")) |home|
        home
    else
        ".";

    var path_z = try ctx.allocator.allocSentinel(u8, target.len, 0);
    defer ctx.allocator.free(path_z);
    std.mem.copyForwards(u8, path_z[0..target.len], target);
    try std.posix.chdir(path_z);
    return BuiltinResult{ .status = 0 };
}

fn pwd(ctx: *Context, args: []const []const u8) !BuiltinResult {
    _ = args;
    const path = try std.fs.cwd().realpathAlloc(ctx.allocator, ".");
    defer ctx.allocator.free(path);
    try ctx.stdout.appendSlice(ctx.allocator, path);
    try ctx.stdout.append(ctx.allocator, '\n');
    return BuiltinResult{ .status = 0, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
}

fn echo(ctx: *Context, args: []const []const u8) !BuiltinResult {
    if (args.len <= 1) {
        try ctx.stdout.append(ctx.allocator, '\n');
    } else {
        for (args[1..], 0..) |arg, idx| {
            if (idx > 0) try ctx.stdout.append(ctx.allocator, ' ');
            try ctx.stdout.appendSlice(ctx.allocator, arg);
        }
        try ctx.stdout.append(ctx.allocator, '\n');
    }
    return BuiltinResult{ .status = 0, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
}

fn exit(ctx: *Context, args: []const []const u8) !BuiltinResult {
    var code: i32 = 0;
    if (args.len > 1) {
        code = try std.fmt.parseInt(i32, args[1], 10);
    }
    ctx.shell_state.setExit(code);
    return BuiltinResult{ .status = code };
}

fn jobs(ctx: *Context, args: []const []const u8) !BuiltinResult {
    _ = args;
    for (ctx.shell_state.jobs.items) |job| {
        const status_str = switch (job.status) {
            .running => "Running",
            .stopped => "Stopped",
            .done => "Done",
        };
        const line = try std.fmt.allocPrint(ctx.allocator, "[{d}]  {s}  {s}\n", .{ job.id, status_str, job.command });
        defer ctx.allocator.free(line);
        try ctx.stdout.appendSlice(ctx.allocator, line);
    }
    return BuiltinResult{ .status = 0, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
}

fn fg(ctx: *Context, args: []const []const u8) !BuiltinResult {
    var job_id: u32 = 0;
    if (args.len > 1) {
        job_id = try std.fmt.parseInt(u32, args[1], 10);
    } else if (ctx.shell_state.jobs.items.len > 0) {
        job_id = ctx.shell_state.jobs.items[ctx.shell_state.jobs.items.len - 1].id;
    } else {
        try ctx.stdout.appendSlice(ctx.allocator, "fg: no current job\n");
        return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
    }

    if (ctx.shell_state.getJob(job_id)) |job| {
        _ = std.posix.kill(job.pid, std.posix.SIG.CONT) catch |err| {
            const msg = try std.fmt.allocPrint(ctx.allocator, "fg: failed to continue job {d}: {s}\n", .{ job_id, @errorName(err) });
            defer ctx.allocator.free(msg);
            try ctx.stdout.appendSlice(ctx.allocator, msg);
            return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
        };

        const wait_result = std.posix.waitpid(job.pid, 0);

        const exit_status: i32 = if (std.posix.W.IFEXITED(wait_result.status))
            @intCast(std.posix.W.EXITSTATUS(wait_result.status))
        else if (std.posix.W.IFSIGNALED(wait_result.status))
            128 + @as(i32, @intCast(std.posix.W.TERMSIG(wait_result.status)))
        else
            1;

        ctx.shell_state.removeJob(job_id);
        return BuiltinResult{ .status = exit_status };
    } else {
        const msg = try std.fmt.allocPrint(ctx.allocator, "fg: job {d} not found\n", .{job_id});
        defer ctx.allocator.free(msg);
        try ctx.stdout.appendSlice(ctx.allocator, msg);
        return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
    }
}

fn bg(ctx: *Context, args: []const []const u8) !BuiltinResult {
    var job_id: u32 = 0;
    if (args.len > 1) {
        job_id = try std.fmt.parseInt(u32, args[1], 10);
    } else if (ctx.shell_state.jobs.items.len > 0) {
        job_id = ctx.shell_state.jobs.items[ctx.shell_state.jobs.items.len - 1].id;
    } else {
        try ctx.stdout.appendSlice(ctx.allocator, "bg: no current job\n");
        return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
    }

    if (ctx.shell_state.getJob(job_id)) |job| {
        _ = std.posix.kill(job.pid, std.posix.SIG.CONT) catch |err| {
            const msg = try std.fmt.allocPrint(ctx.allocator, "bg: failed to continue job {d}: {s}\n", .{ job_id, @errorName(err) });
            defer ctx.allocator.free(msg);
            try ctx.stdout.appendSlice(ctx.allocator, msg);
            return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
        };

        job.status = .running;
        const msg = try std.fmt.allocPrint(ctx.allocator, "[{d}] continued  {s}\n", .{ job.id, job.command });
        defer ctx.allocator.free(msg);
        try ctx.stdout.appendSlice(ctx.allocator, msg);
        return BuiltinResult{ .status = 0, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
    } else {
        const msg = try std.fmt.allocPrint(ctx.allocator, "bg: job {d} not found\n", .{job_id});
        defer ctx.allocator.free(msg);
        try ctx.stdout.appendSlice(ctx.allocator, msg);
        return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
    }
}

fn alias(ctx: *Context, args: []const []const u8) !BuiltinResult {
    // If no args, print all aliases
    if (args.len == 1) {
        var alias_iter = ctx.shell_state.aliases.iterator();
        while (alias_iter.next()) |entry| {
            const line = try std.fmt.allocPrint(ctx.allocator, "alias {s}='{s}'\n", .{ entry.key_ptr.*, entry.value_ptr.* });
            defer ctx.allocator.free(line);
            try ctx.stdout.appendSlice(ctx.allocator, line);
        }
        return BuiltinResult{ .status = 0, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
    }

    // Parse alias definition: alias name=value
    const arg = args[1];
    const eq_pos = std.mem.indexOf(u8, arg, "=") orelse {
        // No '=', just print this specific alias if it exists
        if (ctx.shell_state.getAlias(arg)) |value| {
            const line = try std.fmt.allocPrint(ctx.allocator, "alias {s}='{s}'\n", .{ arg, value });
            defer ctx.allocator.free(line);
            try ctx.stdout.appendSlice(ctx.allocator, line);
            return BuiltinResult{ .status = 0, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
        } else {
            const msg = try std.fmt.allocPrint(ctx.allocator, "alias: {s}: not found\n", .{arg});
            defer ctx.allocator.free(msg);
            try ctx.stdout.appendSlice(ctx.allocator, msg);
            return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
        }
    };

    const name = arg[0..eq_pos];
    const value = arg[eq_pos + 1 ..];

    // Remove quotes if present
    const clean_value = if (value.len >= 2 and ((value[0] == '\'' and value[value.len - 1] == '\'') or (value[0] == '"' and value[value.len - 1] == '"')))
        value[1 .. value.len - 1]
    else
        value;

    try ctx.shell_state.setAlias(name, clean_value);
    return BuiltinResult{ .status = 0 };
}

fn unalias(ctx: *Context, args: []const []const u8) !BuiltinResult {
    if (args.len < 2) {
        try ctx.stdout.appendSlice(ctx.allocator, "unalias: usage: unalias name\n");
        return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
    }

    const name = args[1];
    if (ctx.shell_state.removeAlias(name)) {
        return BuiltinResult{ .status = 0 };
    } else {
        const msg = try std.fmt.allocPrint(ctx.allocator, "unalias: {s}: not found\n", .{name});
        defer ctx.allocator.free(msg);
        try ctx.stdout.appendSlice(ctx.allocator, msg);
        return BuiltinResult{ .status = 1, .output = try ctx.stdout.toOwnedSlice(ctx.allocator) };
    }
}

// Networking command wrappers
fn netTest(ctx: *Context, args: []const []const u8) !BuiltinResult {
    var net_ctx = networking.Context{
        .allocator = ctx.allocator,
        .stdout = ctx.stdout,
    };
    const result = try networking.netTest(&net_ctx, args);
    return BuiltinResult{ .status = result.status, .output = result.output };
}

fn netResolve(ctx: *Context, args: []const []const u8) !BuiltinResult {
    var net_ctx = networking.Context{
        .allocator = ctx.allocator,
        .stdout = ctx.stdout,
    };
    const result = try networking.netResolve(&net_ctx, args);
    return BuiltinResult{ .status = result.status, .output = result.output };
}

fn netFetch(ctx: *Context, args: []const []const u8) !BuiltinResult {
    var net_ctx = networking.Context{
        .allocator = ctx.allocator,
        .stdout = ctx.stdout,
    };
    const result = try networking.netFetch(&net_ctx, args);
    return BuiltinResult{ .status = result.status, .output = result.output };
}

fn netScan(ctx: *Context, args: []const []const u8) !BuiltinResult {
    var net_ctx = networking.Context{
        .allocator = ctx.allocator,
        .stdout = ctx.stdout,
    };
    const result = try networking.netScan(&net_ctx, args);
    return BuiltinResult{ .status = result.status, .output = result.output };
}

test "echo builtin" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var stdout = std.ArrayListUnmanaged(u8){};
    defer stdout.deinit(arena.allocator());
    var fake_state = try state.ShellState.init(arena.allocator());
    defer fake_state.deinit();

    var ctx = Context{
        .allocator = arena.allocator(),
        .stdout = &stdout,
        .stdin_data = &[_]u8{},
        .shell_state = &fake_state,
    };

    const sample = [_][]const u8{ "echo", "hello", "world" };
    const res = try echo(&ctx, sample[0..]);
    try std.testing.expectEqual(@as(i32, 0), res.status);
    try std.testing.expect(std.mem.eql(u8, res.output, "hello world\n"));
}
