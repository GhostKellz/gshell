/// GShell Logging Module
/// Provides structured logging with zlog for better error reporting and debugging.
///
/// Usage:
/// ```zig
/// var logger = try Logger.init(allocator, .info);
/// defer logger.deinit();
/// logger.info("Starting shell", .{});
/// logger.scriptError("test.gza", 42, "Unexpected token");
/// ```
const std = @import("std");
const zlog = @import("zlog");

/// Logger wraps zlog.Logger and provides convenience methods for shell-specific logging
pub const Logger = struct {
    allocator: std.mem.Allocator,
    inner: zlog.Logger,

    /// Initialize a new Logger instance
    ///
    /// @param allocator Memory allocator for the logger
    /// @param level Minimum log level to display (debug, info, warn, err, fatal)
    /// @return Logger instance or error
    pub fn init(allocator: std.mem.Allocator, level: zlog.Level) !Logger {
        const config = zlog.LoggerConfig{
            .level = level,
            .format = .text,
            .output_target = .stderr, // Errors to stderr for better UX
            .async_io = false, // Synchronous for immediate feedback
            .enable_batching = false,
        };
        const inner_logger = try zlog.Logger.init(allocator, config);
        return Logger{
            .allocator = allocator,
            .inner = inner_logger,
        };
    }

    /// Deinitialize the logger and free resources
    pub fn deinit(self: *Logger) void {
        self.inner.deinit();
    }

    /// Log with structured fields for advanced analysis
    ///
    /// @param fmt Format string
    /// @param args Format arguments
    /// @param fields Structured fields for context
    pub fn scoped(self: *Logger, comptime fmt: []const u8, args: anytype, fields: []const zlog.Field) void {
        const message = std.fmt.allocPrint(self.allocator, fmt, args) catch return;
        defer self.allocator.free(message);
        self.inner.logWithFields(.info, message, fields);
    }

    /// Log debug message (only shown when GSHELL_LOG_LEVEL=debug)
    pub fn debug(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.inner.log(.debug, fmt, args);
    }

    /// Log informational message
    pub fn info(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.inner.log(.info, fmt, args);
    }

    /// Log warning message
    pub fn warn(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.inner.log(.warn, fmt, args);
    }

    /// Log error message
    pub fn err(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.inner.log(.err, fmt, args);
    }

    /// Log fatal error message (typically followed by exit)
    pub fn fatal(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.inner.log(.fatal, fmt, args);
    }

    /// Log script execution error with file and line context
    ///
    /// @param script_path Path to the script file
    /// @param line Optional line number where error occurred
    /// @param message Error message
    pub fn scriptError(self: *Logger, script_path: []const u8, line: ?usize, message: []const u8) void {
        if (line) |l| {
            self.err("Script error in {s}:{d}: {s}", .{ script_path, l, message });
        } else {
            self.err("Script error in {s}: {s}", .{ script_path, message });
        }
    }

    /// Log command execution failure with exit code and stderr
    ///
    /// @param command Command that failed
    /// @param exit_code Exit code from the command
    /// @param stderr_output Optional stderr output from command
    pub fn commandError(self: *Logger, command: []const u8, exit_code: i32, stderr_output: ?[]const u8) void {
        if (stderr_output) |stderr| {
            self.err("Command '{s}' failed with exit code {d}: {s}", .{ command, exit_code, stderr });
        } else {
            self.err("Command '{s}' failed with exit code {d}", .{ command, exit_code });
        }
    }

    /// Log parsing error with input context
    ///
    /// @param input The input being parsed
    /// @param position Character position where error occurred
    /// @param message Error description
    pub fn parseError(self: *Logger, input: []const u8, position: usize, message: []const u8) void {
        // Show context around the error (20 chars before and after)
        const context_start = if (position > 20) position - 20 else 0;
        const context_end = if (position + 20 < input.len) position + 20 else input.len;
        const context = input[context_start..context_end];

        self.err("Parse error at position {d}: {s}", .{ position, message });
        self.err("Context: ...{s}...", .{context});
    }
};

test "logging module initialization" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var logger = try Logger.init(allocator, .info);
    defer logger.deinit();

    // Test basic logging
    logger.debug("Debug test", .{});
    logger.info("Info test", .{});
    logger.warn("Warning test", .{});
    logger.err("Error test", .{});
}
