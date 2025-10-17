const std = @import("std");
const zlog = @import("zlog");

/// Enhanced error messages with context and solutions
pub const ErrorContext = struct {
    code: ErrorCode,
    message: []const u8,
    context: ?[]const u8 = null,
    suggestion: ?[]const u8 = null,
    file: ?[]const u8 = null,
    line: ?u32 = null,

    pub fn format(
        self: ErrorContext,
        comptime fmt: []const u8,
        _: anytype,
        writer: anytype,
    ) !void {
        _ = fmt;

        // Error header
        try writer.print("\x1b[1;31merror\x1b[0m: {s}\n", .{self.message});

        // Context
        if (self.context) |ctx| {
            try writer.print("  \x1b[2m→\x1b[0m {s}\n", .{ctx});
        }

        // Location
        if (self.file) |file| {
            if (self.line) |line| {
                try writer.print("  \x1b[2m┌─\x1b[0m {s}:{d}\n", .{ file, line });
            } else {
                try writer.print("  \x1b[2m┌─\x1b[0m {s}\n", .{file});
            }
        }

        // Suggestion
        if (self.suggestion) |sug| {
            try writer.print("\n  \x1b[1;36mhelp\x1b[0m: {s}\n", .{sug});
        }
    }
};

pub const ErrorCode = enum {
    // Command errors
    command_not_found,
    permission_denied,
    execution_failed,

    // File errors
    file_not_found,
    directory_not_found,
    path_traversal,
    invalid_path,

    // Config errors
    config_parse_error,
    config_not_found,
    invalid_config,

    // Syntax errors
    syntax_error,
    unexpected_token,
    unclosed_quote,
    unclosed_brace,

    // Runtime errors
    variable_not_set,
    invalid_argument,
    too_many_arguments,
    too_few_arguments,

    // Plugin errors
    plugin_load_failed,
    plugin_not_found,
    plugin_incompatible,

    // Network errors
    network_unreachable,
    connection_refused,
    dns_resolution_failed,

    // Security errors
    sandbox_violation,
    command_injection,
    unsafe_operation,
};

/// Create error context for command not found
pub fn commandNotFound(allocator: std.mem.Allocator, command: []const u8) !ErrorContext {
    const message = try std.fmt.allocPrint(allocator, "command not found: {s}", .{command});
    const suggestion = findSimilarCommand(allocator, command);

    return ErrorContext{
        .code = .command_not_found,
        .message = message,
        .suggestion = suggestion orelse "Check your PATH or install the required package",
    };
}

/// Create error context for file not found
pub fn fileNotFound(allocator: std.mem.Allocator, path: []const u8) !ErrorContext {
    const message = try std.fmt.allocPrint(allocator, "file not found: {s}", .{path});
    const abs_path = std.fs.cwd().realpathAlloc(allocator, ".") catch null;
    const context = if (abs_path) |p|
        try std.fmt.allocPrint(allocator, "working directory: {s}", .{p})
    else
        null;

    return ErrorContext{
        .code = .file_not_found,
        .message = message,
        .context = context,
        .suggestion = "Check the file path and permissions",
    };
}

/// Create error context for permission denied
pub fn permissionDenied(allocator: std.mem.Allocator, path: []const u8) !ErrorContext {
    const message = try std.fmt.allocPrint(allocator, "permission denied: {s}", .{path});

    return ErrorContext{
        .code = .permission_denied,
        .message = message,
        .suggestion = "Check file permissions with 'ls -l' or run with appropriate privileges",
    };
}

/// Create error context for syntax errors
pub fn syntaxError(allocator: std.mem.Allocator, input: []const u8, position: usize, reason: []const u8) !ErrorContext {
    const message = try std.fmt.allocPrint(allocator, "syntax error: {s}", .{reason});
    const context = try std.fmt.allocPrint(allocator, "{s}\n  \x1b[2m│\x1b[0m {s}\x1b[1;31m^\x1b[0m", .{ input[0..@min(position + 10, input.len)], " " ** position });

    return ErrorContext{
        .code = .syntax_error,
        .message = message,
        .context = context,
        .suggestion = "Check your command syntax",
    };
}

/// Create error context for config errors
pub fn configError(allocator: std.mem.Allocator, file: []const u8, line: ?u32, reason: []const u8) !ErrorContext {
    const message = try std.fmt.allocPrint(allocator, "config error: {s}", .{reason});

    return ErrorContext{
        .code = .config_parse_error,
        .message = message,
        .file = file,
        .line = line,
        .suggestion = "Check your .gshrc.gza configuration file syntax",
    };
}

