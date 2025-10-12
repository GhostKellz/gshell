const std = @import("std");

/// Theme manager for vivid LS_COLORS themes
pub const ThemeManager = struct {
    allocator: std.mem.Allocator,
    assets_dir: []const u8,

    pub fn init(allocator: std.mem.Allocator, assets_dir: []const u8) ThemeManager {
        return .{
            .allocator = allocator,
            .assets_dir = assets_dir,
        };
    }

    pub fn deinit(self: *ThemeManager) void {
        _ = self;
    }

    /// Load a vivid theme by name and return LS_COLORS string
    /// Caller owns returned memory
    pub fn loadVividTheme(self: *ThemeManager, theme_name: []const u8) ![]const u8 {
        // Check if vivid is available
        if (!self.isCommandAvailable("vivid")) {
            return error.VividNotFound;
        }

        // Build path to theme file
        const theme_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/vivid/{s}.yml",
            .{ self.assets_dir, theme_name },
        );
        defer self.allocator.free(theme_path);

        // Check if theme file exists
        std.fs.accessAbsolute(theme_path, .{}) catch {
            return error.ThemeNotFound;
        };

        // Execute vivid generate
        const result = try self.executeCommand(&[_][]const u8{
            "vivid",
            "generate",
            theme_path,
        });

        return result;
    }

    /// Check if a command is available in PATH
    fn isCommandAvailable(self: *ThemeManager, command: []const u8) bool {
        _ = self;
        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "which", command },
        }) catch return false;
        defer self.allocator.free(result.stdout);
        defer self.allocator.free(result.stderr);

        return result.term.Exited == 0;
    }

    /// Execute a command and return stdout
    fn executeCommand(self: *ThemeManager, argv: []const []const u8) ![]const u8 {
        const result = try std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = argv,
        });
        defer self.allocator.free(result.stderr);

        if (result.term.Exited != 0) {
            self.allocator.free(result.stdout);
            return error.CommandFailed;
        }

        // Trim trailing newline
        var stdout = result.stdout;
        if (stdout.len > 0 and stdout[stdout.len - 1] == '\n') {
            stdout = stdout[0 .. stdout.len - 1];
        }

        return stdout;
    }

    /// List available vivid themes
    pub fn listThemes(self: *ThemeManager) ![]const []const u8 {
        const vivid_dir = try std.fmt.allocPrint(
            self.allocator,
            "{s}/vivid",
            .{self.assets_dir},
        );
        defer self.allocator.free(vivid_dir);

        var dir = try std.fs.openDirAbsolute(vivid_dir, .{ .iterate = true });
        defer dir.close();

        var themes = std.ArrayList([]const u8).init(self.allocator);
        errdefer {
            for (themes.items) |theme| {
                self.allocator.free(theme);
            }
            themes.deinit();
        }

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".yml")) continue;

            // Remove .yml extension
            const name = entry.name[0 .. entry.name.len - 4];
            const owned = try self.allocator.dupe(u8, name);
            try themes.append(owned);
        }

        return themes.toOwnedSlice();
    }
};

/// Built-in theme names
pub const BuiltInThemes = struct {
    pub const ghost_hacker_blue = "ghost-hacker-blue";
    pub const tokyonight_night = "tokyonight-night";
    pub const tokyonight_moon = "tokyonight-moon";
    pub const dracula = "dracula";
};

test "ThemeManager init" {
    const allocator = std.testing.allocator;
    var manager = ThemeManager.init(allocator, "/tmp");
    defer manager.deinit();
}
