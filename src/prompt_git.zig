const std = @import("std");
const zsync = @import("zsync");

/// Async Git repository information
pub const GitInfo = struct {
    branch: ?[]const u8 = null,
    dirty: bool = false,
    ahead: u32 = 0,
    behind: u32 = 0,
    in_repo: bool = false,

    pub fn deinit(self: *GitInfo, allocator: std.mem.Allocator) void {
        if (self.branch) |b| allocator.free(b);
    }
};

/// Cached git info with TTL
const GitCache = struct {
    info: GitInfo,
    cwd: []const u8,
    timestamp: i64,
    ttl_ms: i64 = 5000, // 5 second cache

    pub fn isValid(self: *const GitCache, current_cwd: []const u8) bool {
        if (!std.mem.eql(u8, self.cwd, current_cwd)) return false;
        const now = std.time.milliTimestamp();
        return (now - self.timestamp) < self.ttl_ms;
    }

    pub fn deinit(self: *GitCache, allocator: std.mem.Allocator) void {
        self.info.deinit(allocator);
        allocator.free(self.cwd);
    }
};

/// Async Git prompt segment provider
pub const GitPrompt = struct {
    allocator: std.mem.Allocator,
    cache: ?GitCache = null,
    mutex: std.Thread.Mutex = .{},

    pub fn init(allocator: std.mem.Allocator) GitPrompt {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *GitPrompt) void {
        if (self.cache) |*cache| {
            cache.deinit(self.allocator);
        }
    }

    /// Get git info, using cache if available
    pub fn getInfo(self: *GitPrompt, cwd: []const u8) !GitInfo {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Check cache
        if (self.cache) |*cache| {
            if (cache.isValid(cwd)) {
                // Return cached copy
                return GitInfo{
                    .branch = if (cache.info.branch) |b| try self.allocator.dupe(u8, b) else null,
                    .dirty = cache.info.dirty,
                    .ahead = cache.info.ahead,
                    .behind = cache.info.behind,
                    .in_repo = cache.info.in_repo,
                };
            }
            // Cache invalid, free it
            cache.deinit(self.allocator);
            self.cache = null;
        }

        // Fetch fresh git info
        const info = try self.fetchGitInfo(cwd);

        // Update cache
        self.cache = GitCache{
            .info = GitInfo{
                .branch = if (info.branch) |b| try self.allocator.dupe(u8, b) else null,
                .dirty = info.dirty,
                .ahead = info.ahead,
                .behind = info.behind,
                .in_repo = info.in_repo,
            },
            .cwd = try self.allocator.dupe(u8, cwd),
            .timestamp = std.time.milliTimestamp(),
        };

        return info;
    }

    /// Fetch git info synchronously (called from async context)
    fn fetchGitInfo(self: *GitPrompt, cwd: []const u8) !GitInfo {
        _ = cwd; // TODO: Use cwd for git commands

        var info = GitInfo{};

        // Check if in git repo
        const in_repo_result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "git", "rev-parse", "--git-dir" },
        }) catch {
            return info; // Not in git repo
        };
        defer self.allocator.free(in_repo_result.stdout);
        defer self.allocator.free(in_repo_result.stderr);

        if (in_repo_result.term.Exited != 0) {
            return info; // Not in git repo
        }

        info.in_repo = true;

        // Get branch name
        const branch_result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "git", "branch", "--show-current" },
        }) catch {
            return info;
        };
        defer self.allocator.free(branch_result.stderr);

        if (branch_result.term.Exited == 0) {
            const branch = std.mem.trim(u8, branch_result.stdout, "\n\r\t ");
            if (branch.len > 0) {
                info.branch = try self.allocator.dupe(u8, branch);
                self.allocator.free(branch_result.stdout);
            } else {
                self.allocator.free(branch_result.stdout);
                // Try to get detached HEAD commit
                const head_result = std.process.Child.run(.{
                    .allocator = self.allocator,
                    .argv = &[_][]const u8{ "git", "rev-parse", "--short", "HEAD" },
                }) catch {
                    return info;
                };
                defer self.allocator.free(head_result.stderr);
                if (head_result.term.Exited == 0) {
                    const commit = std.mem.trim(u8, head_result.stdout, "\n\r\t ");
                    info.branch = try std.fmt.allocPrint(self.allocator, "detached@{s}", .{commit});
                    self.allocator.free(head_result.stdout);
                } else {
                    self.allocator.free(head_result.stdout);
                }
            }
        } else {
            self.allocator.free(branch_result.stdout);
        }

        // Check if dirty
        const status_result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "git", "status", "--porcelain" },
        }) catch {
            return info;
        };
        defer self.allocator.free(status_result.stderr);

        if (status_result.term.Exited == 0) {
            const status = std.mem.trim(u8, status_result.stdout, "\n\r\t ");
            info.dirty = status.len > 0;
            self.allocator.free(status_result.stdout);
        } else {
            self.allocator.free(status_result.stdout);
        }

        // Get ahead/behind counts (optional, can be slow)
        // Skipping for now to keep it fast

        return info;
    }

    /// Render git info as a prompt segment
    pub fn render(self: *GitPrompt, allocator: std.mem.Allocator, cwd: []const u8) !?[]const u8 {
        const info = try self.getInfo(cwd);
        defer {
            var mut_info = info;
            mut_info.deinit(allocator);
        }

        if (!info.in_repo) return null;

        var result = std.ArrayListUnmanaged(u8){};
        defer result.deinit(allocator);

        // Format: (branch*) where * indicates dirty
        try result.appendSlice(allocator, "(");

        if (info.branch) |branch| {
            try result.appendSlice(allocator, branch);
        } else {
            try result.appendSlice(allocator, "unknown");
        }

        if (info.dirty) {
            try result.appendSlice(allocator, "*");
        }

        try result.appendSlice(allocator, ") ");

        return try result.toOwnedSlice(allocator);
    }

    /// Async version using zsync (for future)
    pub fn renderAsync(self: *GitPrompt, allocator: std.mem.Allocator, cwd: []const u8) !?[]const u8 {
        // For now, just call sync version
        // TODO: Implement actual async with zsync task spawning
        return try self.render(allocator, cwd);
    }
};

test "git prompt basic" {
    const testing = std.testing;
    var gp = GitPrompt.init(testing.allocator);
    defer gp.deinit();

    const info = try gp.getInfo(".");
    defer {
        var mut_info = info;
        mut_info.deinit(testing.allocator);
    }

    // Should detect if we're in a git repo
    if (info.in_repo) {
        try testing.expect(info.branch != null);
    }
}
