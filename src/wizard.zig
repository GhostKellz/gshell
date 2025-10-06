const std = @import("std");

// ANSI color codes - Teal/Mint theme
const TEAL = "\x1b[38;5;51m"; // Bright cyan/teal
const MINT = "\x1b[38;5;121m"; // Mint green
const DARK_TEAL = "\x1b[38;5;37m"; // Dark teal
const GRAY = "\x1b[38;5;240m"; // Gray for descriptions
const WHITE = "\x1b[1;37m"; // Bright white
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";

pub const WizardError = error{
    InvalidInput,
    ReadFailed,
    WriteFailed,
};

pub const PromptChoice = enum {
    starship,
    git_prompt,
    minimal,
};

pub const ThemeChoice = enum {
    ghost_hacker_blue,
    mint_fresh,
    teal_ocean,
    dracula,
    tokyonight_night,
};

pub const WizardConfig = struct {
    prompt: PromptChoice,
    theme: ThemeChoice,
    enable_git_plugin: bool,
    enable_network_plugin: bool,
    enable_docker_plugin: bool,
    enable_dev_tools: bool,
    use_starship: bool,
};

pub fn runInteractiveWizard(allocator: std.mem.Allocator) !WizardConfig {
    var config = WizardConfig{
        .prompt = .starship,
        .theme = .ghost_hacker_blue,
        .enable_git_plugin = false,
        .enable_network_plugin = false,
        .enable_docker_plugin = false,
        .enable_dev_tools = false,
        .use_starship = true,
    };

    const stdin = std.fs.File.stdin();
    const stdout = std.fs.File.stdout();

    // Print welcome header
    try printHeader(stdout);

    // Prompt configuration
    config.prompt = try promptForPromptStyle(allocator, stdin, stdout);
    config.use_starship = (config.prompt == .starship);

    // Theme configuration
    config.theme = try promptForTheme(allocator, stdin, stdout);

    // Plugin configuration
    try printSection(stdout, "Plugin Configuration");
    config.enable_git_plugin = try promptYesNo(allocator, stdin, stdout, "Enable Git integration? (shortcuts, status, etc.)", true);
    config.enable_network_plugin = try promptYesNo(allocator, stdin, stdout, "Enable network utilities? (net-test, net-fetch, etc.)", true);
    config.enable_docker_plugin = try promptYesNo(allocator, stdin, stdout, "Enable Docker integration?", false);
    config.enable_dev_tools = try promptYesNo(allocator, stdin, stdout, "Enable development tools? (code, build shortcuts)", true);

    // Summary
    try printSummary(stdout, config);

    return config;
}

fn printHeader(file: std.fs.File) !void {
    const header =
        \\
        \\
        ++
        TEAL ++
        "  ╔═══════════════════════════════════════════════════════════════╗\n" ++
        "  ║                                                               ║\n" ++
        "  ║   " ++
        BOLD ++
        MINT ++
        "█▀▀ █▀ █ █   " ++
        TEAL ++
        "  ███╗   ██╗███████╗██╗  ██╗████████╗" ++
        RESET ++
        TEAL ++
        "     ║\n" ++
        "  ║   " ++
        BOLD ++
        MINT ++
        "█▄█ ▄█ █▀█   " ++
        TEAL ++
        "████╗  ██║██╔════╝╚██╗██╔╝╚══██╔══╝" ++
        RESET ++
        TEAL ++
        "     ║\n" ++
        "  ║          " ++
        TEAL ++
        "██╔██╗ ██║█████╗   ╚███╔╝    ██║" ++
        RESET ++
        TEAL ++
        "          ║\n" ++
        "  ║          " ++
        TEAL ++
        "██║╚██╗██║██╔══╝   ██╔██╗    ██║" ++
        RESET ++
        TEAL ++
        "          ║\n" ++
        "  ║          " ++
        TEAL ++
        "██║ ╚████║███████╗██╔╝ ██╗   ██║" ++
        RESET ++
        TEAL ++
        "          ║\n" ++
        "  ║          " ++
        TEAL ++
        "╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝   ╚═╝" ++
        RESET ++
        TEAL ++
        "          ║\n" ++
        "  ║                                                               ║\n" ++
        "  ║           " ++
        MINT ++
        "█▀▀ █▀▀ █▄ █ █▀▀ █▀█ ▄▀█ ▀█▀ █ █▀█ █▄ █" ++
        RESET ++
        TEAL ++
        "            ║\n" ++
        "  ║           " ++
        MINT ++
        "█▄█ ██▄ █ ▀█ ██▄ █▀▄ █▀█  █  █ █▄█ █ ▀█" ++
        RESET ++
        TEAL ++
        "            ║\n" ++
        "  ║                                                               ║\n" ++
        "  ║                    " ++
        WHITE ++
        "Next Generation Shell" ++
        RESET ++
        TEAL ++
        "                     ║\n" ++
        "  ║                         " ++
        "\x1b[38;5;226m" ++ // Yellow for lightning
        "⚡ Setup Wizard" ++
        RESET ++
        TEAL ++
        "                        ║\n" ++
        "  ║                                                               ║\n" ++
        "  ╚═══════════════════════════════════════════════════════════════╝\n" ++
        RESET ++
        "\n" ++
        WHITE ++
        "  Welcome to GShell! " ++
        RESET ++
        GRAY ++
        "Let's set up your shell in just a few steps.\n" ++
        RESET ++
        "\n";

    try file.writeAll(header);
}

