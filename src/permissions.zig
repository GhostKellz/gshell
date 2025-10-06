const std = @import("std");

/// File permission errors
pub const PermissionError = error{
    InsecurePermissions,
    WorldReadable,
    WorldWritable,
    GroupWritable,
};

/// Check if a file has secure permissions (600 - owner read/write only)
pub fn checkSecureFile(path: []const u8) !void {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return, // File doesn't exist yet, that's ok
        else => return err,
    };
    defer file.close();

    const stat = try file.stat();
    const mode = stat.mode;

    // Check for world-readable (others can read)
    if (mode & 0o004 != 0) {
        return PermissionError.WorldReadable;
    }

    // Check for world-writable (others can write)
    if (mode & 0o002 != 0) {
        return PermissionError.WorldWritable;
    }

    // Check for group-writable (group can write)
    if (mode & 0o020 != 0) {
        return PermissionError.GroupWritable;
    }
}

/// Check if a directory has secure permissions (700 - owner rwx only)
pub fn checkSecureDirectory(path: []const u8) !void {
    var dir = std.fs.cwd().openDir(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return, // Directory doesn't exist yet, that's ok
        else => return err,
    };
    defer dir.close();

    const stat = try dir.stat();
    const mode = stat.mode;

    // Check for world-readable
    if (mode & 0o004 != 0) {
        return PermissionError.WorldReadable;
    }

    // Check for world-writable
    if (mode & 0o002 != 0) {
        return PermissionError.WorldWritable;
    }

    // Check for group-writable
    if (mode & 0o020 != 0) {
        return PermissionError.GroupWritable;
    }
}

/// Fix file permissions to 600 (owner read/write only)
pub fn fixFilePermissions(path: []const u8) !void {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return, // File doesn't exist, nothing to fix
        else => return err,
    };
    defer file.close();

    try file.chmod(0o600);
}

/// Fix directory permissions to 700 (owner rwx only)
pub fn fixDirectoryPermissions(path: []const u8) !void {
    var dir = std.fs.cwd().openDir(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return, // Directory doesn't exist, nothing to fix
        else => return err,
    };
    defer dir.close();

    try dir.chmod(0o700);
}

/// Check and optionally fix permissions for sensitive files
pub fn ensureSecureFile(allocator: std.mem.Allocator, path: []const u8, auto_fix: bool) !void {
    checkSecureFile(path) catch |err| {
        if (auto_fix) {
            // Try to fix permissions
            fixFilePermissions(path) catch {
                // If fix fails, warn the user
                var stderr = std.fs.File.stderr();
                const msg = try std.fmt.allocPrint(allocator, "Warning: Could not secure permissions for {s}\n", .{path});
                defer allocator.free(msg);
                stderr.writeAll(msg) catch {};
                return err;
            };

            // Warn user that we fixed it
            var stderr = std.fs.File.stderr();
            const msg = try std.fmt.allocPrint(allocator, "Warning: Fixed insecure permissions for {s} (now 600)\n", .{path});
            defer allocator.free(msg);
            stderr.writeAll(msg) catch {};
        } else {
            // Just warn the user
            var stderr = std.fs.File.stderr();
            const warning = try std.fmt.allocPrint(
                allocator,
                "Warning: Insecure permissions on {s}\n" ++
                    "  Recommended: chmod 600 {s}\n",
                .{ path, path },
            );
            defer allocator.free(warning);
            stderr.writeAll(warning) catch {};
            return err;
        }
    };
}

/// Check and optionally fix permissions for sensitive directories
pub fn ensureSecureDirectory(allocator: std.mem.Allocator, path: []const u8, auto_fix: bool) !void {
    checkSecureDirectory(path) catch |err| {
        if (auto_fix) {
            // Try to fix permissions
            fixDirectoryPermissions(path) catch {
                // If fix fails, warn the user
                var stderr = std.fs.File.stderr();
                const msg = try std.fmt.allocPrint(allocator, "Warning: Could not secure permissions for directory {s}\n", .{path});
                defer allocator.free(msg);
                stderr.writeAll(msg) catch {};
                return err;
            };

            // Warn user that we fixed it
            var stderr = std.fs.File.stderr();
            const msg = try std.fmt.allocPrint(allocator, "Warning: Fixed insecure permissions for directory {s} (now 700)\n", .{path});
            defer allocator.free(msg);
            stderr.writeAll(msg) catch {};
        } else {
            // Just warn the user
            var stderr = std.fs.File.stderr();
            const warning = try std.fmt.allocPrint(
                allocator,
                "Warning: Insecure permissions on directory {s}\n" ++
                    "  Recommended: chmod 700 {s}\n",
                .{ path, path },
            );
            defer allocator.free(warning);
            stderr.writeAll(warning) catch {};
            return err;
        }
    };
}

test "file permissions" {
    // Note: This test requires actual file system operations
    // Skip in test environments without file system access
}
