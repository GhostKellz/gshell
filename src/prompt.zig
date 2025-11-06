const std = @import("std");
const prompt_git = @import("prompt_git.zig");
const ghostkellz = @import("prompts/ghostkellz.zig");
const VersionDetector = @import("version_detect.zig").VersionDetector;
const InstantPromptCache = @import("instant_prompt.zig").InstantPromptCache;
const GitInfo = prompt_git.GitInfo;

pub const SegmentAlign = enum {
    left,
    right,
};

pub const PromptSegment = struct {
    text: []const u8,
    alignment: SegmentAlign = .left,
    color: ?[]const u8 = null,

    pub fn deinit(self: *PromptSegment, allocator: std.mem.Allocator) void {
        allocator.free(self.text);
        if (self.color) |c| allocator.free(c);
    }
};

pub const PromptContext = struct {
    allocator: std.mem.Allocator,
    user: []const u8,
    host: []const u8,
    cwd: []const u8,
    exit_code: i32,
    shell_state: *const @import("state.zig").ShellState,
};

pub const PromptEngine = struct {
    allocator: std.mem.Allocator,
    segments: std.ArrayListUnmanaged(PromptSegment) = .{},
    use_starship: bool = false,
    use_ghostkellz: bool = false,
    starship_available: ?bool = null,
    git_prompt: ?prompt_git.GitPrompt = null,
    ghostkellz_prompt: ?ghostkellz.GhostKellzPrompt = null,
    version_detector: VersionDetector,
    instant_prompt: ?InstantPromptCache = null,

    pub fn init(allocator: std.mem.Allocator) PromptEngine {
        var version_detector = VersionDetector.init(allocator);
        const instant_prompt = InstantPromptCache.init(allocator) catch null;

        return .{
            .allocator = allocator,
            .git_prompt = prompt_git.GitPrompt.init(allocator),
            .ghostkellz_prompt = ghostkellz.GhostKellzPrompt.init(allocator, &version_detector) catch null,
            .version_detector = version_detector,
            .instant_prompt = instant_prompt,
        };
    }

    pub fn setUseStarship(self: *PromptEngine, use: bool) void {
        self.use_starship = use;
    }

    pub fn setUseGhostKellz(self: *PromptEngine, use: bool) void {
        self.use_ghostkellz = use;
    }

    pub fn deinit(self: *PromptEngine) void {
        for (self.segments.items) |*seg| {
            seg.deinit(self.allocator);
        }
        self.segments.deinit(self.allocator);
        if (self.git_prompt) |*gp| {
            gp.deinit();
        }
        if (self.ghostkellz_prompt) |*gkp| {
            gkp.deinit();
        }
        if (self.instant_prompt) |*ip| {
            ip.deinit();
        }
        self.version_detector.deinit();
    }

    pub fn addSegment(self: *PromptEngine, text: []const u8, alignment: SegmentAlign) !void {
        const owned = try self.allocator.dupe(u8, text);
        try self.segments.append(self.allocator, .{
            .text = owned,
            .alignment = alignment,
        });
    }

    pub fn addGitSegment(self: *PromptEngine, alignment: SegmentAlign) !void {
        // Add a marker segment that will be replaced with git info
        const owned = try self.allocator.dupe(u8, "${git}");
        try self.segments.append(self.allocator, .{
            .text = owned,
            .alignment = alignment,
        });
    }

    pub fn render(self: *PromptEngine, ctx: PromptContext, terminal_width: usize) ![]const u8 {
        // Try instant prompt cache first (only for GPPrompt)
        if (self.use_ghostkellz and self.instant_prompt != null) {
            const cache_ctx = InstantPromptCache.CacheContext{
                .cwd = ctx.cwd,
                .user = ctx.user,
                .host = ctx.host,
                .exit_code = ctx.exit_code,
                .timestamp_ms = @divFloor((try std.time.Instant.now()).timestamp.nsec, 1_000_000),
            };

            if (try self.instant_prompt.?.load(cache_ctx)) |cached| {
                // Cache hit! Return instantly
                return cached;
            }
        }

        // Try GhostKellz P10k prompt first if enabled
        if (self.use_ghostkellz) {
            if (try self.renderGhostKellz(ctx, terminal_width)) |gk_prompt| {
                // Save to cache for next time
                if (self.instant_prompt) |*ip| {
                    const cache_ctx = InstantPromptCache.CacheContext{
                        .cwd = ctx.cwd,
                        .user = ctx.user,
                        .host = ctx.host,
                        .exit_code = ctx.exit_code,
                        .timestamp_ms = @divFloor((try std.time.Instant.now()).timestamp.nsec, 1_000_000),
                    };
                    ip.save(cache_ctx, gk_prompt) catch {};
                }
                return gk_prompt;
            }
            // Fall through to Starship/segment-based rendering if GhostKellz fails
        }

        // Try Starship if enabled
        if (self.use_starship) {
            if (try self.renderStarship(ctx)) |starship_prompt| {
                return starship_prompt;
            }
            // Fall through to segment-based rendering if Starship fails
        }

        var left_parts = std.ArrayListUnmanaged([]const u8){};
        defer left_parts.deinit(self.allocator);
        var right_parts = std.ArrayListUnmanaged([]const u8){};
        defer right_parts.deinit(self.allocator);

        for (self.segments.items) |seg| {
            // Check if this is a git segment
            if (std.mem.eql(u8, seg.text, "${git}")) {
                // Render git info if available
                if (self.git_prompt) |*gp| {
                    if (try gp.render(self.allocator, ctx.cwd)) |git_text| {
                        if (seg.alignment == .left) {
                            try left_parts.append(self.allocator, git_text);
                        } else {
                            try right_parts.append(self.allocator, git_text);
                        }
                    }
                }
            } else {
                const expanded = try expandVariables(self.allocator, seg.text, ctx);
                if (seg.alignment == .left) {
                    try left_parts.append(self.allocator, expanded);
                } else {
                    try right_parts.append(self.allocator, expanded);
                }
            }
        }

        var result = std.ArrayListUnmanaged(u8){};
        defer result.deinit(self.allocator);

        for (left_parts.items) |part| {
            try result.appendSlice(self.allocator, part);
            self.allocator.free(part);
        }

        if (right_parts.items.len > 0) {
            var right_width: usize = 0;
            for (right_parts.items) |part| {
                right_width += part.len;
            }

            const left_width = result.items.len;
            if (left_width + right_width < terminal_width) {
                const padding = terminal_width - left_width - right_width;
                try result.appendNTimes(self.allocator, ' ', padding);
            }

            for (right_parts.items) |part| {
                try result.appendSlice(self.allocator, part);
                self.allocator.free(part);
            }
        }

        return try result.toOwnedSlice(self.allocator);
    }

    pub fn clear(self: *PromptEngine) void {
        for (self.segments.items) |*seg| {
            seg.deinit(self.allocator);
        }
        self.segments.clearRetainingCapacity();
    }

    fn renderGhostKellz(self: *PromptEngine, ctx: PromptContext, terminal_width: usize) !?[]const u8 {
        if (self.ghostkellz_prompt == null) return null;

        // Gather git information
        var in_git_repo = false;
        var git_branch: []const u8 = "";
        var git_dirty = false;

        if (self.git_prompt) |*gp| {
            // Get git info from cache or fetch
            const git_info = gp.getInfo(ctx.cwd) catch GitInfo{};
            defer {
                var mut_info = git_info;
                mut_info.deinit(self.allocator);
            }

            in_git_repo = git_info.in_repo;
            git_dirty = git_info.dirty;
            if (git_info.branch) |branch| {
                git_branch = branch;
            }
        }

        // Build GhostKellz context
        const gk_ctx = ghostkellz.PromptContext{
            .cwd = ctx.cwd,
            .user = ctx.user,
            .host = ctx.host,
            .exit_code = ctx.exit_code,
            .in_git_repo = in_git_repo,
            .git_branch = git_branch,
            .git_dirty = git_dirty,
            .terminal_width = terminal_width,
            .terminal_height = 24, // Default, could be detected
        };

        // Render the prompt
        var gkp = &self.ghostkellz_prompt.?;
        return gkp.render(gk_ctx) catch null;
    }

    fn renderStarship(self: *PromptEngine, ctx: PromptContext) !?[]const u8 {
        _ = ctx;

        // Check if starship is available (cache result)
        if (self.starship_available == null) {
            // Try to find starship binary
            const result = std.process.Child.run(.{
                .allocator = self.allocator,
                .argv = &[_][]const u8{ "which", "starship" },
            }) catch {
                self.starship_available = false;
                return null;
            };
            defer self.allocator.free(result.stdout);
            defer self.allocator.free(result.stderr);
            self.starship_available = (result.term.Exited == 0);
        }

        if (self.starship_available == false) {
            return null;
        }

        // Block SIGCHLD to prevent shell's reapJobs from interfering
        var old_mask: std.posix.sigset_t = undefined;
        var new_mask = std.posix.sigemptyset();
        std.posix.sigaddset(&new_mask, std.posix.SIG.CHLD);
        _ = std.posix.sigprocmask(std.posix.SIG.BLOCK, &new_mask, &old_mask);
        defer _ = std.posix.sigprocmask(std.posix.SIG.SETMASK, &old_mask, null);

        // Run starship prompt
        var child = std.process.Child.init(&[_][]const u8{
            "starship",
            "prompt",
        }, self.allocator);

        child.stdin_behavior = .Ignore;
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Ignore;

        // Set environment for Starship
        var env_map = std.process.EnvMap.init(self.allocator);
        defer env_map.deinit();
        try env_map.put("STARSHIP_SHELL", "gshell");

        child.env_map = &env_map;

        try child.spawn();

        // Read stdout using a buffer
        var buf: [1024 * 10]u8 = undefined;
        var total_read: usize = 0;

        while (true) {
            const n = child.stdout.?.read(buf[total_read..]) catch break;
            if (n == 0) break;
            total_read += n;
            if (total_read >= buf.len) break;
        }

        const term = try child.wait();

        if (term != .Exited or term.Exited != 0) {
            return null;
        }

        // Trim trailing newline if present
        const output = buf[0..total_read];
        const trimmed = std.mem.trimRight(u8, output, "\n\r");
        return try self.allocator.dupe(u8, trimmed);
    }
};

