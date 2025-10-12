const std = @import("std");

/// Version detection for various programming languages and runtimes
pub const VersionDetector = struct {
    allocator: std.mem.Allocator,
    cache: std.StringHashMap(VersionInfo),
    cache_ttl_ms: i64 = 5000, // Cache for 5 seconds

    pub const VersionInfo = struct {
        version: []const u8,
        icon: []const u8,
        detected_at_ms: i64,

        pub fn deinit(self: *VersionInfo, allocator: std.mem.Allocator) void {
            allocator.free(self.version);
        }
    };

    pub fn init(allocator: std.mem.Allocator) VersionDetector {
        return .{
            .allocator = allocator,
            .cache = std.StringHashMap(VersionInfo).init(allocator),
        };
    }

    pub fn deinit(self: *VersionDetector) void {
        var iter = self.cache.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            var info = entry.value_ptr;
            info.deinit(self.allocator);
        }
        self.cache.deinit();
    }

    /// Get current timestamp in milliseconds
    fn getCurrentTimeMs() i64 {
        return std.time.milliTimestamp();
    }

    /// Check if cached version is still valid
    fn isCacheValid(self: *VersionDetector, key: []const u8) bool {
        const info = self.cache.get(key) orelse return false;
        const now = getCurrentTimeMs();
        return (now - info.detected_at_ms) < self.cache_ttl_ms;
    }

    /// Detect Node.js version if package.json exists
    pub fn detectNodeJs(self: *VersionDetector) ?VersionInfo {
        const cache_key = "nodejs";

        // Check cache first
        if (self.isCacheValid(cache_key)) {
            return self.cache.get(cache_key);
        }

        // Check if package.json exists
        std.fs.cwd().access("package.json", .{}) catch {
            return null;
        };

        // Get node version
        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "node", "--version" },
        }) catch {
            return null;
        };
        defer self.allocator.free(result.stdout);
        defer self.allocator.free(result.stderr);

        if (result.term != .Exited or result.term.Exited != 0) {
            return null;
        }

        // Parse version (remove 'v' prefix and trim)
        var version_str = std.mem.trim(u8, result.stdout, " \n\r\t");
        if (version_str.len > 0 and version_str[0] == 'v') {
            version_str = version_str[1..];
        }

        const owned_version = self.allocator.dupe(u8, version_str) catch {
            return null;
        };

        const info = VersionInfo{
            .version = owned_version,
            .icon = "",
            .detected_at_ms = getCurrentTimeMs(),
        };

        // Cache it
        const owned_key = self.allocator.dupe(u8, cache_key) catch {
            self.allocator.free(owned_version);
            return null;
        };

        self.cache.put(owned_key, info) catch {
            self.allocator.free(owned_key);
            self.allocator.free(owned_version);
            return null;
        };

        return info;
    }

    /// Detect Rust version if Cargo.toml exists
    pub fn detectRust(self: *VersionDetector) ?VersionInfo {
        const cache_key = "rust";

        // Check cache first
        if (self.isCacheValid(cache_key)) {
            return self.cache.get(cache_key);
        }

        // Check if Cargo.toml exists
        std.fs.cwd().access("Cargo.toml", .{}) catch {
            return null;
        };

        // Get rustc version
        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "rustc", "--version" },
        }) catch {
            return null;
        };
        defer self.allocator.free(result.stdout);
        defer self.allocator.free(result.stderr);

        if (result.term != .Exited or result.term.Exited != 0) {
            return null;
        }

        // Parse version from "rustc 1.75.0 (hash date)"
        const stdout = std.mem.trim(u8, result.stdout, " \n\r\t");
        var iter = std.mem.splitScalar(u8, stdout, ' ');
        _ = iter.next(); // Skip "rustc"
        const version_str = iter.next() orelse return null;

        const owned_version = self.allocator.dupe(u8, version_str) catch {
            return null;
        };

        const info = VersionInfo{
            .version = owned_version,
            .icon = "",
            .detected_at_ms = getCurrentTimeMs(),
        };

        // Cache it
        const owned_key = self.allocator.dupe(u8, cache_key) catch {
            self.allocator.free(owned_version);
            return null;
        };

        self.cache.put(owned_key, info) catch {
            self.allocator.free(owned_key);
            self.allocator.free(owned_version);
            return null;
        };

        return info;
    }

    /// Detect Go version if go.mod exists
    pub fn detectGo(self: *VersionDetector) ?VersionInfo {
        const cache_key = "go";

        // Check cache first
        if (self.isCacheValid(cache_key)) {
            return self.cache.get(cache_key);
        }

        // Check if go.mod exists
        std.fs.cwd().access("go.mod", .{}) catch {
            return null;
        };

        // Get go version
        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "go", "version" },
        }) catch {
            return null;
        };
        defer self.allocator.free(result.stdout);
        defer self.allocator.free(result.stderr);

        if (result.term != .Exited or result.term.Exited != 0) {
            return null;
        }

        // Parse version from "go version go1.21.5 linux/amd64"
        const stdout = std.mem.trim(u8, result.stdout, " \n\r\t");
        var iter = std.mem.splitScalar(u8, stdout, ' ');
        _ = iter.next(); // Skip "go"
        _ = iter.next(); // Skip "version"
        var version_str = iter.next() orelse return null;

        // Remove "go" prefix
        if (std.mem.startsWith(u8, version_str, "go")) {
            version_str = version_str[2..];
        }

        const owned_version = self.allocator.dupe(u8, version_str) catch {
            return null;
        };

        const info = VersionInfo{
            .version = owned_version,
            .icon = "",
            .detected_at_ms = getCurrentTimeMs(),
        };

        // Cache it
        const owned_key = self.allocator.dupe(u8, cache_key) catch {
            self.allocator.free(owned_version);
            return null;
        };

        self.cache.put(owned_key, info) catch {
            self.allocator.free(owned_key);
            self.allocator.free(owned_version);
            return null;
        };

        return info;
    }

    /// Detect Python version if requirements.txt, setup.py, or pyproject.toml exists
    pub fn detectPython(self: *VersionDetector) ?VersionInfo {
        const cache_key = "python";

        // Check cache first
        if (self.isCacheValid(cache_key)) {
            return self.cache.get(cache_key);
        }

        // Check if Python project files exist
        const has_requirements = blk: {
            std.fs.cwd().access("requirements.txt", .{}) catch break :blk false;
            break :blk true;
        };
        const has_setup = blk: {
            std.fs.cwd().access("setup.py", .{}) catch break :blk false;
            break :blk true;
        };
        const has_pyproject = blk: {
            std.fs.cwd().access("pyproject.toml", .{}) catch break :blk false;
            break :blk true;
        };

        if (!has_requirements and !has_setup and !has_pyproject) {
            return null;
        }

        // Get python version
        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "python3", "--version" },
        }) catch {
            return null;
        };
        defer self.allocator.free(result.stdout);
        defer self.allocator.free(result.stderr);

        if (result.term != .Exited or result.term.Exited != 0) {
            return null;
        }

        // Parse version from "Python 3.11.5"
        const stdout = std.mem.trim(u8, result.stdout, " \n\r\t");
        var iter = std.mem.splitScalar(u8, stdout, ' ');
        _ = iter.next(); // Skip "Python"
        const version_str = iter.next() orelse return null;

        const owned_version = self.allocator.dupe(u8, version_str) catch {
            return null;
        };

        const info = VersionInfo{
            .version = owned_version,
            .icon = "",
            .detected_at_ms = getCurrentTimeMs(),
        };

        // Cache it
        const owned_key = self.allocator.dupe(u8, cache_key) catch {
            self.allocator.free(owned_version);
            return null;
        };

        self.cache.put(owned_key, info) catch {
            self.allocator.free(owned_key);
            self.allocator.free(owned_version);
            return null;
        };

        return info;
    }

    /// Detect Zig version if build.zig exists
    pub fn detectZig(self: *VersionDetector) ?VersionInfo {
        const cache_key = "zig";

        // Check cache first
        if (self.isCacheValid(cache_key)) {
            return self.cache.get(cache_key);
        }

        // Check if build.zig exists
        std.fs.cwd().access("build.zig", .{}) catch {
            return null;
        };

        // Get zig version
        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "zig", "version" },
        }) catch {
            return null;
        };
        defer self.allocator.free(result.stdout);
        defer self.allocator.free(result.stderr);

        if (result.term != .Exited or result.term.Exited != 0) {
            return null;
        }

        const version_str = std.mem.trim(u8, result.stdout, " \n\r\t");

        const owned_version = self.allocator.dupe(u8, version_str) catch {
            return null;
        };

        const info = VersionInfo{
            .version = owned_version,
            .icon = "⚡",
            .detected_at_ms = getCurrentTimeMs(),
        };

        // Cache it
        const owned_key = self.allocator.dupe(u8, cache_key) catch {
            self.allocator.free(owned_version);
            return null;
        };

        self.cache.put(owned_key, info) catch {
            self.allocator.free(owned_key);
            self.allocator.free(owned_version);
            return null;
        };

        return info;
    }

    /// Detect all applicable versions in current directory
    pub fn detectAll(self: *VersionDetector) std.ArrayList(VersionInfo) {
        var versions = std.ArrayList(VersionInfo).init(self.allocator);

        // Try each detector
        if (self.detectNodeJs()) |info| {
            versions.append(info) catch {};
        }

        if (self.detectRust()) |info| {
            versions.append(info) catch {};
        }

        if (self.detectGo()) |info| {
            versions.append(info) catch {};
        }

        if (self.detectPython()) |info| {
            versions.append(info) catch {};
        }

        if (self.detectZig()) |info| {
            versions.append(info) catch {};
        }

        return versions;
    }

    /// Clear version cache
    pub fn clearCache(self: *VersionDetector) void {
        var iter = self.cache.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            var info = entry.value_ptr;
            info.deinit(self.allocator);
        }
        self.cache.clearRetainingCapacity();
    }
};

test "VersionDetector init" {
    const allocator = std.testing.allocator;
    var detector = VersionDetector.init(allocator);
    defer detector.deinit();
}
