const std = @import("std");
const wizard = @import("wizard.zig");

pub const SetupError = error{
    HomeDirNotFound,
    DirectoryCreationFailed,
    TemplateCopyFailed,
};

pub fn isFirstRun(allocator: std.mem.Allocator) !bool {
    const home = std.posix.getenv("HOME") orelse return SetupError.HomeDirNotFound;

    // Check if .gshrc.gza exists (primary indicator)
    const gshrc_path = try std.fmt.allocPrint(allocator, "{s}/.gshrc.gza", .{home});
    defer allocator.free(gshrc_path);

    std.fs.cwd().access(gshrc_path, .{}) catch {
        return true; // .gshrc.gza doesn't exist, first run
    };

    return false;
}

pub fn runFirstTimeSetup(allocator: std.mem.Allocator) !void {
    // Run interactive wizard
    const config = try wizard.runInteractiveWizard(allocator);

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

    // Create directories with secure permissions
    try createDirIfNotExists(config_dir);
    try createDirIfNotExists(plugins_dir);
    try createDirIfNotExists(rc_d_dir);
    try createDirIfNotExists(prompts_dir);

    // Apply wizard configuration (creates .gshrc.gza and starship config)
    try wizard.applyConfiguration(allocator, config);

    // Print completion message
    const stdout = std.fs.File.stdout();
    try wizard.printCompletionMessage(stdout);
}

fn createDirIfNotExists(path: []const u8) !void {
    std.fs.cwd().makePath(path) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };
}
