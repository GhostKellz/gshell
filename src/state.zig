const std = @import("std");
const security = @import("security.zig");

pub const JobStatus = enum {
    running,
    stopped,
    done,
};

pub const Job = struct {
    id: u32,
    pid: std.posix.pid_t,
    status: JobStatus,
    command: []const u8,
};

pub const ShellState = struct {
    allocator: std.mem.Allocator,
    env: std.process.EnvMap,
    should_exit: bool = false,
    exit_code: i32 = 0,
    jobs: std.ArrayListUnmanaged(Job) = .{},
    next_job_id: u32 = 1,
    aliases: std.StringHashMapUnmanaged([]const u8) = .{},

    pub fn init(allocator: std.mem.Allocator) !ShellState {
        return ShellState{
            .allocator = allocator,
            .env = try std.process.getEnvMap(allocator),
            .should_exit = false,
            .exit_code = 0,
        };
    }

    pub fn deinit(self: *ShellState) void {
        for (self.jobs.items) |job| {
            self.allocator.free(job.command);
        }
        self.jobs.deinit(self.allocator);

        // Free aliases
        var alias_iter = self.aliases.iterator();
        while (alias_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.aliases.deinit(self.allocator);

        self.env.deinit();
    }

    pub fn setExit(self: *ShellState, code: i32) void {
        self.should_exit = true;
        self.exit_code = code;
    }

    pub fn setEnv(self: *ShellState, key: []const u8, value: []const u8) !void {
        // Security: Validate environment variable name and value
        try security.validateEnvVarName(key);
        try security.validateEnvVarValue(value);
        // EnvMap.put() handles duplication internally
        try self.env.put(key, value);
    }

    pub fn getEnv(self: *ShellState, key: []const u8) ?[]const u8 {
        return self.env.get(key);
    }

    pub fn addJob(self: *ShellState, pid: std.posix.pid_t, command: []const u8) !u32 {
        const job_id = self.next_job_id;
        self.next_job_id += 1;
        const owned_command = try self.allocator.dupe(u8, command);
        try self.jobs.append(self.allocator, .{
            .id = job_id,
            .pid = pid,
            .status = .running,
            .command = owned_command,
        });
        return job_id;
    }

    pub fn getJob(self: *ShellState, job_id: u32) ?*Job {
        for (self.jobs.items) |*job| {
            if (job.id == job_id) return job;
        }
        return null;
    }

    pub fn getJobByPid(self: *ShellState, pid: std.posix.pid_t) ?*Job {
        for (self.jobs.items) |*job| {
            if (job.pid == pid) return job;
        }
        return null;
    }

    pub fn removeJob(self: *ShellState, job_id: u32) void {
        for (self.jobs.items, 0..) |job, idx| {
            if (job.id == job_id) {
                self.allocator.free(job.command);
                _ = self.jobs.swapRemove(idx);
                return;
            }
        }
    }

    pub fn setAlias(self: *ShellState, name: []const u8, value: []const u8) !void {
        // Security: Validate alias name to prevent injection
        try security.validateAliasName(name);

        // Security: Validate alias value (command) length
        if (value.len > 4096) {
            return error.ValueTooLong;
        }

        // Check if alias already exists and free old value
        if (self.aliases.fetchRemove(name)) |kv| {
            self.allocator.free(kv.key);
            self.allocator.free(kv.value);
        }

        // Allocate owned copies
        const owned_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(owned_name);
        const owned_value = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned_value);

        try self.aliases.put(self.allocator, owned_name, owned_value);
    }

    pub fn getAlias(self: *ShellState, name: []const u8) ?[]const u8 {
        return self.aliases.get(name);
    }

    pub fn removeAlias(self: *ShellState, name: []const u8) bool {
        if (self.aliases.fetchRemove(name)) |kv| {
            self.allocator.free(kv.key);
            self.allocator.free(kv.value);
            return true;
        }
        return false;
    }
};
