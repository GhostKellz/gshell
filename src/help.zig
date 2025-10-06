const std = @import("std");

/// Help topics for built-in commands and concepts
pub const HelpTopic = struct {
    name: []const u8,
    usage: []const u8,
    description: []const u8,
    examples: []const Example,
    see_also: []const []const u8 = &[_][]const u8{},
};

pub const Example = struct {
    command: []const u8,
    description: []const u8,
};

/// All available help topics
pub const topics = [_]HelpTopic{
    // Core builtins
    .{
        .name = "cd",
        .usage = "cd [directory]",
        .description = "Change the current working directory.\nIf no directory is specified, changes to $HOME.",
        .examples = &[_]Example{
            .{ .command = "cd /tmp", .description = "Change to /tmp directory" },
            .{ .command = "cd ..", .description = "Go up one directory" },
            .{ .command = "cd", .description = "Change to home directory" },
            .{ .command = "cd ~/projects", .description = "Change to ~/projects" },
        },
        .see_also = &[_][]const u8{ "pwd", "pushd", "popd" },
    },
    .{
        .name = "pwd",
        .usage = "pwd",
        .description = "Print the current working directory path.",
        .examples = &[_]Example{
            .{ .command = "pwd", .description = "Show current directory" },
        },
        .see_also = &[_][]const u8{"cd"},
    },
    .{
        .name = "echo",
        .usage = "echo [text...]",
        .description = "Print arguments to standard output.",
        .examples = &[_]Example{
            .{ .command = "echo hello world", .description = "Print 'hello world'" },
            .{ .command = "echo $USER", .description = "Print value of USER variable" },
        },
        .see_also = &[_][]const u8{"print"},
    },
    .{
        .name = "exit",
        .usage = "exit [status]",
        .description = "Exit the shell with optional status code.\nDefault status is 0 (success).",
        .examples = &[_]Example{
            .{ .command = "exit", .description = "Exit with status 0" },
            .{ .command = "exit 1", .description = "Exit with status 1 (error)" },
        },
        .see_also = &[_][]const u8{"logout"},
    },
    .{
        .name = "alias",
        .usage = "alias name='command'",
        .description = "Create a command alias.\nWithout arguments, lists all aliases.",
        .examples = &[_]Example{
            .{ .command = "alias ll='ls -la'", .description = "Create 'll' alias" },
            .{ .command = "alias gs='git status'", .description = "Create 'gs' alias" },
            .{ .command = "alias", .description = "List all aliases" },
        },
        .see_also = &[_][]const u8{"unalias"},
    },
    .{
        .name = "unalias",
        .usage = "unalias name",
        .description = "Remove a command alias.",
        .examples = &[_]Example{
            .{ .command = "unalias ll", .description = "Remove 'll' alias" },
        },
        .see_also = &[_][]const u8{"alias"},
    },
    .{
        .name = "jobs",
        .usage = "jobs",
        .description = "List all background jobs with their status.",
        .examples = &[_]Example{
            .{ .command = "jobs", .description = "Show all jobs" },
        },
        .see_also = &[_][]const u8{ "fg", "bg" },
    },
    .{
        .name = "fg",
        .usage = "fg [job_id]",
        .description = "Bring a background job to foreground.\nIf no job_id specified, uses most recent job.",
        .examples = &[_]Example{
            .{ .command = "fg", .description = "Resume most recent job" },
            .{ .command = "fg 1", .description = "Resume job #1" },
        },
        .see_also = &[_][]const u8{ "bg", "jobs" },
    },
    .{
        .name = "bg",
        .usage = "bg [job_id]",
        .description = "Resume a stopped job in the background.\nIf no job_id specified, uses most recent stopped job.",
        .examples = &[_]Example{
            .{ .command = "bg", .description = "Resume most recent stopped job" },
            .{ .command = "bg 2", .description = "Resume job #2 in background" },
        },
        .see_also = &[_][]const u8{ "fg", "jobs" },
    },

    // Networking utilities
    .{
        .name = "net-test",
        .usage = "net-test <host> <port>",
        .description = "Test TCP connectivity to a host and port.\nReturns 0 if connection succeeds, non-zero otherwise.",
        .examples = &[_]Example{
            .{ .command = "net-test google.com 443", .description = "Test HTTPS connectivity" },
            .{ .command = "net-test localhost 8080", .description = "Test local web server" },
            .{ .command = "net-test 192.168.1.1 22", .description = "Test SSH connectivity" },
        },
        .see_also = &[_][]const u8{ "net-scan", "net-resolve" },
    },
    .{
        .name = "net-resolve",
        .usage = "net-resolve <hostname>",
        .description = "Resolve a hostname to IP address(es) using DNS.",
        .examples = &[_]Example{
            .{ .command = "net-resolve google.com", .description = "Resolve google.com" },
            .{ .command = "net-resolve localhost", .description = "Resolve localhost" },
        },
        .see_also = &[_][]const u8{ "net-test", "net-fetch" },
    },
    .{
        .name = "net-fetch",
        .usage = "net-fetch <url>",
        .description = "Fetch content from a URL via HTTP/HTTPS.\nSupports GET requests.",
        .examples = &[_]Example{
            .{ .command = "net-fetch https://example.com", .description = "Fetch webpage" },
            .{ .command = "net-fetch http://api.example.com/data", .description = "Fetch API data" },
        },
        .see_also = &[_][]const u8{ "net-test", "curl" },
    },
    .{
        .name = "net-scan",
        .usage = "net-scan <cidr>",
        .description = "Scan a network range for active hosts.\nUses CIDR notation (e.g., 192.168.1.0/24).",
        .examples = &[_]Example{
            .{ .command = "net-scan 192.168.1.0/24", .description = "Scan local network" },
            .{ .command = "net-scan 10.0.0.0/16", .description = "Scan larger network" },
        },
        .see_also = &[_][]const u8{ "net-test", "nmap" },
    },
};

