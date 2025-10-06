const std = @import("std");
const Allocator = std.mem.Allocator;

pub const CompletionType = enum {
    command, // First word - scan PATH
    file, // Arguments - scan filesystem
    directory, // Arguments ending with / - only dirs
};

pub const CompletionResult = struct {
    matches: std.ArrayList([]const u8),
    common_prefix: []const u8,
    allocator: Allocator,

    pub fn init(allocator: Allocator) CompletionResult {
        return CompletionResult{
            .matches = std.ArrayList([]const u8){},
            .common_prefix = "",
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *CompletionResult) void {
        for (self.matches.items) |match| {
            self.allocator.free(match);
        }
        self.matches.deinit(self.allocator);
        if (self.common_prefix.len > 0) {
            self.allocator.free(self.common_prefix);
        }
    }
};

pub const CompletionEngine = struct {
    allocator: Allocator,
    path_cache: ?std.ArrayList([]const u8),

    pub fn init(allocator: Allocator) CompletionEngine {
        return CompletionEngine{
            .allocator = allocator,
            .path_cache = null,
        };
    }

    pub fn deinit(self: *CompletionEngine) void {
        if (self.path_cache) |*cache| {
            for (cache.items) |item| {
                self.allocator.free(item);
            }
            cache.deinit(self.allocator);
        }
    }

    /// Main completion entry point
    pub fn complete(
        self: *CompletionEngine,
        input: []const u8,
        cursor_pos: usize,
    ) !CompletionResult {
        // Get the portion of input before cursor
        const before_cursor = input[0..cursor_pos];

        // Find the current word being completed
        const word_start = self.findWordStart(before_cursor);
        const word = before_cursor[word_start..];

        // Determine completion type
        const is_first_word = self.isFirstWord(before_cursor, word_start);

        if (is_first_word) {
            // Complete commands from PATH
            return self.completeCommand(word);
        } else {
            // Complete files/directories
            const only_dirs = std.mem.endsWith(u8, word, "/");
            return self.completeFile(word, only_dirs);
        }
    }

    /// Find the start of the current word (back to last space/start)
    fn findWordStart(self: *CompletionEngine, text: []const u8) usize {
        _ = self;
        if (text.len == 0) return 0;

        var i: usize = text.len;
        while (i > 0) {
            i -= 1;
            if (text[i] == ' ' or text[i] == '\t') {
                return i + 1;
            }
        }
        return 0;
    }

    /// Check if this is the first word (command position)
    fn isFirstWord(self: *CompletionEngine, text: []const u8, word_start: usize) bool {
        _ = self;
        // Check if there's only whitespace before word_start
        for (text[0..word_start]) |c| {
            if (c != ' ' and c != '\t') {
                return false;
            }
        }
        return true;
    }

    /// Complete command names from PATH
    fn completeCommand(self: *CompletionEngine, prefix: []const u8) !CompletionResult {
        var result = CompletionResult.init(self.allocator);
        errdefer result.deinit();

        // Scan PATH if not cached
        if (self.path_cache == null) {
            self.path_cache = try self.scanPATH();
        }

        // Filter commands that start with prefix
        if (self.path_cache) |cache| {
            for (cache.items) |cmd| {
                if (std.mem.startsWith(u8, cmd, prefix)) {
                    const match = try self.allocator.dupe(u8, cmd);
                    try result.matches.append(self.allocator, match);
                }
            }
        }

        // Calculate common prefix
        if (result.matches.items.len > 0) {
            result.common_prefix = try self.findCommonPrefix(result.matches.items);
        }

        return result;
    }

    /// Complete file or directory paths
    fn completeFile(self: *CompletionEngine, prefix: []const u8, only_dirs: bool) !CompletionResult {
        var result = CompletionResult.init(self.allocator);
        errdefer result.deinit();

        // Parse the prefix into directory and filename parts
        const last_slash = std.mem.lastIndexOf(u8, prefix, "/");
        const dir_path = if (last_slash) |idx|
            prefix[0 .. idx + 1]
        else
            "./";

        const file_prefix = if (last_slash) |idx|
            prefix[idx + 1 ..]
        else
            prefix;

        // Open directory
        var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch {
            return result; // Can't open directory, return empty
        };
        defer dir.close();

        // Iterate directory entries
        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            // Skip if not matching prefix
            if (!std.mem.startsWith(u8, entry.name, file_prefix)) {
                continue;
            }

            // Skip non-directories if only_dirs is true
            if (only_dirs and entry.kind != .directory) {
                continue;
            }

            // Build full path
            var path_buf: [std.fs.max_path_bytes]u8 = undefined;
            const full_path = try std.fmt.bufPrint(&path_buf, "{s}{s}", .{ dir_path, entry.name });

            // Add trailing slash for directories
            if (entry.kind == .directory) {
                const with_slash = try std.fmt.bufPrint(&path_buf, "{s}/", .{full_path});
                const match = try self.allocator.dupe(u8, with_slash);
                try result.matches.append(self.allocator, match);
            } else {
                const match = try self.allocator.dupe(u8, full_path);
                try result.matches.append(self.allocator, match);
            }
        }

        // Calculate common prefix
        if (result.matches.items.len > 0) {
            result.common_prefix = try self.findCommonPrefix(result.matches.items);
        }

        return result;
    }

    /// Scan $PATH environment variable for executables
    fn scanPATH(self: *CompletionEngine) !std.ArrayList([]const u8) {
        var commands = std.ArrayList([]const u8){};
        errdefer {
            for (commands.items) |cmd| {
                self.allocator.free(cmd);
            }
            commands.deinit(self.allocator);
        }

        // Get PATH environment variable
        const path_env = std.posix.getenv("PATH") orelse return commands;

        // Split by ':'
        var iter = std.mem.splitScalar(u8, path_env, ':');
        while (iter.next()) |path_dir| {
            // Open directory
            var dir = std.fs.openDirAbsolute(path_dir, .{ .iterate = true }) catch continue;
            defer dir.close();

            // Iterate files in directory
            var dir_iter = dir.iterate();
            while (dir_iter.next() catch continue) |entry| {
                // Only executable files
                if (entry.kind != .file) continue;

                // Check if executable (simple check - file exists)
                // TODO: Could check actual executable permission
                const name_dupe = try self.allocator.dupe(u8, entry.name);
                errdefer self.allocator.free(name_dupe);

                // Avoid duplicates
                var is_duplicate = false;
                for (commands.items) |existing| {
                    if (std.mem.eql(u8, existing, name_dupe)) {
                        is_duplicate = true;
                        break;
                    }
                }

                if (!is_duplicate) {
                    try commands.append(self.allocator, name_dupe);
                } else {
                    self.allocator.free(name_dupe);
                }
            }
        }

        return commands;
    }

    /// Find the longest common prefix among matches
    fn findCommonPrefix(self: *CompletionEngine, matches: []const []const u8) ![]const u8 {
        if (matches.len == 0) return "";
        if (matches.len == 1) return try self.allocator.dupe(u8, matches[0]);

        // Find minimum length
        var min_len: usize = matches[0].len;
        for (matches[1..]) |match| {
            if (match.len < min_len) {
                min_len = match.len;
            }
        }

        // Find common prefix length
        var common_len: usize = 0;
        while (common_len < min_len) : (common_len += 1) {
            const ch = matches[0][common_len];
            for (matches[1..]) |match| {
                if (match[common_len] != ch) {
                    return try self.allocator.dupe(u8, matches[0][0..common_len]);
                }
            }
        }

        return try self.allocator.dupe(u8, matches[0][0..common_len]);
    }
};

