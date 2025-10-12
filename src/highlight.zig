/// Syntax highlighting for GShell using Grove
/// Provides real-time syntax highlighting as users type
const std = @import("std");
const grove = @import("grove");
const themes = @import("themes.zig");

/// Colored segment of text
pub const ColoredSegment = struct {
    text: []const u8,
    color: []const u8,
    start: usize,
    end: usize,
};

/// GShell syntax highlighter
/// Wraps Grove's RealtimeHighlighter with gshell-specific theming
pub const Highlighter = struct {
    allocator: std.mem.Allocator,
    language: grove.Language,
    highlight_query: []const u8,
    theme: themes.Theme,
    parser: grove.Parser,

    /// Initialize the highlighter
    pub fn init(allocator: std.mem.Allocator, theme_name: []const u8) !Highlighter {
        // Get gshell language from grove
        const language = try grove.Languages.gshell.get();

        // GShell highlight query (embedded as string constant)
        // This matches the query in grove's gshell grammar
        const highlight_query =
            \\; Tree-sitter highlighting queries for GShell
            \\(builtin_command) @function.builtin
            \\(command_name (word) @function)
            \\(flag) @parameter
            \\(string) @string
            \\(raw_string) @string
            \\(string_content) @string
            \\(raw_string_content) @string
            \\(escape_sequence) @string.escape
            \\(expansion "$" @punctuation.special (variable_name) @variable)
            \\(expansion "${" @punctuation.special (variable_name) @variable "}" @punctuation.special)
            \\(variable_assignment name: (variable_name) @variable)
            \\(command_substitution ["$(" ")" "`"] @punctuation.special)
            \\(pipeline operator: ["&&" "||"] @operator)
            \\(pipeline operator: "|" @operator.pipe)
            \\(redirection operator: [">" ">>" "<" "2>" "2>>" "&>" "&>>"] @operator)
            \\(comment) @comment
            \\["=" ";"] @punctuation.delimiter
            \\(ERROR) @error
        ;

        // Initialize parser
        var parser = try grove.Parser.init(allocator);
        errdefer parser.deinit();
        try parser.setLanguage(language);

        return Highlighter{
            .allocator = allocator,
            .language = language,
            .highlight_query = highlight_query,
            .theme = themes.getTheme(theme_name),
            .parser = parser,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *Highlighter) void {
        self.parser.deinit();
    }

    /// Highlight a single line of input
    /// Returns colored segments that can be rendered to the terminal
    pub fn highlightLine(self: *Highlighter, line: []const u8) ![]ColoredSegment {
        // Parse the line
        var tree = try self.parser.parseUtf8(null, line);
        defer tree.deinit();

        const root = tree.rootNode() orelse return error.EmptyTree;

        // Execute highlight query
        var query = try grove.Query.init(self.allocator, self.language, self.highlight_query);
        defer query.deinit();

        var cursor = try grove.QueryCursor.init();
        defer cursor.deinit();

        cursor.exec(&query, root);

        // Collect highlighted segments
        var segments = std.ArrayList(ColoredSegment){};
        errdefer segments.deinit(self.allocator);

        var last_end: usize = 0;

        while (cursor.nextCapture(&query)) |capture_result| {
            const capture_name = capture_result.capture.name;
            const node = capture_result.capture.node;
            const start = node.startByte();
            const end = node.endByte();

            // Add unhighlighted text before this capture
            if (start > last_end) {
                try segments.append(self.allocator, .{
                    .text = line[last_end..start],
                    .color = themes.ansi.reset,
                    .start = last_end,
                    .end = start,
                });
            }

            // Add highlighted segment
            const color = self.theme.colorForCapture(capture_name);
            try segments.append(self.allocator, .{
                .text = line[start..end],
                .color = color,
                .start = start,
                .end = end,
            });

            last_end = end;
        }

        // Add remaining unhighlighted text
        if (last_end < line.len) {
            try segments.append(self.allocator, .{
                .text = line[last_end..],
                .color = themes.ansi.reset,
                .start = last_end,
                .end = line.len,
            });
        }

        return try segments.toOwnedSlice(self.allocator);
    }

    /// Render colored segments to a string with ANSI codes
    pub fn render(allocator: std.mem.Allocator, segments: []const ColoredSegment) ![]u8 {
        var result = std.ArrayList(u8){};
        errdefer result.deinit(allocator);

        for (segments) |segment| {
            try result.appendSlice(allocator, segment.color);
            try result.appendSlice(allocator, segment.text);
        }

        // Always reset at the end
        try result.appendSlice(allocator, themes.ansi.reset);

        return try result.toOwnedSlice(allocator);
    }

    /// Convenience function: highlight and render in one step
    pub fn highlightAndRender(self: *Highlighter, line: []const u8) ![]u8 {
        const segments = try self.highlightLine(line);
        defer self.allocator.free(segments);
        return try render(self.allocator, segments);
    }
};

test "highlighter basic functionality" {
    var highlighter = try Highlighter.init(std.testing.allocator, "ghost-hacker-blue");
    defer highlighter.deinit();

    const line = "ls -la";
    const segments = try highlighter.highlightLine(line);
    defer std.testing.allocator.free(segments);

    // Should have at least 2 segments: command + flag
    try std.testing.expect(segments.len >= 2);
}

test "highlighter with pipes" {
    var highlighter = try Highlighter.init(std.testing.allocator, "ghost-hacker-blue");
    defer highlighter.deinit();

    const line = "ls -la | grep test";
    const segments = try highlighter.highlightLine(line);
    defer std.testing.allocator.free(segments);

    // Should highlight: ls, -la, |, grep, test
    try std.testing.expect(segments.len > 0);
}

test "highlighter render" {
    var highlighter = try Highlighter.init(std.testing.allocator, "ghost-hacker-blue");
    defer highlighter.deinit();

    const line = "echo hello";
    const rendered = try highlighter.highlightAndRender(line);
    defer std.testing.allocator.free(rendered);

    // Should contain ANSI codes
    try std.testing.expect(rendered.len > line.len);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "\x1b[") != null);
}
