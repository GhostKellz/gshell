const std = @import("std");
const zqlite = @import("zqlite");

const has_zqlite = @hasDecl(zqlite, "Database");

pub const HistoryStore = struct {
    allocator: std.mem.Allocator,
    path: []const u8,
    file: std.fs.File,
    mutex: std.Thread.Mutex = .{},

    pub fn init(allocator: std.mem.Allocator, resolved_path: []const u8) !HistoryStore {
        try ensureParentDirectory(resolved_path);
        const owned_path = try allocator.dupe(u8, resolved_path);
        const file = try openOrCreate(owned_path);
        return HistoryStore{
            .allocator = allocator,
            .path = owned_path,
            .file = file,
        };
    }

    pub fn deinit(self: *HistoryStore) void {
        self.file.close();
        self.allocator.free(self.path);
    }

    pub fn backend(self: *const HistoryStore) []const u8 {
        _ = self;
        return if (has_zqlite) "zqlite" else "flatfile";
    }

    pub fn append(self: *HistoryStore, command: []const u8, exit_code: i32) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        try self.file.seekFromEnd(0);
        const timestamp = (try std.time.Instant.now()).timestamp.sec;

        // Format the history record
        var buf: [4096]u8 = undefined;
        const line = try std.fmt.bufPrint(&buf, "{d}|{d}|{s}\n", .{ timestamp, exit_code, command });
        try self.file.writeAll(line);
    }

    pub fn flush(self: *HistoryStore) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.file.sync();
    }

    pub fn recent(self: *HistoryStore, allocator: std.mem.Allocator, limit: usize) ![][]const u8 {
        if (limit == 0) return allocator.alloc([]const u8, 0);

        self.mutex.lock();
        defer self.mutex.unlock();

        try self.file.sync();

        var file = try std.fs.cwd().openFile(self.path, .{ .mode = .read_only });
        defer file.close();

        const contents = try file.readToEndAlloc(allocator, 1 << 20);
        errdefer allocator.free(contents);

        var lines = std.ArrayList([]const u8){};
        errdefer {
            for (lines.items) |line| allocator.free(line);
            lines.deinit(allocator);
        }

        var iter = std.mem.splitScalar(u8, contents, '\n');
        while (iter.next()) |line| {
            if (line.len == 0) continue;
            const dup = allocator.dupe(u8, line) catch |err| {
                allocator.free(contents);
                return err;
            };
            if (lines.items.len == limit) {
                const removed = lines.orderedRemove(0);
                allocator.free(removed);
            }
            lines.append(allocator, dup) catch |err| {
                allocator.free(dup);
                allocator.free(contents);
                return err;
            };
        }

        allocator.free(contents);

        const result = try allocator.alloc([]const u8, lines.items.len);
        for (lines.items, 0..) |line, idx| {
            result[idx] = line;
        }
        lines.deinit(allocator);
        return result;
    }
};

fn ensureParentDirectory(path: []const u8) !void {
    if (std.fs.path.dirname(path)) |dir| {
        std.fs.cwd().makePath(dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
    }
}

fn openOrCreate(path: []const u8) !std.fs.File {
    var file = std.fs.cwd().openFile(path, .{ .mode = .read_write }) catch |err| switch (err) {
        error.FileNotFound => blk: {
            break :blk try std.fs.cwd().createFile(path, .{ .read = true, .truncate = false });
        },
        else => return err,
    };
    try file.seekFromEnd(0);
    return file;
}

pub fn parseRecord(record: []const u8) ?struct { timestamp: i64, exit_code: i32, command: []const u8 } {
    var parts = std.mem.splitScalar(u8, record, '|');
    const ts_part = parts.next() orelse return null;
    const exit_part = parts.next() orelse return null;
    const command_part = parts.rest();
    const timestamp = std.fmt.parseInt(i64, ts_part, 10) catch return null;
    const exit_code = std.fmt.parseInt(i32, exit_part, 10) catch return null;
    return .{ .timestamp = timestamp, .exit_code = exit_code, .command = command_part };
}
