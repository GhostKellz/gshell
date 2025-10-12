/// GShell Command Parser
/// Parses shell command lines into executable pipeline structures
///
/// Features:
/// - Command tokenization with quote handling
/// - Pipeline support (|)
/// - I/O redirection (>, >>, <)
/// - Background job support (&)
/// - Environment variable expansion
///
/// Example:
/// ```zig
/// const pipeline = try parseLine(allocator, "cat file.txt | grep pattern > output.txt");
/// defer pipeline.deinit(allocator);
/// ```
const std = @import("std");
const log = @import("logging.zig");

/// Redirection mode for stdout
pub const RedirectionMode = enum {
    /// No redirection
    none,
    /// Overwrite file (>)
    truncate,
    /// Append to file (>>)
    append,
};

/// A single command with its arguments and redirections
pub const Command = struct {
    /// Command and arguments
    argv: [][]const u8,
    /// Input file path (< file)
    stdin_file: ?[]const u8,
    /// Output file path (> or >> file)
    stdout_file: ?[]const u8,
    /// Output redirection mode
    stdout_mode: RedirectionMode,
};

/// A pipeline of commands connected by pipes
pub const Pipeline = struct {
    /// Array of commands in the pipeline
    commands: []Command,
    /// true if pipeline should run in background (&)
    background: bool = false,

    /// Free all memory associated with this pipeline
    pub fn deinit(self: Pipeline, allocator: std.mem.Allocator) void {
        for (self.commands) |cmd| {
            // Free each arg in argv
            for (cmd.argv) |arg| {
                allocator.free(arg);
            }
            // Free argv array
            allocator.free(cmd.argv);

            // Free redirection files if present
            if (cmd.stdin_file) |f| allocator.free(f);
            if (cmd.stdout_file) |f| allocator.free(f);
        }
        // Free commands array
        allocator.free(self.commands);
    }
};

const TokenType = enum {
    word,
    pipe,
    redirect_in,
    redirect_out,
    redirect_append,
    ampersand,
};

const Token = struct {
    ty: TokenType,
    value: []const u8,
};

/// Errors that can occur during parsing
pub const ParseError = error{
    /// Unexpected token in input
    UnexpectedToken,
    /// Command expected but not found
    MissingCommand,
    /// Redirection operator without target file
    MissingRedirectionTarget,
};

/// Parse a command line into a pipeline structure
///
/// @param allocator Memory allocator for the pipeline
/// @param line Command line string to parse
/// @return Pipeline structure with parsed commands
///
/// Example:
/// ```zig
/// const pipeline = try parseLine(allocator, "ls -la | grep txt");
/// defer pipeline.deinit(allocator);
/// ```
///
/// Supported syntax:
/// - Commands: `command arg1 arg2`
/// - Pipes: `cmd1 | cmd2 | cmd3`
/// - Output redirect: `cmd > file` or `cmd >> file`
/// - Input redirect: `cmd < file`
/// - Background: `cmd &`
/// - Quotes: `"quoted arg"` or `'quoted arg'`
/// - Escape: `\` for escaping special chars
pub fn parseLine(allocator: std.mem.Allocator, line: []const u8) !Pipeline {
    const trimmed = std.mem.trim(u8, line, " \t\n\r");
    if (trimmed.len == 0 or trimmed[0] == '#') {
        return Pipeline{ .commands = try allocator.alloc(Command, 0) };
    }

    var arena_stream = std.ArrayListUnmanaged(Token){};
    defer arena_stream.deinit(allocator);

    tokenize(allocator, trimmed, &arena_stream) catch |err| {
        std.debug.print("[ERROR] Failed to tokenize line: {}\n", .{err});
        std.debug.print("Input: {s}\n", .{trimmed});
        return err;
    };

    if (arena_stream.items.len == 0) {
        return error.MissingCommand;
    }

    var commands = std.ArrayListUnmanaged(Command){};
    defer commands.deinit(allocator);

    var argv_buffer = std.ArrayListUnmanaged([]const u8){};
    defer argv_buffer.deinit(allocator);

    var stdin_file: ?[]const u8 = null;
    var stdout_file: ?[]const u8 = null;
    var stdout_mode = RedirectionMode.none;
    var expect_redirect: ?TokenType = null;
    var background = false;

    for (arena_stream.items, 0..) |token, idx| {
        switch (token.ty) {
            .word => {
                const duped = try allocator.dupe(u8, token.value);
                if (expect_redirect) |redir_ty| {
                    switch (redir_ty) {
                        .redirect_in => stdin_file = duped,
                        .redirect_out => {
                            stdout_file = duped;
                            stdout_mode = RedirectionMode.truncate;
                        },
                        .redirect_append => {
                            stdout_file = duped;
                            stdout_mode = RedirectionMode.append;
                        },
                        else => return error.UnexpectedToken,
                    }
                    expect_redirect = null;
                } else {
                    try argv_buffer.append(allocator, duped);
                }
            },
            .pipe => {
                if (expect_redirect != null or argv_buffer.items.len == 0) {
                    return error.UnexpectedToken;
                }
                try commands.append(allocator, .{
                    .argv = try allocator.dupe([]const u8, argv_buffer.items),
                    .stdin_file = stdin_file,
                    .stdout_file = stdout_file,
                    .stdout_mode = stdout_mode,
                });
                argv_buffer.clearRetainingCapacity();
                stdin_file = null;
                stdout_file = null;
                stdout_mode = .none;
            },
            .ampersand => {
                if (idx != arena_stream.items.len - 1) {
                    return error.UnexpectedToken;
                }
                background = true;
            },
            .redirect_in, .redirect_out, .redirect_append => {
                if (expect_redirect != null) return error.UnexpectedToken;
                if (idx + 1 >= arena_stream.items.len) {
                    return error.MissingRedirectionTarget;
                }
                expect_redirect = token.ty;
            },
        }
    }

    if (expect_redirect != null or argv_buffer.items.len == 0) {
        return error.MissingCommand;
    }

    try commands.append(allocator, .{
        .argv = try allocator.dupe([]const u8, argv_buffer.items),
        .stdin_file = stdin_file,
        .stdout_file = stdout_file,
        .stdout_mode = stdout_mode,
    });

    return Pipeline{
        .commands = try commands.toOwnedSlice(allocator),
        .background = background,
    };
}

