const std = @import("std");
const state = @import("state.zig");

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
    if (std.mem.eql(u8, name, "cd")) return cd;
    if (std.mem.eql(u8, name, "exit")) return exit;
    if (std.mem.eql(u8, name, "echo")) return echo;
    if (std.mem.eql(u8, name, "pwd")) return pwd;
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
