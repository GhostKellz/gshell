const std = @import("std");

/// Instant prompt caching system (PowerLevel10k-style)
/// Caches the last prompt output for instant display on shell startup
pub const InstantPromptCache = struct {
    allocator: std.mem.Allocator,
    cache_dir: []const u8,
    cache_file: []const u8,
    enabled: bool = true,
    max_age_ms: i64 = 5000, // Cache valid for 5 seconds

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        // Get cache directory: ~/.cache/gshell/
        const home = std.posix.getenv("HOME") orelse return error.HomeNotFound;
        const cache_dir = try std.fmt.allocPrint(allocator, "{s}/.cache/gshell", .{home});
        errdefer allocator.free(cache_dir);

        // Create cache directory if it doesn't exist
        std.fs.cwd().makePath(cache_dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };

        const cache_file = try std.fmt.allocPrint(allocator, "{s}/instant_prompt.cache", .{cache_dir});

        return Self{
            .allocator = allocator,
            .cache_dir = cache_dir,
            .cache_file = cache_file,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.cache_dir);
        self.allocator.free(self.cache_file);
    }

    /// Cache context for invalidation
    pub const CacheContext = struct {
        cwd: []const u8,
        user: []const u8,
        host: []const u8,
        exit_code: i32,
        timestamp_ms: i64,

        pub fn encode(self: CacheContext, allocator: std.mem.Allocator) ![]const u8 {
            return try std.fmt.allocPrint(
                allocator,
                "{s}|{s}|{s}|{d}|{d}",
                .{ self.cwd, self.user, self.host, self.exit_code, self.timestamp_ms },
            );
        }

        pub fn decode(allocator: std.mem.Allocator, encoded: []const u8) !CacheContext {
            var iter = std.mem.splitScalar(u8, encoded, '|');

            const cwd = iter.next() orelse return error.InvalidFormat;
            const user = iter.next() orelse return error.InvalidFormat;
            const host = iter.next() orelse return error.InvalidFormat;
            const exit_code_str = iter.next() orelse return error.InvalidFormat;
            const timestamp_str = iter.next() orelse return error.InvalidFormat;

            const exit_code = try std.fmt.parseInt(i32, exit_code_str, 10);
            const timestamp = try std.fmt.parseInt(i64, timestamp_str, 10);

            return CacheContext{
                .cwd = try allocator.dupe(u8, cwd),
                .user = try allocator.dupe(u8, user),
                .host = try allocator.dupe(u8, host),
                .exit_code = exit_code,
                .timestamp_ms = timestamp,
            };
        }

        pub fn deinit(self: *CacheContext, allocator: std.mem.Allocator) void {
            allocator.free(self.cwd);
            allocator.free(self.user);
            allocator.free(self.host);
        }
    };

    /// Get current timestamp in milliseconds
    fn getCurrentTimeMs() i64 {
        return std.time.milliTimestamp();
    }

    /// Load cached prompt if valid
    pub fn load(self: *Self, current_ctx: CacheContext) ?[]const u8 {
        if (!self.enabled) return null;

        // Read cache file
        const file = std.fs.cwd().openFile(self.cache_file, .{}) catch {
            return null;
        };
        defer file.close();

        const stat = file.stat() catch return null;
        const content = self.allocator.alloc(u8, stat.size) catch return null;
        errdefer self.allocator.free(content);

        _ = file.readAll(content) catch {
            self.allocator.free(content);
            return null;
        };

        // Parse cache format: <context>\n<prompt>
        const newline_pos = std.mem.indexOfScalar(u8, content, '\n') orelse {
            self.allocator.free(content);
            return null;
        };

        const context_line = content[0..newline_pos];
        const prompt_line = content[newline_pos + 1 ..];

        // Decode cached context
        var cached_ctx = CacheContext.decode(self.allocator, context_line) catch {
            self.allocator.free(content);
            return null;
        };
        defer cached_ctx.deinit(self.allocator);

        // Validate cache
        const now = getCurrentTimeMs();
        const age_ms = now - cached_ctx.timestamp_ms;

        if (age_ms > self.max_age_ms) {
            // Cache too old
            self.allocator.free(content);
            return null;
        }

        // Check if context matches (cwd, user, host)
        if (!std.mem.eql(u8, cached_ctx.cwd, current_ctx.cwd) or
            !std.mem.eql(u8, cached_ctx.user, current_ctx.user) or
            !std.mem.eql(u8, cached_ctx.host, current_ctx.host))
        {
            // Context changed, cache invalid
            self.allocator.free(content);
            return null;
        }

        // Cache is valid, return prompt (duplicate it since we'll free content)
        const prompt = self.allocator.dupe(u8, prompt_line) catch {
            self.allocator.free(content);
            return null;
        };

        self.allocator.free(content);
        return prompt;
    }

    /// Save prompt to cache
    pub fn save(self: *Self, ctx: CacheContext, prompt: []const u8) !void {
        if (!self.enabled) return;

        // Encode context
        const context_line = try ctx.encode(self.allocator);
        defer self.allocator.free(context_line);

        // Write cache file atomically (write to temp, then rename)
        const temp_file = try std.fmt.allocPrint(
            self.allocator,
            "{s}.tmp",
            .{self.cache_file},
        );
        defer self.allocator.free(temp_file);

        // Create temp file
        const file = try std.fs.cwd().createFile(temp_file, .{ .truncate = true });
        defer file.close();

        // Write context line
        try file.writeAll(context_line);
        try file.writeAll("\n");

        // Write prompt
        try file.writeAll(prompt);

        // Atomic rename
        try std.fs.cwd().rename(temp_file, self.cache_file);
    }

    /// Invalidate cache (delete cache file)
    pub fn invalidate(self: *Self) void {
        std.fs.cwd().deleteFile(self.cache_file) catch {};
    }

    /// Check if cache exists
    pub fn exists(self: *Self) bool {
        std.fs.cwd().access(self.cache_file, .{}) catch return false;
        return true;
    }

    /// Enable/disable instant prompt
    pub fn setEnabled(self: *Self, enabled: bool) void {
        self.enabled = enabled;
    }
};

test "InstantPromptCache init" {
    const allocator = std.testing.allocator;

    var cache = try InstantPromptCache.init(allocator);
    defer cache.deinit();

    try std.testing.expect(cache.enabled);
}

test "CacheContext encode/decode" {
    const allocator = std.testing.allocator;

    const ctx = InstantPromptCache.CacheContext{
        .cwd = "/home/user",
        .user = "user",
        .host = "localhost",
        .exit_code = 0,
        .timestamp_ms = 1234567890,
    };

    const encoded = try ctx.encode(allocator);
    defer allocator.free(encoded);

    var decoded = try InstantPromptCache.CacheContext.decode(allocator, encoded);
    defer decoded.deinit(allocator);

    try std.testing.expectEqualStrings(ctx.cwd, decoded.cwd);
    try std.testing.expectEqualStrings(ctx.user, decoded.user);
    try std.testing.expectEqualStrings(ctx.host, decoded.host);
    try std.testing.expectEqual(ctx.exit_code, decoded.exit_code);
    try std.testing.expectEqual(ctx.timestamp_ms, decoded.timestamp_ms);
}