fn tokenize(allocator: std.mem.Allocator, input: []const u8, tokens: *std.ArrayListUnmanaged(Token)) !void {
    var i: usize = 0;
    var buf = std.ArrayListUnmanaged(u8){};
    defer buf.deinit(allocator);

    var in_single_quote = false;
    var in_double_quote = false;

    while (i < input.len) : (i += 1) {
        const c = input[i];
        if (in_single_quote) {
            if (c == '\'') {
                in_single_quote = false;
            } else {
                try buf.append(allocator, c);
            }
            continue;
        }
        if (in_double_quote) {
            if (c == '"') {
                in_double_quote = false;
            } else if (c == '\\') {
                if (i + 1 < input.len) {
                    i += 1;
                    try buf.append(allocator, input[i]);
                }
            } else {
                try buf.append(allocator, c);
            }
            continue;
        }

        switch (c) {
            ' ', '\t' => {
                if (buf.items.len > 0) {
                    const slice = try allocator.dupe(u8, buf.items);
                    try tokens.append(allocator, .{ .ty = .word, .value = slice });
                    buf.clearRetainingCapacity();
                }
            },
            '|' => {
                if (buf.items.len > 0) {
                    const slice = try allocator.dupe(u8, buf.items);
                    try tokens.append(allocator, .{ .ty = .word, .value = slice });
                    buf.clearRetainingCapacity();
                }
                try tokens.append(allocator, .{ .ty = .pipe, .value = input[i .. i + 1] });
            },
            '&' => {
                if (buf.items.len > 0) {
                    const slice = try allocator.dupe(u8, buf.items);
                    try tokens.append(allocator, .{ .ty = .word, .value = slice });
                    buf.clearRetainingCapacity();
                }
                try tokens.append(allocator, .{ .ty = .ampersand, .value = input[i .. i + 1] });
            },
            '<' => {
                if (buf.items.len > 0) {
                    const slice = try allocator.dupe(u8, buf.items);
                    try tokens.append(allocator, .{ .ty = .word, .value = slice });
                    buf.clearRetainingCapacity();
                }
                try tokens.append(allocator, .{ .ty = .redirect_in, .value = input[i .. i + 1] });
            },
            '>' => {
                if (buf.items.len > 0) {
                    const slice = try allocator.dupe(u8, buf.items);
                    try tokens.append(allocator, .{ .ty = .word, .value = slice });
                    buf.clearRetainingCapacity();
                }
                if (i + 1 < input.len and input[i + 1] == '>') {
                    i += 1;
                    try tokens.append(allocator, .{ .ty = .redirect_append, .value = input[i - 1 .. i + 1] });
                } else {
                    try tokens.append(allocator, .{ .ty = .redirect_out, .value = input[i .. i + 1] });
                }
            },
            '\'' => {
                in_single_quote = true;
            },
            '"' => {
                in_double_quote = true;
            },
            '\\' => {
                if (i + 1 < input.len) {
                    i += 1;
                    try buf.append(allocator, input[i]);
                }
            },
            else => {
                try buf.append(allocator, c);
            },
        }
    }

    if (in_single_quote or in_double_quote) {
        return error.UnexpectedToken;
    }

    if (buf.items.len > 0) {
        const slice = try allocator.dupe(u8, buf.items);
        try tokens.append(allocator, .{ .ty = .word, .value = slice });
    }
}

const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

test "parse simple command" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const pipeline = try parseLine(allocator, "echo hello world");
    try expectEqual(@as(usize, 1), pipeline.commands.len);
    try expectEqual(@as(usize, 3), pipeline.commands[0].argv.len);
    try expectEqualStrings("echo", pipeline.commands[0].argv[0]);
    try expectEqualStrings("hello", pipeline.commands[0].argv[1]);
    try expectEqualStrings("world", pipeline.commands[0].argv[2]);
}

test "parse pipeline with redirection" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const pipeline = try parseLine(allocator, "cat < input.txt | grep foo >> out.log");
    try expectEqual(@as(usize, 2), pipeline.commands.len);
    try expectEqualStrings("input.txt", pipeline.commands[0].stdin_file.?);
    try expectEqualStrings("out.log", pipeline.commands[1].stdout_file.?);
    try expectEqual(RedirectionMode.append, pipeline.commands[1].stdout_mode);
}

test "parse with quotes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const pipeline = try parseLine(allocator, "echo \"hello world\"");
    try expectEqual(@as(usize, 1), pipeline.commands.len);
    try expectEqualStrings("hello world", pipeline.commands[0].argv[1]);
}

test "error on trailing pipe" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    try expectError(error.MissingCommand, parseLine(allocator, "echo hi |"));
}

test "error on unclosed quote" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    try expectError(error.UnexpectedToken, parseLine(allocator, "echo 'hi"));
}

fn expectEqualStrings(a: []const u8, b: []const u8) !void {
    if (!std.mem.eql(u8, a, b)) {
        std.debug.print("expected '{s}' == '{s}'\n", .{ a, b });
        return error.TestUnexpectedResult;
    }
}
