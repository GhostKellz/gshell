/// Command validation for GShell
/// Checks if commands exist in PATH for real-time error highlighting
const std = @import("std");

/// Result of command validation
pub const ValidationResult = struct {
    command: []const u8,
    is_valid: bool,
    is_builtin: bool,
    path: ?[]const u8, // Full path if found in PATH
};

/// Command validator
/// Checks if commands exist as builtins or in PATH
pub const CommandValidator = struct {
    allocator: std.mem.Allocator,
    path_cache: std.StringHashMap(bool),
    builtins: std.StringHashMap(void),

    /// Initialize the validator
    pub fn init(allocator: std.mem.Allocator) !CommandValidator {
        var validator = CommandValidator{
            .allocator = allocator,
            .path_cache = std.StringHashMap(bool).init(allocator),
            .builtins = std.StringHashMap(void).init(allocator),
        };

        // Register GShell builtins
        try validator.registerBuiltins();

        return validator;
    }

    /// Clean up resources
    pub fn deinit(self: *CommandValidator) void {
        self.path_cache.deinit();
        self.builtins.deinit();
    }

    /// Register all GShell built-in commands
    fn registerBuiltins(self: *CommandValidator) !void {
        const builtin_list = [_][]const u8{
            // Core shell builtins
            "cd",
            "pwd",
            "echo",
            "exit",
            "export",
            "alias",
            "unalias",
            "source",
            "exec",
            "jobs",
            "fg",
            "bg",
            "help",
            "history",

            // Editor integration
            "e",
            "fc",

            // GShell-specific FFI builtins
            "use_starship",
            "enable_plugin",
            "load_vivid_theme",
            "setenv",
            "getenv",
            "command_exists",
            "path_exists",
            "read_file",
            "write_file",
            "git_branch",
            "git_dirty",
            "git_repo_root",
            "in_git_repo",
            "get_user",
            "get_hostname",
            "get_cwd",

            // Networking builtins
            "net-test",
            "net-resolve",
            "net-fetch",
            "net-scan",
        };

        for (builtin_list) |builtin| {
            try self.builtins.put(builtin, {});
        }
    }

    /// Check if a command is valid (builtin or in PATH)
    pub fn isCommandValid(self: *CommandValidator, command: []const u8) bool {
        // Check if it's a builtin first (instant)
        if (self.builtins.contains(command)) {
            return true;
        }

        // Check cache
        if (self.path_cache.get(command)) |cached| {
            return cached;
        }

        // Check PATH
        const is_valid = self.checkPath(command);

        // Cache the result
        self.path_cache.put(self.allocator.dupe(u8, command) catch return is_valid, is_valid) catch {};

        return is_valid;
    }

    /// Check if command exists in PATH
    fn checkPath(self: *CommandValidator, command: []const u8) bool {
        const path_env = std.posix.getenv("PATH") orelse return false;

        var iter = std.mem.splitScalar(u8, path_env, ':');
        while (iter.next()) |dir| {
            const full_path = std.fmt.allocPrint(
                self.allocator,
                "{s}/{s}",
                .{ dir, command },
            ) catch continue;
            defer self.allocator.free(full_path);

            // Check if file exists and is executable
            std.fs.accessAbsolute(full_path, .{}) catch continue;

            // File exists, now check if it's executable
            const stat = std.fs.cwd().statFile(full_path) catch continue;
            _ = stat;

            // On Unix, we should check execute permission, but for simplicity
            // we'll just check if the file exists in PATH
            return true;
        }

        return false;
    }

    /// Get validation result with details
    pub fn validate(self: *CommandValidator, command: []const u8) ValidationResult {
        const is_builtin = self.builtins.contains(command);
        if (is_builtin) {
            return .{
                .command = command,
                .is_valid = true,
                .is_builtin = true,
                .path = null,
            };
        }

        const is_valid = self.checkPath(command);
        return .{
            .command = command,
            .is_valid = is_valid,
            .is_builtin = false,
            .path = null, // TODO: Return full path
        };
    }

    /// Clear the PATH cache (call when PATH environment variable changes)
    pub fn clearCache(self: *CommandValidator) void {
        self.path_cache.clearRetainingCapacity();
    }
};

test "builtin commands are valid" {
    var validator = try CommandValidator.init(std.testing.allocator);
    defer validator.deinit();

    try std.testing.expect(validator.isCommandValid("cd"));
    try std.testing.expect(validator.isCommandValid("exit"));
    try std.testing.expect(validator.isCommandValid("alias"));
    try std.testing.expect(validator.isCommandValid("use_starship"));
    try std.testing.expect(validator.isCommandValid("enable_plugin"));
}

test "common system commands are valid" {
    var validator = try CommandValidator.init(std.testing.allocator);
    defer validator.deinit();

    // These should exist on most systems
    try std.testing.expect(validator.isCommandValid("ls"));
    try std.testing.expect(validator.isCommandValid("cat"));
    try std.testing.expect(validator.isCommandValid("echo"));
}

test "invalid commands are rejected" {
    var validator = try CommandValidator.init(std.testing.allocator);
    defer validator.deinit();

    try std.testing.expect(!validator.isCommandValid("this_command_does_not_exist_12345"));
    try std.testing.expect(!validator.isCommandValid("invalidcmd"));
}

test "validation result details" {
    var validator = try CommandValidator.init(std.testing.allocator);
    defer validator.deinit();

    const result1 = validator.validate("cd");
    try std.testing.expect(result1.is_valid);
    try std.testing.expect(result1.is_builtin);

    const result2 = validator.validate("ls");
    try std.testing.expect(result2.is_valid);
    try std.testing.expect(!result2.is_builtin);

    const result3 = validator.validate("invalidcmd");
    try std.testing.expect(!result3.is_valid);
    try std.testing.expect(!result3.is_builtin);
}

test "cache functionality" {
    var validator = try CommandValidator.init(std.testing.allocator);
    defer validator.deinit();

    // First call caches the result
    _ = validator.isCommandValid("ls");

    // Second call should use cache (faster)
    const is_valid = validator.isCommandValid("ls");
    try std.testing.expect(is_valid);

    // Clear cache
    validator.clearCache();

    // Should still work after cache clear
    const is_valid2 = validator.isCommandValid("ls");
    try std.testing.expect(is_valid2);
}
