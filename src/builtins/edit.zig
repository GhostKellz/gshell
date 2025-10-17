/// Edit builtin - Quick file editing with Grim
/// Commands: e <file>, e -, fc <N>
const std = @import("std");
const ShellState = @import("../state.zig").ShellState;

pub const EditError = error{
    NoEditor,
    EditorFailed,
    NoHistory,
    InvalidHistoryIndex,
};

/// Execute edit command
/// Usage:
///   e <file>     - Open file in editor
///   e -          - Edit last command from history
///   fc <N>       - Edit command N from history
pub fn execute(
    allocator: std.mem.Allocator,
    state: *ShellState,
    args: []const []const u8,
    history: ?*const std.ArrayListUnmanaged([]const u8),
) !void {
    // Determine editor (prefer grim, fallback to $EDITOR, then vi)
    const editor: []const u8 = blk: {
        // Check if grim is available
        const grim_check = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "which", "grim" },
        }) catch break :blk "vi";
        defer {
            allocator.free(grim_check.stdout);
            allocator.free(grim_check.stderr);
        }

        if (grim_check.term == .Exited and grim_check.term.Exited == 0) {
            break :blk "grim";
        }

        // Fallback to $EDITOR
        if (state.getEnv("EDITOR")) |ed| {
            break :blk ed;
        }

        break :blk "vi";
    };

    if (args.len == 0) {
        std.debug.print("Usage: e <file> | e - | fc <N>\n", .{});
        return;
    }

    const first_arg = args[0];

    // Handle 'e -' (edit last command)
    if (std.mem.eql(u8, first_arg, "-")) {
        if (history == null or history.?.items.len == 0) {
            return EditError.NoHistory;
        }
        const last_cmd = history.?.items[history.?.items.len - 1];
        try editCommand(allocator, editor, last_cmd);
        return;
    }

    // Handle 'fc N' style (edit command N from history)
    if (args.len >= 1) {
        const maybe_num = std.fmt.parseInt(usize, first_arg, 10) catch null;
        if (maybe_num) |num| {
            if (history == null) return EditError.NoHistory;
            if (num == 0 or num > history.?.items.len) {
                return EditError.InvalidHistoryIndex;
            }
            const cmd = history.?.items[num - 1];
            try editCommand(allocator, editor, cmd);
            return;
        }
    }

    // Regular file edit
    try editFile(allocator, editor, first_arg);
}

/// Edit a file in the editor
fn editFile(allocator: std.mem.Allocator, editor: []const u8, file_path: []const u8) !void {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ editor, file_path },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.term != .Exited or result.term.Exited != 0) {
        return EditError.EditorFailed;
    }
}

/// Edit a command in a temp file, then execute it
fn editCommand(allocator: std.mem.Allocator, editor: []const u8, command: []const u8) !void {
    // Create temp file
    const temp_path = "/tmp/gsh_edit.sh";

    // Write command to temp file
    {
        const file = try std.fs.cwd().createFile(temp_path, .{});
        defer file.close();
        try file.writeAll(command);
    }

    // Open in editor
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ editor, temp_path },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.term != .Exited or result.term.Exited != 0) {
        return EditError.EditorFailed;
    }

    // Read edited command
    const edited_content = try std.fs.cwd().readFileAlloc(temp_path, allocator, @enumFromInt(1024 * 1024));
    defer allocator.free(edited_content);

    // Print the edited command for user review and manual execution
    // Note: We intentionally don't auto-execute for safety - user can review
    // and press Up arrow to recall it, or copy-paste to execute
    std.debug.print("\n\x1b[1;32mEdited command:\x1b[0m\n{s}\n", .{edited_content});
    if (!std.mem.endsWith(u8, edited_content, "\n")) {
        std.debug.print("\n", .{});
    }
    std.debug.print("\x1b[2m(Copy and paste to execute, or press Up arrow)\x1b[0m\n", .{});
}
