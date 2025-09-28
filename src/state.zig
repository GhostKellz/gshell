const std = @import("std");

pub const ShellConfig = struct {
    prompt: []const u8 = "gshell> ",
    interactive: bool = true,
};

pub const ShellState = struct {
    allocator: std.mem.Allocator,
    env: std.process.EnvMap,
    should_exit: bool = false,
    exit_code: i32 = 0,

    pub fn init(allocator: std.mem.Allocator) !ShellState {
        return ShellState{
            .allocator = allocator,
            .env = try std.process.getEnvMap(allocator),
            .should_exit = false,
            .exit_code = 0,
        };
    }

    pub fn deinit(self: *ShellState) void {
        self.env.deinit();
    }

    pub fn setExit(self: *ShellState, code: i32) void {
        self.should_exit = true;
        self.exit_code = code;
    }

    pub fn setEnv(self: *ShellState, key: []const u8, value: []const u8) !void {
        try self.env.put(key, value);
    }

    pub fn getEnv(self: *ShellState, key: []const u8) ?[]const u8 {
        return self.env.get(key);
    }
};
