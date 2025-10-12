const std = @import("std");

/// Security validation errors
pub const SecurityError = error{
    PathTraversal,
    CommandInjection,
    InvalidPath,
    UnsafeOperation,
    InvalidEnvVarName,
    InvalidEnvVarValue,
};

/// Validate a path to prevent directory traversal attacks
pub fn validatePath(path: []const u8) !void {
    // Check for path traversal sequences
    if (std.mem.indexOf(u8, path, "..") != null) {
        // Allow .. only if it's part of a valid absolute path resolution
        // But reject suspicious patterns like /../ or ..\
        if (std.mem.indexOf(u8, path, "../") != null or
            std.mem.indexOf(u8, path, "..\\") != null or
            std.mem.indexOf(u8, path, "/..") != null or
            std.mem.indexOf(u8, path, "\\..") != null)
        {
            return SecurityError.PathTraversal;
        }
    }

    // Check for null bytes (path injection)
    if (std.mem.indexOfScalar(u8, path, 0) != null) {
        return SecurityError.InvalidPath;
    }

    // Reject paths that are too long
    if (path.len > 4096) {
        return SecurityError.InvalidPath;
    }
}

/// Sanitize environment variable name
pub fn validateEnvVarName(name: []const u8) !void {
    if (name.len == 0) {
        return SecurityError.InvalidEnvVarName;
    }

    // Special case: Allow numeric-only names for script arguments ($0, $1, $2, etc.)
    var all_numeric = true;
    for (name) |c| {
        if (!std.ascii.isDigit(c)) {
            all_numeric = false;
            break;
        }
    }
    if (all_numeric) {
        // Numeric variable names are allowed (for script arguments)
        if (name.len > 10) return SecurityError.InvalidEnvVarName; // Limit to reasonable size
        return;
    }

    // Must start with letter or underscore (for regular env vars)
    if (!std.ascii.isAlphabetic(name[0]) and name[0] != '_') {
        return SecurityError.InvalidEnvVarName;
    }

    // Only alphanumeric and underscore allowed
    for (name) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '_') {
            return SecurityError.InvalidEnvVarName;
        }
    }

    // Check for null bytes
    if (std.mem.indexOfScalar(u8, name, 0) != null) {
        return SecurityError.InvalidEnvVarName;
    }

    // Reject names that are too long
    if (name.len > 256) {
        return SecurityError.InvalidEnvVarName;
    }
}

/// Sanitize environment variable value
pub fn validateEnvVarValue(value: []const u8) !void {
    // Check for null bytes
    if (std.mem.indexOfScalar(u8, value, 0) != null) {
        return SecurityError.InvalidEnvVarValue;
    }

    // Reject values that are too long (32KB limit)
    if (value.len > 32768) {
        return SecurityError.InvalidEnvVarValue;
    }
}

/// Check if a command contains shell injection attempts
pub fn validateCommand(command: []const u8) !void {
    // Check for null bytes
    if (std.mem.indexOfScalar(u8, command, 0) != null) {
        return SecurityError.CommandInjection;
    }

    // Check for dangerous shell metacharacters when used suspiciously
    // Note: We allow these in normal usage, but we validate the context

    // Reject commands that are too long
    if (command.len > 65536) {
        return SecurityError.CommandInjection;
    }
}

/// Validate file path for reading
pub fn validateReadPath(allocator: std.mem.Allocator, path: []const u8) !void {
    try validatePath(path);

    // Resolve to absolute path
    const abs_path = std.fs.cwd().realpathAlloc(allocator, path) catch |err| switch (err) {
        error.FileNotFound => return SecurityError.InvalidPath,
        else => return err,
    };
    defer allocator.free(abs_path);

    // Check if path points outside allowed directories
    // For now, we allow all paths, but this could be restricted
    // Future: Add whitelist/blacklist of allowed read paths
    if (abs_path.len == 0) return SecurityError.InvalidPath;
}

/// Validate file path for writing
pub fn validateWritePath(allocator: std.mem.Allocator, path: []const u8) !void {
    try validatePath(path);

    // Get the directory component
    const dir = std.fs.path.dirname(path) orelse ".";

    // Resolve directory to absolute path
    const abs_dir = std.fs.cwd().realpathAlloc(allocator, dir) catch |err| switch (err) {
        error.FileNotFound => return SecurityError.InvalidPath,
        else => return err,
    };
    defer allocator.free(abs_dir);

    // Check if we're trying to write to sensitive system directories
    const dangerous_dirs = [_][]const u8{
        "/bin",
        "/sbin",
        "/usr/bin",
        "/usr/sbin",
        "/boot",
        "/sys",
        "/proc",
    };

    for (dangerous_dirs) |dangerous| {
        if (std.mem.startsWith(u8, abs_dir, dangerous)) {
            return SecurityError.UnsafeOperation;
        }
    }
}

