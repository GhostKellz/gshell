/// Color themes for GShell syntax highlighting
/// Provides ANSI escape codes for highlighting different syntax elements
const std = @import("std");

/// ANSI color codes
pub const ansi = struct {
    pub const reset = "\x1b[0m";
    pub const bold = "\x1b[1m";

    // Basic colors
    pub const black = "\x1b[30m";
    pub const red = "\x1b[31m";
    pub const green = "\x1b[32m";
    pub const yellow = "\x1b[33m";
    pub const blue = "\x1b[34m";
    pub const magenta = "\x1b[35m";
    pub const cyan = "\x1b[36m";
    pub const white = "\x1b[37m";

    // Bright colors
    pub const bright_black = "\x1b[90m";
    pub const bright_red = "\x1b[91m";
    pub const bright_green = "\x1b[92m";
    pub const bright_yellow = "\x1b[93m";
    pub const bright_blue = "\x1b[94m";
    pub const bright_magenta = "\x1b[95m";
    pub const bright_cyan = "\x1b[96m";
    pub const bright_white = "\x1b[97m";

    // 256-color support
    pub const orange = "\x1b[38;5;208m";
    pub const teal = "\x1b[38;5;6m";
    pub const aquamarine = "\x1b[38;5;122m";
    pub const mint = "\x1b[38;5;121m";
    pub const gray = "\x1b[38;5;240m";
};

/// Theme defines color mappings for syntax elements
pub const Theme = struct {
    command: []const u8,          // Regular commands
    builtin: []const u8,          // Shell builtins
    builtin_network: []const u8,  // Network commands (net-*)
    builtin_gshell: []const u8,   // GShell FFI functions
    flag: []const u8,             // Command flags (-x, --flag)
    string: []const u8,           // String literals
    escape: []const u8,           // Escape sequences
    variable: []const u8,         // Variables ($VAR)
    operator: []const u8,         // Operators (&&, ||)
    operator_pipe: []const u8,    // Pipe operator (|)
    comment: []const u8,          // Comments
    error_node: []const u8,       // Syntax errors
    punctuation: []const u8,      // Punctuation (;, =)
    reset: []const u8,            // Reset to default

    /// Get color code for a tree-sitter capture name
    pub fn colorForCapture(self: *const Theme, capture: []const u8) []const u8 {
        if (std.mem.eql(u8, capture, "function")) return self.command;
        if (std.mem.eql(u8, capture, "function.builtin")) return self.builtin;
        if (std.mem.eql(u8, capture, "function.builtin.network")) return self.builtin_network;
        if (std.mem.eql(u8, capture, "function.builtin.gshell")) return self.builtin_gshell;
        if (std.mem.eql(u8, capture, "parameter")) return self.flag;
        if (std.mem.eql(u8, capture, "string")) return self.string;
        if (std.mem.eql(u8, capture, "string.escape")) return self.escape;
        if (std.mem.eql(u8, capture, "variable")) return self.variable;
        if (std.mem.eql(u8, capture, "operator")) return self.operator;
        if (std.mem.eql(u8, capture, "operator.pipe")) return self.operator_pipe;
        if (std.mem.eql(u8, capture, "comment")) return self.comment;
        if (std.mem.eql(u8, capture, "error")) return self.error_node;
        if (std.mem.eql(u8, capture, "punctuation.delimiter")) return self.punctuation;
        if (std.mem.eql(u8, capture, "punctuation.special")) return self.variable;

        // Default
        return self.reset;
    }
};