fn printSection(file: std.fs.File, title: []const u8) !void {
    const section = try std.fmt.allocPrint(std.heap.page_allocator, "\n{s}{s}━━━ {s}{s}{s} {s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ TEAL, BOLD, MINT, title, TEAL, RESET, RESET });
    defer std.heap.page_allocator.free(section);
    try file.writeAll(section);
}

fn promptForPromptStyle(allocator: std.mem.Allocator, stdin: std.fs.File, stdout: std.fs.File) !PromptChoice {
    try printSection(stdout, "Prompt Style");

    const prompt =
        GRAY ++
        "  Choose your shell prompt style:\n\n" ++
        RESET ++
        MINT ++
        "    1" ++
        RESET ++
        " │ " ++
        WHITE ++
        "Starship" ++
        RESET ++
        " " ++
        GRAY ++
        "(Recommended)" ++
        RESET ++
        "\n" ++
        "      └─ Fast, customizable, cross-shell prompt\n" ++
        "      └─ Shows git status, language versions, etc.\n\n" ++
        MINT ++
        "    2" ++
        RESET ++
        " │ " ++
        WHITE ++
        "Git Prompt" ++
        RESET ++
        "\n" ++
        "      └─ Lightweight, focused on git integration\n" ++
        "      └─ Shows current branch and status\n\n" ++
        MINT ++
        "    3" ++
        RESET ++
        " │ " ++
        WHITE ++
        "Minimal" ++
        RESET ++
        "\n" ++
        "      └─ Simple, clean prompt\n" ++
        "      └─ Just directory and status symbol\n\n" ++
        TEAL ++
        "  →" ++
        RESET ++
        " Enter your choice [1-3] (default: 1): ";

    try stdout.writeAll(prompt);

    const choice = try readLine(allocator, stdin);
    defer allocator.free(choice);

    if (choice.len == 0) return .starship;

    if (std.mem.eql(u8, choice, "1")) return .starship;
    if (std.mem.eql(u8, choice, "2")) return .git_prompt;
    if (std.mem.eql(u8, choice, "3")) return .minimal;

    try stdout.writeAll(GRAY ++ "  Invalid choice, using Starship (default)\n" ++ RESET);
    return .starship;
}

fn promptForTheme(allocator: std.mem.Allocator, stdin: std.fs.File, stdout: std.fs.File) !ThemeChoice {
    try printSection(stdout, "Color Theme");

    const prompt =
        GRAY ++
        "  Choose your color theme:\n\n" ++
        RESET ++
        MINT ++
        "    1" ++
        RESET ++
        " │ " ++
        WHITE ++
        "Ghost Hacker Blue" ++
        RESET ++
        " " ++
        GRAY ++
        "(Default)" ++
        RESET ++
        "\n" ++
        "      └─ " ++
        "\x1b[38;5;39m" ++
        "Deep blues" ++
        RESET ++
        " and " ++
        "\x1b[38;5;51m" ++
        "cyans" ++
        RESET ++
        " - perfect for terminal hackers\n\n" ++
        MINT ++
        "    2" ++
        RESET ++
        " │ " ++
        WHITE ++
        "Mint Fresh" ++
        RESET ++
        "\n" ++
        "      └─ " ++
        "\x1b[38;5;121m" ++
        "Mint greens" ++
        RESET ++
        " and " ++
        "\x1b[38;5;158m" ++
        "light teals" ++
        RESET ++
        " - refreshing and clean\n\n" ++
        MINT ++
        "    3" ++
        RESET ++
        " │ " ++
        WHITE ++
        "Teal Ocean" ++
        RESET ++
        "\n" ++
        "      └─ " ++
        "\x1b[38;5;37m" ++
        "Deep teals" ++
        RESET ++
        " and " ++
        "\x1b[38;5;80m" ++
        "aqua blues" ++
        RESET ++
        " - calming and professional\n\n" ++
        MINT ++
        "    4" ++
        RESET ++
        " │ " ++
        WHITE ++
        "Dracula" ++
        RESET ++
        "\n" ++
        "      └─ " ++
        "\x1b[38;5;141m" ++
        "Purple" ++
        RESET ++
        " and " ++
        "\x1b[38;5;212m" ++
        "pink" ++
        RESET ++
        " - a dark theme classic\n\n" ++
        MINT ++
        "    5" ++
        RESET ++
        " │ " ++
        WHITE ++
        "Tokyo Night" ++
        RESET ++
        "\n" ++
        "      └─ " ++
        "\x1b[38;5;111m" ++
        "Night blues" ++
        RESET ++
        " - inspired by Tokyo at night\n\n" ++
        TEAL ++
        "  →" ++
        RESET ++
        " Enter your choice [1-5] (default: 1): ";

    try stdout.writeAll(prompt);

    const choice = try readLine(allocator, stdin);
    defer allocator.free(choice);

    if (choice.len == 0) return .ghost_hacker_blue;

    if (std.mem.eql(u8, choice, "1")) return .ghost_hacker_blue;
    if (std.mem.eql(u8, choice, "2")) return .mint_fresh;
    if (std.mem.eql(u8, choice, "3")) return .teal_ocean;
    if (std.mem.eql(u8, choice, "4")) return .dracula;
    if (std.mem.eql(u8, choice, "5")) return .tokyonight_night;

    try stdout.writeAll(GRAY ++ "  Invalid choice, using Ghost Hacker Blue (default)\n" ++ RESET);
    return .ghost_hacker_blue;
}

fn promptYesNo(allocator: std.mem.Allocator, stdin: std.fs.File, stdout: std.fs.File, question: []const u8, default_yes: bool) !bool {
    const default_str = if (default_yes) "Y/n" else "y/N";
    const prompt = try std.fmt.allocPrint(allocator, "  {s}{s}{s} [{s}]: ", .{ TEAL, question, RESET, default_str });
    defer allocator.free(prompt);

    try stdout.writeAll(prompt);

    const answer = try readLine(allocator, stdin);
    defer allocator.free(answer);

    if (answer.len == 0) return default_yes;

    const lower = std.ascii.toLower(answer[0]);
    return (lower == 'y');
}

fn readLine(allocator: std.mem.Allocator, file: std.fs.File) ![]u8 {
    var buffer: [256]u8 = undefined;
    const bytes_read = try file.read(&buffer);

    if (bytes_read == 0) return WizardError.ReadFailed;

    // Trim newline
    var end = bytes_read;
    if (end > 0 and buffer[end - 1] == '\n') end -= 1;
    if (end > 0 and buffer[end - 1] == '\r') end -= 1;

    return try allocator.dupe(u8, buffer[0..end]);
}

fn printSummary(file: std.fs.File, config: WizardConfig) !void {
    try printSection(file, "Configuration Summary");

    const prompt_name = switch (config.prompt) {
        .starship => "Starship",
        .git_prompt => "Git Prompt",
        .minimal => "Minimal",
    };

    const theme_name = switch (config.theme) {
        .ghost_hacker_blue => "Ghost Hacker Blue",
        .mint_fresh => "Mint Fresh",
        .teal_ocean => "Teal Ocean",
        .dracula => "Dracula",
        .tokyonight_night => "Tokyo Night",
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const temp_allocator = gpa.allocator();

    const git_status = if (config.enable_git_plugin) TEAL ++ "Enabled" else GRAY ++ "Disabled";
    const network_status = if (config.enable_network_plugin) TEAL ++ "Enabled" else GRAY ++ "Disabled";
    const docker_status = if (config.enable_docker_plugin) TEAL ++ "Enabled" else GRAY ++ "Disabled";
    const devtools_status = if (config.enable_dev_tools) TEAL ++ "Enabled" else GRAY ++ "Disabled";

    const summary = try std.fmt.allocPrint(temp_allocator, "  {s}Prompt:{s}        {s}{s}{s}\n  {s}Theme:{s}         {s}{s}{s}\n  {s}Git Plugin:{s}    {s}{s}\n  {s}Network:{s}       {s}{s}\n  {s}Docker:{s}        {s}{s}\n  {s}Dev Tools:{s}     {s}{s}\n\n", .{
        MINT,
        RESET,
        WHITE,
        prompt_name,
        RESET,
        MINT,
        RESET,
        WHITE,
        theme_name,
        RESET,
        MINT,
        RESET,
        git_status,
        RESET,
        MINT,
        RESET,
        network_status,
        RESET,
        MINT,
        RESET,
        docker_status,
        RESET,
        MINT,
        RESET,
        devtools_status,
        RESET,
    });
    defer temp_allocator.free(summary);

    try file.writeAll(summary);

    const complete =
        TEAL ++
        "  ✓ Configuration complete! Setting up GShell...\n" ++
        RESET ++
        "\n";

    try file.writeAll(complete);
}

pub fn applyConfiguration(allocator: std.mem.Allocator, config: WizardConfig) !void {
    const home = std.posix.getenv("HOME") orelse return error.HomeDirNotFound;

    // Create .gshrc with configuration
    const gshrc_path = try std.fmt.allocPrint(allocator, "{s}/.gshrc.gza", .{home});
    defer allocator.free(gshrc_path);

    const theme_name = switch (config.theme) {
        .ghost_hacker_blue => "ghost-hacker-blue",
        .mint_fresh => "mint-fresh",
        .teal_ocean => "teal-ocean",
        .dracula => "dracula",
        .tokyonight_night => "tokyonight-night",
    };

    // Build config content using allocPrint
    var content_builder = std.ArrayListUnmanaged(u8){};
    defer content_builder.deinit(allocator);

    // Header
    try content_builder.appendSlice(allocator, "-- GShell Configuration (Generated by Setup Wizard)\n");
    try content_builder.appendSlice(allocator, "-- Edit this file to customize your shell\n\n");

    // Theme
    const theme_line = try std.fmt.allocPrint(allocator, "-- Color Theme: {s}\nload_vivid_theme(\"{s}\")\n\n", .{ theme_name, theme_name });
    defer allocator.free(theme_line);
    try content_builder.appendSlice(allocator, theme_line);

    // Plugins
    if (config.enable_git_plugin or config.enable_network_plugin or config.enable_docker_plugin or config.enable_dev_tools) {
        try content_builder.appendSlice(allocator, "-- Enabled Plugins\n");

        if (config.enable_git_plugin) {
            try content_builder.appendSlice(allocator, "enable_plugin(\"git\")\n");
        }
        if (config.enable_network_plugin) {
            try content_builder.appendSlice(allocator, "enable_plugin(\"network\")\n");
        }
        if (config.enable_docker_plugin) {
            try content_builder.appendSlice(allocator, "enable_plugin(\"docker\")\n");
        }
        if (config.enable_dev_tools) {
            try content_builder.appendSlice(allocator, "enable_plugin(\"dev-tools\")\n");
        }

        try content_builder.appendSlice(allocator, "\n");
    }

    // Prompt configuration
    if (config.use_starship) {
        try content_builder.appendSlice(allocator, "-- Starship Prompt (configured in ~/.config/starship.toml)\n");
        try content_builder.appendSlice(allocator, "-- https://starship.rs/config/\n\n");
    }

    // Common aliases
    try content_builder.appendSlice(allocator, "-- Common Aliases\n");
    try content_builder.appendSlice(allocator, "alias ll = \"ls -lah\"\n");
    try content_builder.appendSlice(allocator, "alias la = \"ls -A\"\n");
    try content_builder.appendSlice(allocator, "alias l = \"ls -CF\"\n\n");

    // Environment
    try content_builder.appendSlice(allocator, "-- Environment Variables\n");
    try content_builder.appendSlice(allocator, "-- export MY_VAR = \"value\"\n\n");

    try content_builder.appendSlice(allocator, "-- Custom Configuration Below\n");

    // Write file with secure permissions
    const file = try std.fs.cwd().createFile(gshrc_path, .{});
    defer file.close();
    try file.writeAll(content_builder.items);
    try file.chmod(0o600);

    // Create starship config if using starship
    if (config.use_starship) {
        try createStarshipConfig(allocator, config.theme);
    }
}

fn createStarshipConfig(allocator: std.mem.Allocator, theme: ThemeChoice) !void {
    const home = std.posix.getenv("HOME") orelse return error.HomeDirNotFound;

    const starship_path = try std.fmt.allocPrint(allocator, "{s}/.config/starship.toml", .{home});
    defer allocator.free(starship_path);

    // Create .config directory if it doesn't exist
    const config_dir = try std.fmt.allocPrint(allocator, "{s}/.config", .{home});
    defer allocator.free(config_dir);

    std.fs.cwd().makePath(config_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    const color = switch (theme) {
        .ghost_hacker_blue => "blue",
        .mint_fresh => "green",
        .teal_ocean => "cyan",
        .dracula => "purple",
        .tokyonight_night => "blue",
    };

    const starship_content = try std.fmt.allocPrint(allocator,
        \\# Starship Configuration (Generated by GShell Wizard)
        \\# https://starship.rs/config/
        \\
        \\format = """
        \\$username\
        \\$hostname\
        \\$directory\
        \\$git_branch\
        \\$git_status\
        \\$cmd_duration\
        \\$line_break\
        \\$character"""
        \\
        \\[character]
        \\success_symbol = "[➜](bold {s})"
        \\error_symbol = "[➜](bold red)"
        \\
        \\[directory]
        \\style = "bold {s}"
        \\truncation_length = 3
        \\truncate_to_repo = true
        \\
        \\[git_branch]
        \\symbol = " "
        \\style = "bold {s}"
        \\
        \\[git_status]
        \\style = "bold {s}"
        \\
        \\[cmd_duration]
        \\min_time = 500
        \\format = "took [$duration](bold yellow)"
        \\
    , .{ color, color, color, color });
    defer allocator.free(starship_content);

    const file = try std.fs.cwd().createFile(starship_path, .{});
    defer file.close();
    try file.writeAll(starship_content);
}

pub fn printCompletionMessage(file: std.fs.File) !void {
    const message =
        "\n" ++
        TEAL ++
        "  ╔═══════════════════════════════════════════════════════════════╗\n" ++
        "  ║                                                               ║\n" ++
        "  ║               " ++
        MINT ++
        "✓ GShell is ready to use!" ++
        TEAL ++
        "                       ║\n" ++
        "  ║                                                               ║\n" ++
        "  ╚═══════════════════════════════════════════════════════════════╝\n" ++
        RESET ++
        "\n" ++
        GRAY ++
        "  Quick Tips:\n" ++
        RESET ++
        MINT ++
        "    •" ++
        RESET ++
        " Type " ++
        WHITE ++
        "help" ++
        RESET ++
        " to see available commands\n" ++
        MINT ++
        "    •" ++
        RESET ++
        " Edit " ++
        WHITE ++
        "~/.gshrc.gza" ++
        RESET ++
        " to customize your shell\n" ++
        MINT ++
        "    •" ++
        RESET ++
        " Run " ++
        WHITE ++
        "enable_plugin(\"name\")" ++
        RESET ++
        " to enable plugins\n" ++
        MINT ++
        "    •" ++
        RESET ++
        " Use " ++
        WHITE ++
        "load_vivid_theme(\"name\")" ++
        RESET ++
        " to change themes\n" ++
        "\n" ++
        GRAY ++
        "  Enjoy your next generation shell experience! " ++
        "\x1b[38;5;226m" ++
        "⚡\n" ++
        RESET ++
        "\n";

    try file.writeAll(message);
}
