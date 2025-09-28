const std = @import("std");
const parser = @import("parser.zig");
const executor = @import("executor.zig");
const state = @import("state.zig");

const posix = std.posix;
var sigint_flag = std.atomic.Value(bool).init(false);
var sigtstp_flag = std.atomic.Value(bool).init(false);
const MAX_LINE_BYTES: usize = 1 << 16;

fn signalHandler(sig: c_int) callconv(.c) void {
    if (sig == posix.SIG.INT) {
        sigint_flag.store(true, .seq_cst);
    } else if (sig == posix.SIG.TSTP) {
        sigtstp_flag.store(true, .seq_cst);
    }
}

pub const Shell = struct {
    allocator: std.mem.Allocator,
    config: state.ShellConfig,
    state: state.ShellState,
    handlers_installed: bool = false,

    pub fn init(allocator: std.mem.Allocator, config: state.ShellConfig) !Shell {
        const shell_state = try state.ShellState.init(allocator);
        return Shell{
            .allocator = allocator,
            .config = config,
            .state = shell_state,
            .handlers_installed = false,
        };
    }

    pub fn deinit(self: *Shell) void {
        if (self.handlers_installed) {
            self.restoreDefaultSignals() catch {}; // best effort
        }
        self.state.deinit();
    }

    pub fn runInteractive(self: *Shell) !i32 {
        try self.installSignalHandlers();
        defer self.restoreDefaultSignals() catch {};

        var stdin_file = std.fs.File{ .handle = std.posix.STDIN_FILENO };
        var stdout_file = std.fs.File{ .handle = std.posix.STDOUT_FILENO };
        var stderr_file = std.fs.File{ .handle = std.posix.STDERR_FILENO };

        const is_tty = stdin_file.isTty() and stdout_file.isTty();

        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        var exit_status: i32 = 0;

        while (!self.state.should_exit) {
            arena.reset(.retain_capacity);

            if (self.config.interactive and is_tty) {
                try stdout_file.writeAll(self.config.prompt);
            }

            const maybe_line = readLineAlloc(arena.allocator(), &stdin_file, MAX_LINE_BYTES) catch |err| switch (err) {
                error.InputInterrupted => {
                    if (sigint_flag.swap(false, .seq_cst)) {
                        try stdout_file.writeAll("\n");
                    }
                    continue;
                },
                error.LineTooLong => {
                    try stderr_file.writeAll("error: input line too long\n");
                    continue;
                },
                else => return err,
            };

            if (sigint_flag.swap(false, .seq_cst)) {
                try stdout_file.writeAll("\n");
                continue;
            }
            if (sigtstp_flag.swap(false, .seq_cst)) {
                try stdout_file.writeAll("\n[gshell] job control not implemented yet\n");
                continue;
            }

            if (maybe_line == null) break;
            const line = maybe_line.?;
            if (line.len == 0) {
                continue;
            }

            const trimmed = std.mem.trim(u8, line, " \t\r\n");
            if (trimmed.len == 0) {
                continue;
            }

            try self.restoreDefaultSignals();
            const outcome = self.execute(trimmed, arena.allocator()) catch |err| {
                var msg_buf: [128]u8 = undefined;
                const msg = std.fmt.bufPrint(&msg_buf, "error: {s}\n", .{@errorName(err)}) catch "error: unexpected\n";
                try stderr_file.writeAll(msg);
                try self.installSignalHandlers();
                exit_status = 1;
                continue;
            };
            try self.installSignalHandlers();

            exit_status = outcome.status;
            self.state.exit_code = outcome.status;

            if (outcome.output.len > 0) {
                try stdout_file.writeAll(outcome.output);
                if (outcome.output[outcome.output.len - 1] != '\n') {
                    try stdout_file.writeAll("\n");
                }
            }
        }

        if (self.state.exit_code != 0) return self.state.exit_code;
        return exit_status;
    }

    pub fn runCommand(self: *Shell, command: []const u8) !i32 {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        const trimmed = std.mem.trim(u8, command, " \t\r\n");
        if (trimmed.len == 0) return 0;

        if (self.handlers_installed) try self.restoreDefaultSignals();
        const outcome = try self.execute(trimmed, arena.allocator());
        if (self.handlers_installed) try self.installSignalHandlers();

        self.state.exit_code = outcome.status;
        if (outcome.output.len > 0) {
            var stdout_file = std.fs.File{ .handle = std.posix.STDOUT_FILENO };
            try stdout_file.writeAll(outcome.output);
            if (outcome.output[outcome.output.len - 1] != '\n') {
                try stdout_file.writeAll("\n");
            }
        }

        return outcome.status;
    }

    pub fn runScript(self: *Shell, path: []const u8, args: []const []const u8) !i32 {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        try self.state.setEnv("0", path);
        for (args, 0..) |arg, idx| {
            var key_buf: [12]u8 = undefined;
            const key = try std.fmt.bufPrint(&key_buf, "{d}", .{idx + 1});
            try self.state.setEnv(key, arg);
        }

        var file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
        defer file.close();

        var exit_status: i32 = 0;

        while (true) {
            arena.reset(.retain_capacity);
            const maybe_line = readLineAlloc(arena.allocator(), &file, MAX_LINE_BYTES) catch |err| switch (err) {
                error.InputInterrupted => continue,
                else => return err,
            };
            if (maybe_line == null) break;
            const line = maybe_line.?;

            const trimmed = std.mem.trim(u8, line, " \t\r\n");
            if (trimmed.len == 0 or trimmed[0] == '#') {
                continue;
            }

            const outcome = try self.execute(trimmed, arena.allocator());
            exit_status = outcome.status;
            self.state.exit_code = outcome.status;
            if (self.state.should_exit) break;
        }

        if (self.state.exit_code != 0) return self.state.exit_code;
        return exit_status;
    }

    fn execute(self: *Shell, line: []const u8, allocator: std.mem.Allocator) !executor.ExecOutcome {
        const pipeline = try parser.parseLine(allocator, line);
        return try executor.runPipeline(allocator, &self.state, pipeline);
    }

    fn installSignalHandlers(self: *Shell) !void {
        var action = posix.Sigaction{
            .handler = .{ .handler = signalHandler },
            .mask = std.mem.zeroes(posix.sigset_t),
            .flags = 0,
        };
        _ = posix.sigaction(posix.SIG.INT, &action, null);
        _ = posix.sigaction(posix.SIG.TSTP, &action, null);
        self.handlers_installed = true;
    }

    fn restoreDefaultSignals(self: *Shell) !void {
        var action = posix.Sigaction{
            .handler = .{ .handler = posix.SIG.DFL },
            .mask = std.mem.zeroes(posix.sigset_t),
            .flags = 0,
        };
        _ = posix.sigaction(posix.SIG.INT, &action, null);
        _ = posix.sigaction(posix.SIG.TSTP, &action, null);
        self.handlers_installed = false;
    }
};

const ReadLineError = std.fs.File.ReadError || error{LineTooLong};

fn readLineAlloc(
    allocator: std.mem.Allocator,
    file: *std.fs.File,
    max_len: usize,
) ReadLineError!?[]const u8 {
    var buffer = std.ArrayListUnmanaged(u8){};
    errdefer buffer.deinit(allocator);

    var byte_buf: [1]u8 = undefined;

    while (true) {
        const bytes_read = file.read(&byte_buf) catch |err| switch (err) {
            error.InputInterrupted => return error.InputInterrupted,
            else => return err,
        };

        if (bytes_read == 0) {
            if (buffer.items.len == 0) {
                buffer.deinit(allocator);
                return null;
            }
            break;
        }

        const ch = byte_buf[0];
        if (ch == '\n') {
            break;
        }
        if (ch == '\r') {
            continue;
        }
        if (buffer.items.len >= max_len) {
            return error.LineTooLong;
        }
        try buffer.append(allocator, ch);
    }

    return try buffer.toOwnedSlice(allocator);
}

test "runCommand echo" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var shell = try Shell.init(gpa.allocator(), .{});
    defer shell.deinit();

    const status = try shell.runCommand("echo hello");
    try std.testing.expectEqual(@as(i32, 0), status);
}