/// Find help topic by name
pub fn findTopic(name: []const u8) ?*const HelpTopic {
    for (&topics) |*topic| {
        if (std.mem.eql(u8, topic.name, name)) {
            return topic;
        }
    }
    return null;
}

/// Print help for a topic
pub fn printHelp(allocator: std.mem.Allocator, file: std.fs.File, topic: *const HelpTopic) !void {
    // Header
    const header = try std.fmt.allocPrint(allocator, "\x1b[1;36m{s}\x1b[0m - {s}\n\n", .{ topic.name, topic.usage });
    defer allocator.free(header);
    try file.writeAll(header);

    // Description
    try file.writeAll("\x1b[1mDESCRIPTION\x1b[0m\n");
    const desc = try std.fmt.allocPrint(allocator, "  {s}\n\n", .{topic.description});
    defer allocator.free(desc);
    try file.writeAll(desc);

    // Examples
    if (topic.examples.len > 0) {
        try file.writeAll("\x1b[1mEXAMPLES\x1b[0m\n");
        for (topic.examples) |example| {
            const ex_desc = try std.fmt.allocPrint(allocator, "  \x1b[2m# {s}\x1b[0m\n", .{example.description});
            defer allocator.free(ex_desc);
            try file.writeAll(ex_desc);

            const ex_cmd = try std.fmt.allocPrint(allocator, "  \x1b[32m{s}\x1b[0m\n\n", .{example.command});
            defer allocator.free(ex_cmd);
            try file.writeAll(ex_cmd);
        }
    }

    // See also
    if (topic.see_also.len > 0) {
        try file.writeAll("\x1b[1mSEE ALSO\x1b[0m\n  ");
        for (topic.see_also, 0..) |related, i| {
            if (i > 0) try file.writeAll(", ");
            try file.writeAll(related);
        }
        try file.writeAll("\n");
    }
}

/// Print overview of all topics
pub fn printOverview(allocator: std.mem.Allocator, file: std.fs.File) !void {
    try file.writeAll("\x1b[1;36mgshell help\x1b[0m - Built-in shell help system\n\n");
    try file.writeAll("\x1b[1mUSAGE\x1b[0m\n");
    try file.writeAll("  help [topic]       Show help for a specific topic\n");
    try file.writeAll("  help               Show this overview\n\n");

    try file.writeAll("\x1b[1mCORE BUILTINS\x1b[0m\n");
    const builtins_list = [_][]const u8{ "cd", "pwd", "echo", "exit", "alias", "unalias", "jobs", "fg", "bg", "help" };
    for (builtins_list) |name| {
        if (findTopic(name)) |topic| {
            const line = try std.fmt.allocPrint(allocator, "  \x1b[32m{s:<15}\x1b[0m {s}\n", .{ name, topic.usage });
            defer allocator.free(line);
            try file.writeAll(line);
        }
    }

    try file.writeAll("\n\x1b[1mNETWORKING\x1b[0m\n");
    const net_list = [_][]const u8{ "net-test", "net-resolve", "net-fetch", "net-scan" };
    for (net_list) |name| {
        if (findTopic(name)) |topic| {
            const line = try std.fmt.allocPrint(allocator, "  \x1b[32m{s:<15}\x1b[0m {s}\n", .{ name, topic.usage });
            defer allocator.free(line);
            try file.writeAll(line);
        }
    }

    try file.writeAll("\n\x1b[2mFor more info: help <topic>\x1b[0m\n");
}