/// Create error context for invalid arguments
pub fn invalidArgument(allocator: std.mem.Allocator, command: []const u8, arg: []const u8, reason: []const u8) !ErrorContext {
    const message = try std.fmt.allocPrint(allocator, "invalid argument '{s}': {s}", .{ arg, reason });
    const suggestion = try std.fmt.allocPrint(allocator, "Run 'help {s}' for usage information", .{command});

    return ErrorContext{
        .code = .invalid_argument,
        .message = message,
        .suggestion = suggestion,
    };
}

/// Create error context for plugin errors
pub fn pluginError(allocator: std.mem.Allocator, plugin: []const u8, reason: []const u8) !ErrorContext {
    const message = try std.fmt.allocPrint(allocator, "plugin error ({s}): {s}", .{ plugin, reason });

    return ErrorContext{
        .code = .plugin_load_failed,
        .message = message,
        .suggestion = "Check plugin compatibility and installation",
    };
}

/// Create error context for network errors
pub fn networkError(allocator: std.mem.Allocator, host: []const u8, reason: []const u8) !ErrorContext {
    const message = try std.fmt.allocPrint(allocator, "network error: {s}", .{reason});
    const context = try std.fmt.allocPrint(allocator, "host: {s}", .{host});

    return ErrorContext{
        .code = .network_unreachable,
        .message = message,
        .context = context,
        .suggestion = "Check network connectivity and DNS resolution",
    };
}

/// Calculate Levenshtein distance between two strings
fn levenshteinDistance(s1: []const u8, s2: []const u8, allocator: std.mem.Allocator) !usize {
    const len1 = s1.len;
    const len2 = s2.len;

    if (len1 == 0) return len2;
    if (len2 == 0) return len1;

    // Create matrix for dynamic programming
    var matrix = try allocator.alloc(usize, (len1 + 1) * (len2 + 1));
    defer allocator.free(matrix);

    // Initialize first column and row
    for (0..len1 + 1) |i| {
        matrix[i * (len2 + 1)] = i;
    }
    for (0..len2 + 1) |j| {
        matrix[j] = j;
    }

    // Fill matrix
    for (1..len1 + 1) |i| {
        for (1..len2 + 1) |j| {
            const cost: usize = if (s1[i - 1] == s2[j - 1]) 0 else 1;

            const deletion = matrix[(i - 1) * (len2 + 1) + j] + 1;
            const insertion = matrix[i * (len2 + 1) + (j - 1)] + 1;
            const substitution = matrix[(i - 1) * (len2 + 1) + (j - 1)] + cost;

            matrix[i * (len2 + 1) + j] = @min(deletion, @min(insertion, substitution));
        }
    }

    return matrix[len1 * (len2 + 1) + len2];
}

/// Find similar commands for suggestions using edit distance
fn findSimilarCommand(allocator: std.mem.Allocator, command: []const u8) ?[]const u8 {
    // Common shell commands to check against
    const common_commands = [_][]const u8{
        // Core builtins
        "cd", "pwd", "echo", "exit", "alias", "unalias", "help",
        "jobs", "fg", "bg", "e", "fc",
        // Common Unix commands
        "ls", "cat", "grep", "find", "sed", "awk", "sort", "uniq",
        "head", "tail", "wc", "cut", "tr", "tee", "xargs",
        "git", "make", "cargo", "npm", "pip", "docker", "kubectl",
        "ps", "top", "kill", "htop", "free", "df", "du",
        "ssh", "scp", "rsync", "curl", "wget", "nc",
        "vim", "nano", "emacs", "grim",
        "man", "which", "whereis", "type",
    };

    var best_match: ?[]const u8 = null;
    var best_distance: usize = std.math.maxInt(usize);

    for (common_commands) |cmd| {
        const distance = levenshteinDistance(command, cmd, allocator) catch continue;

        // Only suggest if edit distance is small (typo range)
        if (distance <= 2 and distance < best_distance) {
            best_distance = distance;
            best_match = cmd;
        }
    }

    if (best_match) |match| {
        return std.fmt.allocPrint(allocator, "Did you mean '{s}'?", .{match}) catch null;
    }

    return null;
}

/// Log error with structured logging
pub fn logError(logger: anytype, err_ctx: ErrorContext) void {
    const fields = [_]zlog.Field{
        .{ .key = "error_code", .value = .{ .string = @tagName(err_ctx.code) } },
        .{ .key = "message", .value = .{ .string = err_ctx.message } },
    };
    logger.inner.logWithFields(.err, "Shell error occurred", &fields);
}
