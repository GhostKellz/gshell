const std = @import("std");

/// GPPrompt Setup Wizard (PowerLevel10k-style configuration)
/// Interactive wizard to configure GShell prompt and plugins
pub const GPPromptWizard = struct {
    allocator: std.mem.Allocator,
    stdin: std.fs.File,
    stdout: std.fs.File,

    pub fn init(allocator: std.mem.Allocator) GPPromptWizard {
        return .{
            .allocator = allocator,
            .stdin = std.fs.File.stdin(),
            .stdout = std.fs.File.stdout(),
        };
    }

    pub fn deinit(self: *GPPromptWizard) void {
        _ = self;
    }

    /// Run the wizard
    pub fn run(self: *GPPromptWizard) !void {
        try self.showWelcome();

        // Gather user preferences
        const prompt_style = try self.askPromptStyle();
        const color_theme = try self.askColorTheme();
        const plugins = try self.askPlugins();
        const nerd_font = try self.confirmNerdFont();

        // Generate configuration
        const config = try self.generateConfig(prompt_style, color_theme, plugins, nerd_font);
        defer self.allocator.free(config);

        // Show preview
        try self.showPreview(config);

        // Ask for confirmation
        if (try self.confirmSave()) {
            try self.saveConfig(config);
            try self.showCompletion();
        } else {
            try self.print("\n⚠️  Configuration not saved. Run 'gsh p10ksetup' to try again.\n\n", .{});
        }
    }

    fn showWelcome(self: *GPPromptWizard) !void {
        try self.print("\x1b[2J\x1b[H", .{}); // Clear screen
        try self.print(
            \\╔═══════════════════════════════════════════════════════════╗
            \\║                                                           ║
            \\║    🌊 GPPrompt Configuration Wizard                      ║
            \\║                                                           ║
            \\║    Welcome to the GShell GPPrompt setup wizard!          ║
            \\║    This wizard will help you configure your prompt       ║
            \\║    and plugins in just a few steps.                      ║
            \\║                                                           ║
            \\╚═══════════════════════════════════════════════════════════╝
            \\
            \\
        , .{});
        try self.print("Press ENTER to continue...", .{});
        _ = try self.readLine();
    }

    fn askPromptStyle(self: *GPPromptWizard) !PromptStyle {
        try self.print("\x1b[2J\x1b[H", .{}); // Clear screen
        try self.print(
            \\╔═══════════════════════════════════════════════════════════╗
            \\║  Step 1/4: Choose Prompt Style                            ║
            \\╚═══════════════════════════════════════════════════════════╝
            \\
            \\Select your preferred prompt style:
            \\
            \\  (1) GPPrompt - PowerLevel10k-style prompt (recommended)
            \\      ╭─  arch  ~/projects/gshell   main*
            \\      ╰─ ❯
            \\
            \\  (2) Starship - Modern, fast prompt (requires starship binary)
            \\      via  ~/projects/gshell on  main [!]
            \\
            \\  (3) Minimal - Simple, fast prompt
            \\      user@host ~/projects/gshell (main*) $
            \\
            \\
        , .{});

        while (true) {
            try self.print("Enter your choice (1-3) [1]: ", .{});
            const input = try self.readLine();
            const choice = std.mem.trim(u8, input, " \n\r\t");

            if (choice.len == 0 or std.mem.eql(u8, choice, "1")) {
                return .gprompt;
            } else if (std.mem.eql(u8, choice, "2")) {
                return .starship;
            } else if (std.mem.eql(u8, choice, "3")) {
                return .minimal;
            } else {
                try self.print("Invalid choice. Please enter 1, 2, or 3.\n", .{});
            }
        }
    }

    fn askColorTheme(self: *GPPromptWizard) !ColorTheme {
        try self.print("\x1b[2J\x1b[H", .{}); // Clear screen
        try self.print(
            \\╔═══════════════════════════════════════════════════════════╗
            \\║  Step 2/4: Choose Color Theme                             ║
            \\╚═══════════════════════════════════════════════════════════╝
            \\
            \\Select your preferred color theme for LS_COLORS:
            \\
            \\  (1) Ghost Hacker Blue - Teal/mint cyberpunk theme (default)
            \\  (2) Tokyo Night - Modern dark theme
            \\  (3) Tokyo Night Moon - Moonlit variant
            \\  (4) Dracula - Popular purple/pink theme
            \\  (5) None - Use system default colors
            \\
            \\
        , .{});

        while (true) {
            try self.print("Enter your choice (1-5) [1]: ", .{});
            const input = try self.readLine();
            const choice = std.mem.trim(u8, input, " \n\r\t");

            if (choice.len == 0 or std.mem.eql(u8, choice, "1")) {
                return .ghost_hacker_blue;
            } else if (std.mem.eql(u8, choice, "2")) {
                return .tokyonight_night;
            } else if (std.mem.eql(u8, choice, "3")) {
                return .tokyonight_moon;
            } else if (std.mem.eql(u8, choice, "4")) {
                return .dracula;
            } else if (std.mem.eql(u8, choice, "5")) {
                return .none;
            } else {
                try self.print("Invalid choice. Please enter 1-5.\n", .{});
            }
        }
    }

    fn askPlugins(self: *GPPromptWizard) ![]const PluginChoice {
        try self.print("\x1b[2J\x1b[H", .{}); // Clear screen
        try self.print(
            \\╔═══════════════════════════════════════════════════════════╗
            \\║  Step 3/4: Choose Plugins                                 ║
            \\╚═══════════════════════════════════════════════════════════╝
            \\
            \\Select which built-in plugins to enable:
            \\(Enter plugin numbers separated by spaces, or press ENTER for all)
            \\
            \\  (1) git       - Git aliases and helpers (gs, gd, gc, etc.)
            \\  (2) docker    - Docker shortcuts (dps, di, dcu, etc.)
            \\  (3) network   - Network utilities (port_scan, my_ip, etc.)
            \\  (4) kubectl   - Kubernetes helpers (k, kg, klog, etc.)
            \\  (5) dev-tools - Version detection (Node, Rust, Go, Python)
            \\  (6) system    - System information (sysinfo, cpu_info, etc.)
            \\
            \\Examples:
            \\  1 2 3    - Enable git, docker, and network
            \\  1 5      - Enable git and dev-tools
            \\  (empty)  - Enable all plugins
            \\
            \\
        , .{});

        try self.print("Enter your choices: ", .{});
        const input = try self.readLine();
        const choice = std.mem.trim(u8, input, " \n\r\t");

        // If empty, enable all
        if (choice.len == 0) {
            const all = try self.allocator.alloc(PluginChoice, 6);
            all[0] = .git;
            all[1] = .docker;
            all[2] = .network;
            all[3] = .kubectl;
            all[4] = .dev_tools;
            all[5] = .system;
            return all;
        }

        // Parse space-separated numbers
        var plugins = std.ArrayListUnmanaged(PluginChoice){};
        defer plugins.deinit(self.allocator);

        var iter = std.mem.tokenizeScalar(u8, choice, ' ');
        while (iter.next()) |token| {
            const num = std.fmt.parseInt(u8, token, 10) catch continue;
            const plugin: PluginChoice = switch (num) {
                1 => .git,
                2 => .docker,
                3 => .network,
                4 => .kubectl,
                5 => .dev_tools,
                6 => .system,
                else => continue,
            };
            try plugins.append(self.allocator, plugin);
        }

        return try plugins.toOwnedSlice(self.allocator);
    }

    fn confirmNerdFont(self: *GPPromptWizard) !bool {
        try self.print("\x1b[2J\x1b[H", .{}); // Clear screen
        try self.print(
            \\╔═══════════════════════════════════════════════════════════╗
            \\║  Step 4/4: Nerd Font Confirmation                         ║
            \\╚═══════════════════════════════════════════════════════════╝
            \\
            \\GPPrompt uses Nerd Fonts for beautiful icons like:
            \\     (Arch)  (Node.js)  (Git)  (Rust)
            \\
            \\Do you have a Nerd Font installed?
            \\
            \\If you see icons above correctly, answer YES.
            \\If you see boxes or question marks, answer NO.
            \\
            \\Install Nerd Fonts:
            \\  Arch: sudo pacman -S ttf-meslo-nerd ttf-firacode-nerd
            \\  macOS: brew tap homebrew/cask-fonts && brew install font-meslo-lg-nerd-font
            \\  Other: https://www.nerdfonts.com/
            \\
            \\
        , .{});

        while (true) {
            try self.print("Do you have a Nerd Font installed? (y/n) [y]: ", .{});
            const input = try self.readLine();
            const choice = std.mem.trim(u8, input, " \n\r\t");

            if (choice.len == 0 or std.ascii.toLower(choice[0]) == 'y') {
                return true;
            } else if (std.ascii.toLower(choice[0]) == 'n') {
                return false;
            } else {
                try self.print("Please answer 'y' or 'n'.\n", .{});
            }
        }
    }

    fn generateConfig(
        self: *GPPromptWizard,
        prompt_style: PromptStyle,
        color_theme: ColorTheme,
        plugins: []const PluginChoice,
        nerd_font: bool,
    ) ![]const u8 {
        _ = nerd_font;
        var config = std.ArrayListUnmanaged(u8){};
        defer config.deinit(self.allocator);

        // Header
        try config.appendSlice(self.allocator,
            \\-- ~/.gshrc.gza — GShell Configuration (Ghostlang)
            \\-- Generated by GPPrompt Wizard
            \\--
            \\-- This file is executed when gshell starts in interactive mode.
            \\-- All Ghostlang language features are available here!
            \\
            \\-- ──────────────────────────────────────────────────────────────
            \\-- Environment Variables
            \\-- ──────────────────────────────────────────────────────────────
            \\setenv("EDITOR", "nvim")
            \\setenv("PAGER", "less")
            \\setenv("SHELL", "/usr/bin/gshell")
            \\
            \\
        );

        // Prompt configuration
        try config.appendSlice(self.allocator,
            \\-- ──────────────────────────────────────────────────────────────
            \\-- Prompt Configuration
            \\-- ──────────────────────────────────────────────────────────────
            \\
        );

        switch (prompt_style) {
            .gprompt => {
                try config.appendSlice(self.allocator,
                    \\-- GPPrompt: Native PowerLevel10k-style prompt
                    \\gprompt_enable()
                    \\
                    \\
                );
            },
            .starship => {
                try config.appendSlice(self.allocator,
                    \\-- Starship: Modern prompt (requires starship binary)
                    \\if command_exists("starship") then
                    \\    gprompt_disable()
                    \\    use_starship(true)
                    \\else
                    \\    print("⚠️  Starship not found, falling back to GPPrompt")
                    \\    gprompt_enable()
                    \\end
                    \\
                    \\
                );
            },
            .minimal => {
                try config.appendSlice(self.allocator,
                    \\-- Minimal: Simple, fast prompt
                    \\gprompt_disable()
                    \\enable_git_prompt()
                    \\
                    \\
                );
            },
        }

        // Color theme
        try config.appendSlice(self.allocator,
            \\-- ──────────────────────────────────────────────────────────────
            \\-- Color Theme
            \\-- ──────────────────────────────────────────────────────────────
            \\
        );

        if (color_theme != .none) {
            const theme_section = try std.fmt.allocPrint(
                self.allocator,
                \\-- Vivid theme for LS_COLORS
                \\if command_exists("vivid") then
                \\    load_vivid_theme("{s}")
                \\end
                \\
                \\
            , .{@tagName(color_theme)});
            defer self.allocator.free(theme_section);
            try config.appendSlice(self.allocator, theme_section);
        } else {
            try config.appendSlice(self.allocator,
                \\-- Using system default colors
                \\
                \\
            );
        }

        // Plugins
        try config.appendSlice(self.allocator,
            \\-- ──────────────────────────────────────────────────────────────
            \\-- Plugins (GhostPlug)
            \\-- ──────────────────────────────────────────────────────────────
            \\
        );

        for (plugins) |plugin| {
            const plugin_line = try std.fmt.allocPrint(self.allocator, "enable_plugin(\"{s}\")\n", .{@tagName(plugin)});
            defer self.allocator.free(plugin_line);
            try config.appendSlice(self.allocator, plugin_line);
        }

        // Aliases
        try config.appendSlice(self.allocator,
            \\
            \\-- ──────────────────────────────────────────────────────────────
            \\-- Common Aliases
            \\-- ──────────────────────────────────────────────────────────────
            \\alias("ll", "ls -lah")
            \\alias("la", "ls -A")
            \\alias("l", "ls -CF")
            \\alias("...", "cd ../..")
            \\alias("grep", "grep --color=auto")
            \\
            \\-- Editor shortcuts
            \\alias("e", getenv("EDITOR") or "vim")
            \\alias("vi", getenv("EDITOR") or "vim")
            \\
            \\
        );

        // History
        try config.appendSlice(self.allocator,
            \\-- ──────────────────────────────────────────────────────────────
            \\-- History Configuration
            \\-- ──────────────────────────────────────────────────────────────
            \\set_history_size(10000)
            \\set_history_file(getenv("HOME") .. "/.gshell_history")
            \\
            \\
        );

        // Welcome message
        try config.appendSlice(self.allocator,
            \\-- ──────────────────────────────────────────────────────────────
            \\-- Startup Message
            \\-- ──────────────────────────────────────────────────────────────
            \\print("🌊 GShell " .. (getenv("GSHELL_VERSION") or "0.1.0") .. " loaded")
            \\
            \\-- Show git status if in a git repository
            \\if in_git_repo() then
            \\    local branch = git_branch()
            \\    if branch then
            \\        local status_marker = git_dirty() and "*" or ""
            \\        print("📁 Git: " .. branch .. status_marker)
            \\    end
            \\end
            \\
        );

        return try config.toOwnedSlice(self.allocator);
    }

    fn showPreview(self: *GPPromptWizard, config: []const u8) !void {
        try self.print("\x1b[2J\x1b[H", .{}); // Clear screen
        try self.print(
            \\╔═══════════════════════════════════════════════════════════╗
            \\║  Configuration Preview                                    ║
            \\╚═══════════════════════════════════════════════════════════╝
            \\
            \\This configuration will be written to ~/.gshrc.gza:
            \\
            \\───────────────────────────────────────────────────────────────
            \\
        , .{});
        try self.print("{s}\n", .{config});
        try self.print(
            \\───────────────────────────────────────────────────────────────
            \\
            \\
        , .{});
    }

    fn confirmSave(self: *GPPromptWizard) !bool {
        while (true) {
            try self.print("Save this configuration? (y/n) [y]: ", .{});
            const input = try self.readLine();
            const choice = std.mem.trim(u8, input, " \n\r\t");

            if (choice.len == 0 or std.ascii.toLower(choice[0]) == 'y') {
                return true;
            } else if (std.ascii.toLower(choice[0]) == 'n') {
                return false;
            } else {
                try self.print("Please answer 'y' or 'n'.\n", .{});
            }
        }
    }

    fn saveConfig(self: *GPPromptWizard, config: []const u8) !void {
        const home = std.posix.getenv("HOME") orelse return error.HomeNotFound;
        const config_path = try std.fmt.allocPrint(self.allocator, "{s}/.gshrc.gza", .{home});
        defer self.allocator.free(config_path);

        // Backup existing config if it exists
        std.fs.cwd().access(config_path, .{}) catch |err| switch (err) {
            error.FileNotFound => {},
            else => return err,
        };

        const backup_path = try std.fmt.allocPrint(self.allocator, "{s}.backup", .{config_path});
        defer self.allocator.free(backup_path);

        std.fs.cwd().copyFile(config_path, std.fs.cwd(), backup_path, .{}) catch {};

        // Write new config
        const file = try std.fs.cwd().createFile(config_path, .{ .truncate = true });
        defer file.close();

        try file.writeAll(config);
        try file.chmod(0o600); // -rw-------
    }

    fn showCompletion(self: *GPPromptWizard) !void {
        try self.print(
            \\
            \\╔═══════════════════════════════════════════════════════════╗
            \\║                                                           ║
            \\║    ✅ Configuration Complete!                            ║
            \\║                                                           ║
            \\║    Your ~/.gshrc.gza has been created.                   ║
            \\║    Restart GShell to see your new prompt!                ║
            \\║                                                           ║
            \\║    Tips:                                                  ║
            \\║    • Edit ~/.gshrc.gza to customize further              ║
            \\║    • Run 'gsh p10ksetup' to reconfigure                  ║
            \\║    • Visit docs/gprompt/README.md for more info          ║
            \\║                                                           ║
            \\╚═══════════════════════════════════════════════════════════╝
            \\
            \\
        , .{});
    }

    // Helper methods
    fn print(self: *GPPromptWizard, comptime fmt: []const u8, args: anytype) !void {
        const msg = try std.fmt.allocPrint(self.allocator, fmt, args);
        defer self.allocator.free(msg);
        try self.stdout.writeAll(msg);
    }

    fn readLine(self: *GPPromptWizard) ![]const u8 {
        var buffer: [256]u8 = undefined;
        const bytes_read = try self.stdin.read(&buffer);

        if (bytes_read == 0) return "";

        // Trim newline
        var end = bytes_read;
        if (end > 0 and buffer[end - 1] == '\n') end -= 1;
        if (end > 0 and buffer[end - 1] == '\r') end -= 1;

        return buffer[0..end];
    }
};

const PromptStyle = enum {
    gprompt,
    starship,
    minimal,
};

const ColorTheme = enum {
    ghost_hacker_blue,
    tokyonight_night,
    tokyonight_moon,
    dracula,
    none,
};

const PluginChoice = enum {
    git,
    docker,
    network,
    kubectl,
    dev_tools,
    system,
};

pub fn runWizard(allocator: std.mem.Allocator) !void {
    var wizard = GPPromptWizard.init(allocator);
    defer wizard.deinit();

    try wizard.run();
}
