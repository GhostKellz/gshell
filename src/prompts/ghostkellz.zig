const std = @import("std");
const zfont = @import("zfont");
const VersionDetector = @import("../version_detect.zig").VersionDetector;

/// GhostKellz P10k-style prompt theme
/// Based on .p10k.zsh config with ghost-hacker-blue color scheme
pub const GhostKellzPrompt = struct {
    allocator: std.mem.Allocator,
    p10k: zfont.PowerLevel10k,
    version_detector: *VersionDetector,

    const Self = @This();

    /// Color scheme from ghost-hacker-blue.yml (256-color ANSI codes)
    pub const Colors = struct {
        // Ghost Hacker Blue palette
        pub const minty: u8 = 122;          // #7FFFD4 - aquamarine
        pub const mint: u8 = 121;           // #98ff98
        pub const teal: u8 = 80;            // #4fd6be
        pub const blue6: u8 = 111;          // #82aaff
        pub const blue_moon: u8 = 189;      // #c0caf5
        pub const green1: u8 = 150;         // #c3e88d
        pub const yellow: u8 = 221;         // #ffc777
        pub const red1: u8 = 167;           // #c53b53
        pub const gray3: u8 = 60;           // #636da6
        pub const bg: u8 = 235;             // #222436

        // Your .p10k.zsh segment colors
        pub const os_icon_fg: u8 = 18;      // From line 37
        pub const os_icon_bg: u8 = 33;      // From line 38
        pub const user_fg: u8 = 122;        // From line 46 (mint)
        pub const user_bg: u8 = 17;         // From line 45
        pub const dir_fg: u8 = 122;
        pub const dir_bg: u8 = 68;
        pub const vcs_fg: u8 = 150;
        pub const vcs_bg: u8 = 64;
        pub const status_ok_fg: u8 = 46;    // Green
        pub const status_err_fg: u8 = 196;  // Red
    };

    /// Segment configuration matching your .p10k.zsh layout
    pub const Layout = struct {
        pub const left_segments = [_][]const u8{
            "os_icon",    // Arch logo
            "dir",        // Current directory
            "vcs",        // Git branch + status
        };

        pub const right_segments = [_][]const u8{
            "status",
            "command_execution_time",
            "node_version",
            "go_version",
            "rust_version",
            "user",
            "time",
        };

        pub const use_two_line = true;
        pub const newline_char = "\n";
        pub const multiline_prefix_first = "╭─";
        pub const multiline_prefix_last = "╰─ ";
        pub const prompt_char = "❯";
    };

    pub fn init(allocator: std.mem.Allocator, version_detector: *VersionDetector) !Self {
        // Initialize zfont's PowerLevel10k with a programming font manager
        var prog_manager = zfont.ProgrammingFonts.ProgrammingFontManager.init(allocator);
        const p10k = zfont.PowerLevel10k.init(allocator, &prog_manager);

        return Self{
            .allocator = allocator,
            .p10k = p10k,
            .version_detector = version_detector,
        };
    }

    pub fn deinit(self: *Self) void {
        self.p10k.deinit();
    }

    /// Render the GhostKellz prompt
    pub fn render(self: *Self, ctx: PromptContext) ![]const u8 {
        var segments = std.ArrayListUnmanaged(u8){};
        defer segments.deinit(self.allocator);

        // Line 1: Left segments
        if (Layout.use_two_line) {
            try segments.appendSlice(self.allocator, Layout.multiline_prefix_first);
            try segments.append(self.allocator, ' ');
        }

        // OS Icon segment (Arch Linux)
        const os_seg = try self.renderOsIcon();
        defer self.allocator.free(os_seg);
        try segments.appendSlice(self.allocator, os_seg);

        // Directory segment
        const dir_seg = try self.renderDirectory(ctx.cwd);
        defer self.allocator.free(dir_seg);
        try segments.appendSlice(self.allocator, dir_seg);

        // VCS (Git) segment
        if (ctx.in_git_repo) {
            const vcs_seg = try self.renderVcs(ctx.git_branch, ctx.git_dirty);
            defer self.allocator.free(vcs_seg);
            try segments.appendSlice(self.allocator, vcs_seg);
        }

        // Right segments (if terminal width allows)
        if (ctx.terminal_width > 100) {
            try self.renderRightSegments(&segments, ctx);
        }

        // Line 2: Prompt character
        if (Layout.use_two_line) {
            try segments.append(self.allocator, '\n');
            try segments.appendSlice(self.allocator, Layout.multiline_prefix_last);
        } else {
            try segments.append(self.allocator, ' ');
        }

        // Prompt character (color based on last exit code)
        const prompt_color = if (ctx.exit_code == 0) Colors.status_ok_fg else Colors.status_err_fg;
        const colored_prompt = try self.colorize(Layout.prompt_char, prompt_color);
        defer self.allocator.free(colored_prompt);
        try segments.appendSlice(self.allocator, colored_prompt);
        try segments.append(self.allocator, ' ');

        return try segments.toOwnedSlice(self.allocator);
    }

    fn renderOsIcon(self: *Self) ![]const u8 {
        const icon_name = "LINUX_ARCH_ICON";
        if (self.p10k.getIcon(icon_name)) |icon| {
            // Format: [bg:color][fg:color] ICON [separator]
            return try std.fmt.allocPrint(
                self.allocator,
                "\x1b[48;5;{d}m\x1b[38;5;{d}m {s} \x1b[0m",
                .{ Colors.os_icon_bg, Colors.os_icon_fg, icon.symbol }
            );
        }
        return try self.allocator.dupe(u8, "");
    }

    fn renderDirectory(self: *Self, cwd: []const u8) ![]const u8 {
        // Truncate to last 3 components (like your .p10k.zsh)
        const display_path = try self.truncatePath(cwd, 3);
        defer self.allocator.free(display_path);

        return try std.fmt.allocPrint(
            self.allocator,
            "\x1b[48;5;{d}m\x1b[38;5;{d}m {s} \x1b[0m",
            .{ Colors.dir_bg, Colors.dir_fg, display_path }
        );
    }

    fn renderVcs(self: *Self, branch: []const u8, dirty: bool) ![]const u8 {
        // Branch name + dirty indicator
        var content = std.ArrayListUnmanaged(u8){};
        defer content.deinit(self.allocator);

        // Add git icon
        if (self.p10k.getIcon("VCS_BRANCH_ICON")) |icon| {
            try content.appendSlice(self.allocator, icon.symbol);
            try content.append(self.allocator, ' ');
        }

        try content.appendSlice(self.allocator, branch);
        if (dirty) {
            try content.append(self.allocator, '*');
        }

        return try std.fmt.allocPrint(
            self.allocator,
            "\x1b[48;5;{d}m\x1b[38;5;{d}m {s} \x1b[0m",
            .{ Colors.vcs_bg, Colors.vcs_fg, content.items }
        );
    }

    fn renderRightSegments(self: *Self, segments: *std.ArrayListUnmanaged(u8), ctx: PromptContext) !void {
        _ = ctx;

        // Detect versions in current directory
        if (try self.version_detector.detectNodeJs()) |info| {
            const seg = try self.renderVersionSegment("", info.version, Colors.green1, Colors.gray3);
            defer self.allocator.free(seg);
            try segments.appendSlice(self.allocator, "  ");
            try segments.appendSlice(self.allocator, seg);
        }

        if (try self.version_detector.detectRust()) |info| {
            const seg = try self.renderVersionSegment("", info.version, Colors.red1, Colors.gray3);
            defer self.allocator.free(seg);
            try segments.appendSlice(self.allocator, "  ");
            try segments.appendSlice(self.allocator, seg);
        }

        if (try self.version_detector.detectGo()) |info| {
            const seg = try self.renderVersionSegment("", info.version, Colors.blue6, Colors.gray3);
            defer self.allocator.free(seg);
            try segments.appendSlice(self.allocator, "  ");
            try segments.appendSlice(self.allocator, seg);
        }

        if (try self.version_detector.detectZig()) |info| {
            const seg = try self.renderVersionSegment("⚡", info.version, Colors.yellow, Colors.gray3);
            defer self.allocator.free(seg);
            try segments.appendSlice(self.allocator, "  ");
            try segments.appendSlice(self.allocator, seg);
        }
    }

    fn renderVersionSegment(self: *Self, icon: []const u8, version: []const u8, fg: u8, bg: u8) ![]const u8 {
        return try std.fmt.allocPrint(
            self.allocator,
            "\x1b[48;5;{d}m\x1b[38;5;{d}m {s} {s} \x1b[0m",
            .{ bg, fg, icon, version }
        );
    }

    fn truncatePath(self: *Self, path: []const u8, max_components: usize) ![]const u8 {
        var components = std.ArrayListUnmanaged([]const u8){};
        defer components.deinit(self.allocator);

        var it = std.mem.splitSequence(u8, path, "/");
        while (it.next()) |component| {
            if (component.len > 0) {
                try components.append(self.allocator, component);
            }
        }

        // Replace $HOME with ~
        const home = std.posix.getenv("HOME");
        if (home != null and std.mem.startsWith(u8, path, home.?)) {
            // Path starts with home, replace with ~
            if (components.items.len > max_components) {
                const start = components.items.len - max_components;
                var result = std.ArrayListUnmanaged(u8){};
                defer result.deinit(self.allocator);
                try result.appendSlice(self.allocator, "~/…/");
                for (components.items[start..]) |comp| {
                    try result.appendSlice(self.allocator, comp);
                    try result.append(self.allocator, '/');
                }
                if (result.items.len > 0 and result.items[result.items.len - 1] == '/') {
                    _ = result.pop();
                }
                return try result.toOwnedSlice(self.allocator);
            }
        }

        // Just truncate normally
        if (components.items.len > max_components) {
            const start = components.items.len - max_components;
            var result = std.ArrayListUnmanaged(u8){};
            defer result.deinit(self.allocator);
            try result.appendSlice(self.allocator, "…/");
            for (components.items[start..]) |comp| {
                try result.appendSlice(self.allocator, comp);
                try result.append(self.allocator, '/');
            }
            if (result.items.len > 0 and result.items[result.items.len - 1] == '/') {
                _ = result.pop();
            }
            return try result.toOwnedSlice(self.allocator);
        }

        return try self.allocator.dupe(u8, path);
    }

    fn colorize(self: *Self, text: []const u8, color: u8) ![]const u8 {
        return try std.fmt.allocPrint(
            self.allocator,
            "\x1b[38;5;{d}m{s}\x1b[0m",
            .{ color, text }
        );
    }

    /// Convert ANSI 256-color code to RGB (approximate)
    fn ansi256ToRgb(color: u8) u32 {
        // Basic 16 colors (0-15)
        if (color < 16) {
            const basic_colors = [_]u32{
                0x000000, 0x800000, 0x008000, 0x808000,
                0x000080, 0x800080, 0x008080, 0xc0c0c0,
                0x808080, 0xff0000, 0x00ff00, 0xffff00,
                0x0000ff, 0xff00ff, 0x00ffff, 0xffffff,
            };
            return basic_colors[color];
        }

        // 216 color cube (16-231)
        if (color >= 16 and color <= 231) {
            const idx = color - 16;
            const r = (idx / 36) * 51;
            const g = ((idx % 36) / 6) * 51;
            const b = (idx % 6) * 51;
            return (@as(u32, r) << 16) | (@as(u32, g) << 8) | b;
        }

        // Grayscale (232-255)
        if (color >= 232) {
            const gray = 8 + (color - 232) * 10;
            return (@as(u32, gray) << 16) | (@as(u32, gray) << 8) | gray;
        }

        return 0xFFFFFF; // Fallback white
    }
};