fn expandVariables(allocator: std.mem.Allocator, template: []const u8, ctx: PromptContext) ![]const u8 {
    var result = std.ArrayListUnmanaged(u8){};
    defer result.deinit(allocator);

    var i: usize = 0;
    while (i < template.len) {
        if (template[i] == '$' and i + 1 < template.len and template[i + 1] == '{') {
            const start = i + 2;
            const end = std.mem.indexOfScalarPos(u8, template, start, '}') orelse {
                try result.append(allocator, template[i]);
                i += 1;
                continue;
            };

            const var_name = template[start..end];
            const value = try getVariable(allocator, var_name, ctx);
            defer allocator.free(value);
            try result.appendSlice(allocator, value);
            i = end + 1;
        } else {
            try result.append(allocator, template[i]);
            i += 1;
        }
    }

    return try result.toOwnedSlice(allocator);
}

fn getVariable(allocator: std.mem.Allocator, name: []const u8, ctx: PromptContext) ![]const u8 {
    if (std.mem.eql(u8, name, "user")) {
        return try allocator.dupe(u8, ctx.user);
    } else if (std.mem.eql(u8, name, "host")) {
        return try allocator.dupe(u8, ctx.host);
    } else if (std.mem.eql(u8, name, "cwd")) {
        return try allocator.dupe(u8, ctx.cwd);
    } else if (std.mem.eql(u8, name, "exit_status")) {
        return try std.fmt.allocPrint(allocator, "{d}", .{ctx.exit_code});
    } else if (std.mem.eql(u8, name, "jobs")) {
        return try std.fmt.allocPrint(allocator, "{d}", .{ctx.shell_state.jobs.items.len});
    } else if (std.mem.eql(u8, name, "git")) {
        // This is a placeholder - actual git rendering happens in PromptEngine.render
        return try allocator.dupe(u8, "");
    }
    return try allocator.dupe(u8, "");
}