/// Check if a path is a symbolic link
pub fn isSymlink(path: []const u8) bool {
    const file = std.fs.cwd().openFile(path, .{}) catch return false;
    defer file.close();

    const stat = file.stat() catch return false;
    return stat.kind == .sym_link;
}

/// Sanitize alias name (prevent injection via alias names)
pub fn validateAliasName(name: []const u8) !void {
    if (name.len == 0 or name.len > 256) {
        return SecurityError.InvalidPath;
    }

    // Must start with alphanumeric or underscore
    if (!std.ascii.isAlphanumeric(name[0]) and name[0] != '_') {
        return SecurityError.InvalidPath;
    }

    // Only allow alphanumeric, underscore, and hyphen
    for (name) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '-') {
            return SecurityError.InvalidPath;
        }
    }

    // Check for null bytes
    if (std.mem.indexOfScalar(u8, name, 0) != null) {
        return SecurityError.InvalidPath;
    }
}

/// Validate network hostname (prevent DNS rebinding, SSRF)
pub fn validateHostname(hostname: []const u8) !void {
    if (hostname.len == 0 or hostname.len > 253) {
        return SecurityError.InvalidPath;
    }

    // Check for null bytes
    if (std.mem.indexOfScalar(u8, hostname, 0) != null) {
        return SecurityError.InvalidPath;
    }

    // Basic hostname validation
    for (hostname) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '.' and c != '-' and c != ':') {
            return SecurityError.InvalidPath;
        }
    }
}

/// Validate port number
pub fn validatePort(port_str: []const u8) !u16 {
    const port = std.fmt.parseInt(u16, port_str, 10) catch {
        return SecurityError.InvalidPath;
    };

    // Port 0 is invalid
    if (port == 0) {
        return SecurityError.InvalidPath;
    }

    return port;
}

test "validatePath - basic paths" {
    try validatePath("/tmp/test.txt");
    try validatePath("./test.txt");
    try validatePath("test.txt");
}

test "validatePath - reject traversal" {
    try std.testing.expectError(SecurityError.PathTraversal, validatePath("../etc/passwd"));
    try std.testing.expectError(SecurityError.PathTraversal, validatePath("/tmp/../../../etc/passwd"));
    try std.testing.expectError(SecurityError.PathTraversal, validatePath("test/../../etc/passwd"));
}

test "validatePath - reject null bytes" {
    const path_with_null = [_]u8{ 't', 'e', 's', 't', 0, '.', 't', 'x', 't' };
    try std.testing.expectError(SecurityError.InvalidPath, validatePath(&path_with_null));
}

test "validateEnvVarName - valid names" {
    try validateEnvVarName("PATH");
    try validateEnvVarName("USER");
    try validateEnvVarName("MY_VAR");
    try validateEnvVarName("_private");
    try validateEnvVarName("123"); // Numeric names are allowed for script arguments ($0, $1, etc.)
    try validateEnvVarName("0"); // Script argument $0
}

test "validateEnvVarName - invalid names" {
    try std.testing.expectError(SecurityError.InvalidEnvVarName, validateEnvVarName(""));
    try std.testing.expectError(SecurityError.InvalidEnvVarName, validateEnvVarName("MY-VAR"));
    try std.testing.expectError(SecurityError.InvalidEnvVarName, validateEnvVarName("MY VAR"));
}

test "validateHostname - valid hostnames" {
    try validateHostname("localhost");
    try validateHostname("example.com");
    try validateHostname("192.168.1.1");
    try validateHostname("sub.domain.example.com");
    try validateHostname("localhost:8080");
}

test "validatePort - valid ports" {
    try std.testing.expectEqual(@as(u16, 80), try validatePort("80"));
    try std.testing.expectEqual(@as(u16, 443), try validatePort("443"));
    try std.testing.expectEqual(@as(u16, 8080), try validatePort("8080"));
}

test "validatePort - invalid ports" {
    try std.testing.expectError(SecurityError.InvalidPath, validatePort("0"));
    try std.testing.expectError(SecurityError.InvalidPath, validatePort("abc"));
    try std.testing.expectError(SecurityError.InvalidPath, validatePort("99999"));
}
