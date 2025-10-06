const std = @import("std");
const parser = @import("parser.zig");
const state = @import("state.zig");
const builtins = @import("builtins.zig");
const security = @import("security.zig");

pub const ExecOutcome = struct {
    status: i32,
    output: []const u8,
    job_id: ?u32 = null,
};

pub fn runPipeline(
    allocator: std.mem.Allocator,
    shell_state: *state.ShellState,
    pipeline: parser.Pipeline,
) !ExecOutcome {
    if (pipeline.commands.len == 0) {
        return ExecOutcome{ .status = 0, .output = &[_]u8{} };
    }

    if (pipeline.background) {
        return try runPipelineBackground(allocator, shell_state, pipeline);
    }

    var previous_output: []const u8 = &[_]u8{};
    var status: i32 = 0;

    for (pipeline.commands, 0..) |command, idx| {
        var effective_input = previous_output;
        if (command.stdin_file) |path| {
            effective_input = try readFileAll(allocator, path);
        }

        var expanded_args = try expandArgs(allocator, shell_state, command.argv);
        defer {
            for (expanded_args) |arg| allocator.free(arg);
            allocator.free(expanded_args);
        }

        if (expanded_args.len == 0) {
            continue;
        }

        // Check for alias expansion
        if (shell_state.getAlias(expanded_args[0])) |alias_value| {
            // Parse the alias value into separate words
            var alias_parts = std.ArrayListUnmanaged([]const u8){};
            defer alias_parts.deinit(allocator);

            var iter = std.mem.tokenizeScalar(u8, alias_value, ' ');
            while (iter.next()) |part| {
                try alias_parts.append(allocator, try allocator.dupe(u8, part));
            }

            // Append remaining args after the command name
            for (expanded_args[1..]) |arg| {
                try alias_parts.append(allocator, try allocator.dupe(u8, arg));
            }

            // Replace expanded_args with alias expansion
            for (expanded_args) |arg| allocator.free(arg);
            allocator.free(expanded_args);
            expanded_args = try alias_parts.toOwnedSlice(allocator);
        }

        if (builtins.lookup(expanded_args[0])) |handler| {
            var stdout_buf = std.ArrayListUnmanaged(u8){};
            defer stdout_buf.deinit(allocator);

            var ctx = builtins.Context{
                .allocator = allocator,
                .stdout = &stdout_buf,
                .stdin_data = effective_input,
                .shell_state = shell_state,
            };

            const result = try handler(&ctx, expanded_args);
            status = result.status;

            if (result.output.len > 0) {
                previous_output = result.output;
            } else if (stdout_buf.items.len > 0) {
                previous_output = try stdout_buf.toOwnedSlice(allocator);
            } else {
                previous_output = &[_]u8{};
            }
        } else {
            const exec_result = try runExternal(allocator, shell_state, expanded_args, effective_input);
            status = exec_result.status;
            previous_output = exec_result.output;
        }

        if (command.stdout_file) |path| {
            try writeOutput(path, command.stdout_mode, previous_output);
            previous_output = &[_]u8{};
        }

        if (idx < pipeline.commands.len - 1 and previous_output.len == 0) {
            previous_output = &[_]u8{};
        }
    }

    return ExecOutcome{ .status = status, .output = previous_output };
}

fn expandArgs(
    allocator: std.mem.Allocator,
    shell_state: *state.ShellState,
    raw_args: [][]const u8,
) ![]const []const u8 {
    var list = std.ArrayListUnmanaged([]const u8){};
    defer list.deinit(allocator);

    for (raw_args) |arg| {
        try list.append(allocator, try expandArg(allocator, shell_state, arg));
    }

    return try list.toOwnedSlice(allocator);
}

fn expandArg(
    allocator: std.mem.Allocator,
    shell_state: *state.ShellState,
    arg: []const u8,
) ![]const u8 {
    if (std.mem.indexOf(u8, arg, "$")) |pos| {
        _ = pos;
    } else {
        return arg;
    }

    var buffer = std.ArrayListUnmanaged(u8){};
    defer buffer.deinit(allocator);

    var i: usize = 0;
    while (i < arg.len) {
        if (arg[i] == '$') {
            i += 1;
            const start = i;
            while (i < arg.len and isIdentChar(arg[i])) : (i += 1) {}
            const name = arg[start..i];
            if (shell_state.getEnv(name)) |value| {
                try buffer.appendSlice(allocator, value);
            }
        } else {
            try buffer.append(allocator, arg[i]);
            i += 1;
        }
    }

    return try buffer.toOwnedSlice(allocator);
}