/// Ghost Hacker Blue theme - GShell's signature theme
/// Cyan/teal/aquamarine aesthetic matching the GShell logo
pub const ghost_hacker_blue = Theme{
    .command = ansi.bright_green,        // Commands: bright green
    .builtin = ansi.aquamarine,          // Builtins: aquamarine (cyan-green)
    .builtin_network = ansi.teal,        // Network cmds: teal
    .builtin_gshell = ansi.mint,         // GShell FFI: mint green
    .flag = ansi.bright_yellow,          // Flags: bright yellow
    .string = ansi.bright_magenta,       // Strings: bright magenta
    .escape = ansi.orange,               // Escapes: orange
    .variable = ansi.bright_blue,        // Variables: bright blue
    .operator = ansi.orange,             // Operators: orange
    .operator_pipe = ansi.cyan,          // Pipes: cyan
    .comment = ansi.gray,                // Comments: gray
    .error_node = ansi.bright_red,       // Errors: bright red
    .punctuation = ansi.white,           // Punctuation: white
    .reset = ansi.reset,
};

/// Mint Fresh theme - Refreshing green aesthetic
pub const mint_fresh = Theme{
    .command = ansi.bright_green,
    .builtin = ansi.mint,
    .builtin_network = ansi.cyan,
    .builtin_gshell = ansi.aquamarine,
    .flag = ansi.yellow,
    .string = ansi.green,
    .escape = ansi.bright_yellow,
    .variable = ansi.bright_cyan,
    .operator = ansi.yellow,
    .operator_pipe = ansi.cyan,
    .comment = ansi.gray,
    .error_node = ansi.bright_red,
    .punctuation = ansi.white,
    .reset = ansi.reset,
};

/// Dracula theme - Popular dark theme
pub const dracula = Theme{
    .command = ansi.bright_cyan,
    .builtin = ansi.bright_magenta,
    .builtin_network = ansi.cyan,
    .builtin_gshell = ansi.magenta,
    .flag = ansi.bright_yellow,
    .string = ansi.yellow,
    .escape = ansi.orange,
    .variable = ansi.bright_green,
    .operator = ansi.magenta,
    .operator_pipe = ansi.cyan,
    .comment = ansi.gray,
    .error_node = ansi.bright_red,
    .punctuation = ansi.white,
    .reset = ansi.reset,
};

/// Classic theme - Traditional shell colors
pub const classic = Theme{
    .command = ansi.green,
    .builtin = ansi.cyan,
    .builtin_network = ansi.cyan,
    .builtin_gshell = ansi.cyan,
    .flag = ansi.yellow,
    .string = ansi.magenta,
    .escape = ansi.magenta,
    .variable = ansi.blue,
    .operator = ansi.red,
    .operator_pipe = ansi.red,
    .comment = ansi.bright_black,
    .error_node = ansi.red,
    .punctuation = ansi.white,
    .reset = ansi.reset,
};

/// Get theme by name
pub fn getTheme(name: []const u8) Theme {
    if (std.mem.eql(u8, name, "ghost-hacker-blue")) return ghost_hacker_blue;
    if (std.mem.eql(u8, name, "mint-fresh")) return mint_fresh;
    if (std.mem.eql(u8, name, "dracula")) return dracula;
    if (std.mem.eql(u8, name, "classic")) return classic;

    // Default to ghost hacker blue
    return ghost_hacker_blue;
}

test "theme color lookup" {
    const theme = ghost_hacker_blue;
    try std.testing.expectEqualStrings(ansi.bright_green, theme.colorForCapture("function"));
    try std.testing.expectEqualStrings(ansi.aquamarine, theme.colorForCapture("function.builtin"));
    try std.testing.expectEqualStrings(ansi.bright_yellow, theme.colorForCapture("parameter"));
    try std.testing.expectEqualStrings(ansi.bright_red, theme.colorForCapture("error"));
}

test "theme selection" {
    const theme1 = getTheme("ghost-hacker-blue");
    try std.testing.expectEqualStrings(ansi.bright_green, theme1.command);

    const theme2 = getTheme("dracula");
    try std.testing.expectEqualStrings(ansi.bright_cyan, theme2.command);

    const theme3 = getTheme("unknown");
    try std.testing.expectEqualStrings(ansi.bright_green, theme3.command); // Falls back to ghost-hacker-blue
}