test "completion engine initialization" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = CompletionEngine.init(allocator);
    defer engine.deinit();
}

test "find word start" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = CompletionEngine.init(allocator);
    defer engine.deinit();

    try testing.expectEqual(@as(usize, 0), engine.findWordStart("echo"));
    try testing.expectEqual(@as(usize, 5), engine.findWordStart("echo hello"));
    try testing.expectEqual(@as(usize, 11), engine.findWordStart("echo hello world"));
}

test "is first word" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = CompletionEngine.init(allocator);
    defer engine.deinit();

    try testing.expect(engine.isFirstWord("echo", 0));
    try testing.expect(!engine.isFirstWord("echo hello", 5));
    try testing.expect(engine.isFirstWord("  echo", 2));
}

test "common prefix" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = CompletionEngine.init(allocator);
    defer engine.deinit();

    const matches1 = [_][]const u8{ "echo", "ech", "echotest" };
    const prefix1 = try engine.findCommonPrefix(&matches1);
    defer allocator.free(prefix1);
    try testing.expectEqualStrings("ech", prefix1);

    const matches2 = [_][]const u8{ "test", "testing", "tester" };
    const prefix2 = try engine.findCommonPrefix(&matches2);
    defer allocator.free(prefix2);
    try testing.expectEqualStrings("test", prefix2);
}