fn isIdentChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_' or c == '?';
}

fn runExternal(
    allocator: std.mem.Allocator,
    shell_state: *state.ShellState,
    args: []const []const u8,
    input_data: []const u8,
) !ExecOutcome {
    var proc = std.process.Child.init(args, allocator);

    const needs_input = input_data.len > 0;

    proc.stdin_behavior = if (needs_input) .Pipe else .Inherit;
    proc.stdout_behavior = .Pipe;
    proc.stderr_behavior = .Inherit;

    proc.env_map = &shell_state.env;

    try proc.spawn();

    if (needs_input) {
        if (proc.stdin) |stdin_stream| {
            try stdin_stream.writeAll(input_data);
            // Don't manually close - wait() will handle cleanup
        }
    }

    var output_buffer = std.ArrayListUnmanaged(u8){};
    defer output_buffer.deinit(allocator);

    if (proc.stdout) |stdout_stream| {
        var temp: [4096]u8 = undefined;
        while (true) {
            const bytes = try stdout_stream.read(&temp);
            if (bytes == 0) break;
            try output_buffer.appendSlice(allocator, temp[0..bytes]);
        }
        // Don't manually close - wait() will handle cleanup
    }

    const term = try proc.wait();
    switch (term) {
        .Exited => |code| {
            return ExecOutcome{
                .status = @as(i32, @intCast(code)),
                .output = try output_buffer.toOwnedSlice(allocator),
            };
        },
        .Signal => |signum| {
            const sig_i32 = std.math.cast(i32, signum) orelse -1;
            shell_state.setExit(sig_i32);
            return ExecOutcome{
                .status = sig_i32,
                .output = try output_buffer.toOwnedSlice(allocator),
            };
        },
        else => {
            return ExecOutcome{
                .status = -1,
                .output = try output_buffer.toOwnedSlice(allocator),
            };
        },
    }
}

fn readFileAll(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    // Security: Validate path to prevent directory traversal
    try security.validateReadPath(allocator, path);

    var file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    defer file.close();
    const size = try file.getEndPos();

    // Security: Limit file size to 100MB to prevent memory exhaustion
    if (size > 100 * 1024 * 1024) {
        return error.FileTooLarge;
    }

    var buffer = try allocator.alloc(u8, @as(usize, @intCast(size)));
    const read = try file.readAll(buffer);
    return buffer[0..read];
}

fn writeOutput(path: []const u8, mode: parser.RedirectionMode, data: []const u8) !void {
    // Security: Validate path to prevent directory traversal and unsafe writes
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    try security.validateWritePath(allocator, path);

    var file = try std.fs.cwd().createFile(path, .{
        .truncate = mode == .truncate,
        .read = false,
    });
    defer file.close();

    if (mode == .append) {
        try file.seekFromEnd(0);
    }

    if (data.len > 0) {
        try file.writeAll(data);
    }
}

fn runPipelineBackground(
    allocator: std.mem.Allocator,
    shell_state: *state.ShellState,
    pipeline: parser.Pipeline,
) !ExecOutcome {
    if (pipeline.commands.len != 1) {
        return error.UnsupportedPipeline;
    }

    const command = pipeline.commands[0];
    const expanded_args = try expandArgs(allocator, shell_state, command.argv);
    if (expanded_args.len == 0) {
        return ExecOutcome{ .status = 0, .output = &[_]u8{} };
    }

    var proc = std.process.Child.init(expanded_args, allocator);
    proc.stdin_behavior = .Ignore;
    proc.stdout_behavior = .Ignore;
    proc.stderr_behavior = .Inherit;
    proc.env_map = &shell_state.env;

    try proc.spawn();

    var command_str = std.ArrayListUnmanaged(u8){};
    defer command_str.deinit(allocator);
    for (expanded_args, 0..) |arg, idx| {
        if (idx > 0) try command_str.append(allocator, ' ');
        try command_str.appendSlice(allocator, arg);
    }

    const job_id = try shell_state.addJob(proc.id, command_str.items);

    return ExecOutcome{
        .status = 0,
        .output = &[_]u8{},
        .job_id = job_id,
    };
}

fn expectEqualStrings(a: []const u8, b: []const u8) !void {
    if (!std.mem.eql(u8, a, b)) return error.TestUnexpectedResult;
}

test "expand simple argument" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var shell_state = try state.ShellState.init(arena.allocator());
    defer shell_state.deinit();

    try shell_state.setEnv("USER", "ghost");
    const expanded = try expandArg(arena.allocator(), &shell_state, "$USER");
    try expectEqualStrings("ghost", expanded);
}
