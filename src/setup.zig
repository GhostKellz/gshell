const std = @import("std");

pub const SetupError = error{
    HomeDirNotFound,
    DirectoryCreationFailed,
    TemplateCopyFailed,
};

pub fn isFirstRun(allocator: std.mem.Allocator) !bool {
    const home = std.posix.getenv("HOME") orelse return SetupError.HomeDirNotFound;
    const config_path = try std.fmt.allocPrint(allocator, "{s}/.config/gshell", .{home});
    defer allocator.free(config_path);

    // Check if config directory exists
    std.fs.cwd().access(config_path, .{}) catch {
        return true; // Directory doesn't exist, first run
    };

    return false;
}

pub fn runFirstTimeSetup(allocator: std.mem.Allocator) !void {
    const home = std.posix.getenv("HOME") orelse return SetupError.HomeDirNotFound;

    // Create directory structure
    const config_dir = try std.fmt.allocPrint(allocator, "{s}/.config/gshell", .{home});
    defer allocator.free(config_dir);

    const plugins_dir = try std.fmt.allocPrint(allocator, "{s}/.config/gshell/plugins", .{home});
    defer allocator.free(plugins_dir);

    const rc_d_dir = try std.fmt.allocPrint(allocator, "{s}/.config/gshell/rc.d", .{home});
    defer allocator.free(rc_d_dir);

    const prompts_dir = try std.fmt.allocPrint(allocator, "{s}/.config/gshell/prompts", .{home});
    defer allocator.free(prompts_dir);

    // Create directories
    try createDirIfNotExists(config_dir);
    try createDirIfNotExists(plugins_dir);
    try createDirIfNotExists(rc_d_dir);
    try createDirIfNotExists(prompts_dir);

    // Copy default .gshrc if it doesn't exist
    const gshrc_path = try std.fmt.allocPrint(allocator, "{s}/.gshrc", .{home});
    defer allocator.free(gshrc_path);

    std.fs.cwd().access(gshrc_path, .{}) catch {
        // .gshrc doesn't exist, copy template
        try copyTemplate(allocator, "assets/templates/gshrc-ghostkellz", gshrc_path);
    };

    // Copy Starship config if it doesn't exist
    const starship_config_dir = try std.fmt.allocPrint(allocator, "{s}/.config", .{home});
    defer allocator.free(starship_config_dir);
    try createDirIfNotExists(starship_config_dir);

    const starship_path = try std.fmt.allocPrint(allocator, "{s}/.config/starship.toml", .{home});
    defer allocator.free(starship_path);

    std.fs.cwd().access(starship_path, .{}) catch {
        // starship.toml doesn't exist, copy template
        try copyTemplate(allocator, "assets/templates/starship-ghostkellz.toml", starship_path);
    };

    // Print welcome message
    printWelcomeMessage();
}

fn createDirIfNotExists(path: []const u8) !void {
    std.fs.cwd().makePath(path) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };
}

fn copyTemplate(allocator: std.mem.Allocator, src_path: []const u8, dest_path: []const u8) !void {
    // Read source file
    const src_file = std.fs.cwd().openFile(src_path, .{}) catch |err| {
        std.debug.print("Warning: Could not open template {s}: {s}\n", .{ src_path, @errorName(err) });
        return;
    };
    defer src_file.close();

    const stat = src_file.stat() catch |err| {
        std.debug.print("Warning: Could not stat template {s}: {s}\n", .{ src_path, @errorName(err) });
        return;
    };

    const content = allocator.alloc(u8, stat.size) catch |err| {
        std.debug.print("Warning: Could not allocate for template {s}: {s}\n", .{ src_path, @errorName(err) });
        return;
    };
    defer allocator.free(content);

    _ = src_file.readAll(content) catch |err| {
        std.debug.print("Warning: Could not read template {s}: {s}\n", .{ src_path, @errorName(err) });
        return;
    };

    // Write to destination
    const dest_file = std.fs.cwd().createFile(dest_path, .{}) catch |err| {
        std.debug.print("Warning: Could not create {s}: {s}\n", .{ dest_path, @errorName(err) });
        return;
    };
    defer dest_file.close();

    try dest_file.writeAll(content);
}

fn printWelcomeMessage() void {
    const welcome =
        \\
        \\🎨 Welcome to GShell!
        \\
        \\✓ Created ~/.config/gshell/
        \\✓ Created ~/.gshrc (configuration file)
        \\✓ Created ~/.config/starship.toml (prompt config)
        \\
        \\GShell is ready to use! Here's what's available:
        \\
        \\  📦 Plugins: git, network, dev-tools, docker, kubectl, system
        \\     Enable in ~/.gshrc with: enable_plugin("git")
        \\
        \\  🎨 Themes: ghost-hacker-blue (default), dracula, tokyonight-*
        \\     Load in ~/.gshrc with: load_vivid_theme("ghost-hacker-blue")
        \\
        \\  🚀 Prompt: Starship (configured) or GPrompt (coming soon)
        \\     Configured in ~/.config/starship.toml
        \\
        \\  🔧 Networking: net-test, net-resolve, net-fetch, net-scan
        \\
        \\  📝 History: Saved to ~/.gshell_history
        \\
        \\Quick start:
        \\  - Edit ~/.gshrc to customize your shell
        \\  - Run 'enable_plugin("git")' for git shortcuts
        \\  - Run 'load_vivid_theme("dracula")' to change colors
        \\
        \\Type 'help' or visit https://github.com/ghostkellz/gshell for docs
        \\
        \\
    ;
    std.debug.print("{s}", .{welcome});
}

pub fn printFirstRunReminder() void {
    const reminder =
        \\
        \\💡 Tip: Edit ~/.gshrc to customize GShell
        \\   Enable plugins: enable_plugin("git", "docker", "network")
        \\   Change theme: load_vivid_theme("ghost-hacker-blue")
        \\
        \\
    ;
    std.debug.print("{s}", .{reminder});
}
