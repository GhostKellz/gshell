const std = @import("std");
const gshell = @import("gshell");

const UsageError = error{
    MissingCommand,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const config = gshell.ShellConfig{};

    var shell = try gshell.Shell.init(allocator, config);
    defer shell.deinit();

    const exit_code = dispatch(&shell, args) catch |err| switch (err) {
        UsageError.MissingCommand => {
            try printUsage();
            return std.process.exit(2);
        },
        else => return err,
    };
    std.process.exit(normalizeExit(exit_code));
}

fn dispatch(shell: *gshell.Shell, args: [][]u8) !i32 {
    if (args.len <= 1) {
        return try shell.runInteractive();
    }

    var idx: usize = 1;
    var command: ?[]const u8 = null;
    var script: ?[]const u8 = null;

    while (idx < args.len) : (idx += 1) {
        const arg = args[idx];
        if (std.mem.eql(u8, arg, "-c") or std.mem.eql(u8, arg, "--command")) {
            idx += 1;
            if (idx >= args.len) return UsageError.MissingCommand;
            command = args[idx];
            idx += 1;
            break;
        } else if (std.mem.eql(u8, arg, "--")) {
            idx += 1;
            if (idx < args.len) {
                script = args[idx];
                idx += 1;
            }
            break;
        } else if (arg.len > 0 and arg[0] == '-') {
            try printUsage();
            std.process.exit(2);
        } else {
            script = arg;
            idx += 1;
            break;
        }
    }

    if (command) |cmd| {
        shell.config.interactive = false;
        return try shell.runCommand(cmd);
    }

    if (script) |path| {
        shell.config.interactive = false;
        var extra_args = std.ArrayListUnmanaged([]const u8){};
        defer extra_args.deinit(shell.allocator);
        const extra = args[idx..];
        for (extra) |arg| {
            try extra_args.append(shell.allocator, arg);
        }
        return try shell.runScript(path, extra_args.items);
    }

    try printUsage();
    return 2;
}

fn normalizeExit(code: i32) u8 {
    if (code < 0) return 255;
    if (code > 255) return 255;
    return @as(u8, @intCast(code));
}

fn printUsage() !void {
    const stderr_writer = std.io.getStdErr().writer();
    try stderr_writer.writeAll(
        "Usage: gshell [-c command] [script.gsh [args...]]\n",
    );
}