/// Context passed to prompt renderer
pub const PromptContext = struct {
    cwd: []const u8,
    user: []const u8,
    host: []const u8,
    exit_code: i32,
    in_git_repo: bool = false,
    git_branch: []const u8 = "",
    git_dirty: bool = false,
    terminal_width: usize = 80,
    terminal_height: usize = 24,
};

// Tests
test "GhostKellzPrompt initialization" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var detector = VersionDetector.init(allocator);
    defer detector.deinit();

    var prompt = try GhostKellzPrompt.init(allocator, &detector);
    defer prompt.deinit();

    try testing.expect(true);
}

test "GhostKellzPrompt path truncation" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var detector = VersionDetector.init(allocator);
    defer detector.deinit();

    var prompt = try GhostKellzPrompt.init(allocator, &detector);
    defer prompt.deinit();

    const long_path = "/home/user/projects/gshell/src/prompts/ghostkellz.zig";
    const truncated = try prompt.truncatePath(long_path, 3);
    defer allocator.free(truncated);

    // Should truncate to last 3 components
    try testing.expect(std.mem.indexOf(u8, truncated, "…") != null);
}

test "GhostKellzPrompt ANSI color conversion" {
    const testing = std.testing;

    // Test basic colors
    const black = GhostKellzPrompt.ansi256ToRgb(0);
    try testing.expectEqual(@as(u32, 0x000000), black);

    const white = GhostKellzPrompt.ansi256ToRgb(15);
    try testing.expectEqual(@as(u32, 0xffffff), white);

    // Test 256-color cube
    const color = GhostKellzPrompt.ansi256ToRgb(122); // Mint green
    try testing.expect(color != 0);
}
