const std = @import("std");
const zlog = @import("zlog");

pub const Logger = struct {
    allocator: std.mem.Allocator,
    inner: zlog.Logger,

    pub fn init(allocator: std.mem.Allocator, level: zlog.Level) !Logger {
        const config = zlog.LoggerConfig{
            .level = level,
            .format = .text,
            .output_target = .stdout,
            .async_io = false,
            .enable_batching = false,
        };
        const inner_logger = try zlog.Logger.init(allocator, config);
        return Logger{
            .allocator = allocator,
            .inner = inner_logger,
        };
    }

    pub fn deinit(self: *Logger) void {
        self.inner.deinit();
    }

    pub fn scoped(self: *Logger, comptime fmt: []const u8, args: anytype, fields: []const zlog.Field) void {
        const message = std.fmt.allocPrint(self.allocator, fmt, args) catch return;
        defer self.allocator.free(message);
        self.inner.logWithFields(.info, message, fields);
    }

    pub fn info(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.inner.log(.info, fmt, args);
    }

    pub fn warn(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.inner.log(.warn, fmt, args);
    }

    pub fn err(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.inner.log(.err, fmt, args);
    }
};
