const std = @import("std");
const flash = @import("flash");
const gshell = @import("gshell");

const cli_version = "0.1.0-alpha";

const AppCLI = flash.CLI(.{
    .name = "gshell",
    .version = cli_version,
    .about = "Ghost Shell — a modern shell for the Ghost stack",
});

const CliState = struct {
    raw_args: []const [:0]u8 = &.{},
    script_index: ?usize = null,
};

var cli_state = CliState{};
var active_cli: ?*AppCLI = null;

const PreprocessedArgs = struct {
    flash_args: []const []const u8,
    script_index: ?usize,
};

inline fn makeConfigArg() flash.Argument {
    return flash.Argument.init("config", (flash.ArgumentConfig{})
        .withHelp("Override the configuration file path")
        .withLong("config"));
}

inline fn makeCommandArg() flash.Argument {
    return flash.Argument.init("command", (flash.ArgumentConfig{})
        .withHelp("Execute a single command string and exit")
        .withShort('c')
        .withLong("command"));
}

const init_command = flash.cmd("init", (flash.CommandConfig{})
    .withAbout("Create or overwrite a gshell configuration file")
    .withArgs(&.{makeConfigArg()})
    .withFlags(&.{
        flash.Flag.init("force", (flash.FlagConfig{})
            .withHelp("Overwrite the configuration if it already exists")
            .withShort('f')
            .withLong("force")),
    })
    .withHandler(initHandler));

const completions_command = flash.cmd("completions", (flash.CommandConfig{})
    .withAbout("Generate shell completions for gshell")
    .withArgs(&.{flash.Argument.init("shell", (flash.ArgumentConfig{})
        .withHelp("Shell to target (bash, zsh, fish, powershell)")
        .setRequired())})
    .withHandler(completionsHandler));

const root_command_config = (flash.CommandConfig{})
    .withAbout("Launch the Ghost shell")
    .withUsage("gshell [--config PATH] [-c command | script.gsh [args...]]")
    .withArgs(&.{ makeConfigArg(), makeCommandArg() })
    .withFlags(&.{
        flash.Flag.init("init", (flash.FlagConfig{})
            .withLong("init")
            .withHelp("Run the configuration wizard and exit")),
    })
    .withSubcommands(&.{ init_command, completions_command })
    .withHandler(rootHandler);

pub fn main() !void {
    if (@import("builtin").is_test) return;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const raw_args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, raw_args);

    const preprocessed = try preprocessArgs(allocator, raw_args);
    defer if (preprocessed.flash_args.len > 0) allocator.free(preprocessed.flash_args);

    cli_state = .{
        .raw_args = raw_args,
        .script_index = preprocessed.script_index,
    };

    var cli = AppCLI.init(allocator, root_command_config);
    active_cli = &cli;
    defer active_cli = null;

    try cli.runWithArgs(preprocessed.flash_args);
}

fn preprocessArgs(allocator: std.mem.Allocator, raw_args: []const [:0]u8) !PreprocessedArgs {
    var processed = std.ArrayList([]const u8){};
    errdefer processed.deinit(allocator);

    if (raw_args.len == 0) {
        return PreprocessedArgs{
            .flash_args = &.{},
            .script_index = null,
        };
    }

    try processed.append(allocator, std.mem.sliceTo(raw_args[0], 0));

    var idx: usize = 1;
    var disable_script_detection = false;
    var script_index: ?usize = null;

    while (idx < raw_args.len) {
        const arg_slice = std.mem.sliceTo(raw_args[idx], 0);

        if (script_index == null and !disable_script_detection) {
            if (std.mem.eql(u8, arg_slice, "--")) {
                if (idx + 1 < raw_args.len) {
                    script_index = idx + 1;
                }
                break;
            }

            if (!isOption(arg_slice)) {
                if (isSubcommandName(arg_slice)) {
                    disable_script_detection = true;
                    try processed.append(allocator, arg_slice);
                    idx += 1;
                    continue;
                } else {
                    script_index = idx;
                    break;
                }
            }

            try processed.append(allocator, arg_slice);

            if (needsValue(arg_slice)) {
                idx += 1;
                if (idx >= raw_args.len) break;
                const value_slice = std.mem.sliceTo(raw_args[idx], 0);
                try processed.append(allocator, value_slice);
            }

            idx += 1;
            continue;
        }

        try processed.append(allocator, arg_slice);
        idx += 1;
    }

    const flash_args = try processed.toOwnedSlice(allocator);
    return PreprocessedArgs{
        .flash_args = flash_args,
        .script_index = script_index,
    };
}

fn isOption(arg: []const u8) bool {
    return arg.len > 0 and arg[0] == '-';
}

fn needsValue(arg: []const u8) bool {
    if (std.mem.indexOfScalar(u8, arg, '=')) |_| {
        return false;
    }
    return std.mem.eql(u8, arg, "--config") or std.mem.eql(u8, arg, "--command") or std.mem.eql(u8, arg, "-c");
}

fn isSubcommandName(arg: []const u8) bool {
    return std.mem.eql(u8, arg, "init") or std.mem.eql(u8, arg, "completions");
}

fn loadOptionsFromContext(ctx: flash.Context) gshell.config.LoadOptions {
    var options = gshell.config.LoadOptions{};
    if (ctx.getString("config")) |path| {
        options.path_override = path;
    }
    return options;
}

fn gatherScriptArgs(allocator: std.mem.Allocator, script_index: usize) ![]const []const u8 {
    const raw = cli_state.raw_args;
    if (script_index + 1 >= raw.len) {
        return &.{};
    }

    const tail = raw[script_index + 1 ..];
    var buffer = try allocator.alloc([]const u8, tail.len);
    for (tail, 0..) |item, i| {
        buffer[i] = std.mem.sliceTo(item, 0);
    }
    return buffer;
}

fn rootHandler(ctx: flash.Context) flash.Error!void {
    const allocator = ctx.allocator;
    const init_flag = ctx.getFlag("init");
    const command_value = ctx.getString("command");
    const script_idx = cli_state.script_index;

    if (init_flag and (command_value != null or script_idx != null)) {
        printUsage();
        std.process.exit(2);
    }

    if (command_value != null and script_idx != null) {
        printUsage();
        std.process.exit(2);
    }

    const load_options = loadOptionsFromContext(ctx);

    if (init_flag) {
        const exit_code = try runInit(allocator, load_options, false);
        std.process.exit(normalizeExit(exit_code));
    }

    var config = gshell.config.load(allocator, load_options) catch |err| {
        reportConfigError(err);
        std.process.exit(1);
    };

    var shell = gshell.Shell.init(allocator, config) catch |err| {
        config.deinit();
        return mapIoError(err);
    };
    defer shell.deinit();

    if (command_value) |cmd| {
        shell.config.interactive = false;
        const exit_code = shell.runCommand(cmd) catch |err| return mapShellExecError(err);
        std.process.exit(normalizeExit(exit_code));
    }

    if (script_idx) |idx| {
        const script_path = std.mem.sliceTo(cli_state.raw_args[idx], 0);
        const script_args = try gatherScriptArgs(shell.allocator, idx);
        defer if (script_args.len > 0) shell.allocator.free(script_args);

        shell.config.interactive = false;
        const exit_code = shell.runScript(script_path, script_args) catch |err| return mapShellExecError(err);
        std.process.exit(normalizeExit(exit_code));
    }

    const exit_code = shell.runInteractive() catch |err| return mapShellExecError(err);
    std.process.exit(normalizeExit(exit_code));
}

fn initHandler(ctx: flash.Context) flash.Error!void {
    const allocator = ctx.allocator;
    const options = loadOptionsFromContext(ctx);
    const force = ctx.getFlag("force");
    const exit_code = try runInit(allocator, options, force);
    std.process.exit(normalizeExit(exit_code));
}

fn completionsHandler(ctx: flash.Context) flash.Error!void {
    const shell_name = ctx.getString("shell") orelse return flash.Error.MissingRequiredArgument;
    _ = shell_name;
    var stdout_file = std.fs.File.stdout();
    stdout_file.writeAll("# Shell completion generation is not implemented yet\n") catch return flash.Error.IOError;
}

fn runInit(allocator: std.mem.Allocator, options: gshell.config.LoadOptions, force: bool) flash.Error!i32 {
    const path = gshell.config.writeDefaultConfig(allocator, options, force) catch |err| switch (err) {
        gshell.config.LoadError.ConfigAlreadyExists => {
            const resolved_path = gshell.config.ensureConfigPath(allocator, options) catch |resolve_err| switch (resolve_err) {
                gshell.config.LoadError.ConfigPathUnavailable => {
                    var stderr_file = std.fs.File.stderr();
                    stderr_file.writeAll("gshell init: unable to determine config path (set HOME or use --config)\n") catch return flash.Error.IOError;
                    return 1;
                },
                else => return mapConfigError(resolve_err),
            };
            defer allocator.free(resolved_path);
            const msg = try std.fmt.allocPrint(allocator, "gshell init: config already exists at {s} (use --force to overwrite)\n", .{resolved_path});
            defer allocator.free(msg);
            var stderr_file = std.fs.File.stderr();
            stderr_file.writeAll(msg) catch return flash.Error.IOError;
            return 1;
        },
        gshell.config.LoadError.ConfigPathUnavailable => {
            var stderr_file = std.fs.File.stderr();
            stderr_file.writeAll("gshell init: unable to determine config path (set HOME or use --config)\n") catch return flash.Error.IOError;
            return 1;
        },
        else => return mapConfigError(err),
    };
    defer allocator.free(path);

    const msg = try std.fmt.allocPrint(allocator, "gshell init: wrote default config to {s}\n", .{path});
    defer allocator.free(msg);
    var stdout_file = std.fs.File.stdout();
    stdout_file.writeAll(msg) catch return flash.Error.IOError;
    return 0;
}

fn normalizeExit(code: i32) u8 {
    if (code < 0) return 255;
    if (code > 255) return 255;
    return @as(u8, @intCast(code));
}

fn mapIoError(err: anyerror) flash.Error {
    return switch (err) {
        error.OutOfMemory => flash.Error.OutOfMemory,
        else => flash.Error.IOError,
    };
}

fn mapConfigError(err: anyerror) flash.Error {
    return switch (err) {
        error.OutOfMemory => flash.Error.OutOfMemory,
        error.ConfigPathUnavailable, error.ConfigAlreadyExists, error.InvalidConfig => flash.Error.ConfigError,
        error.InvalidWtf8, error.EnvironmentVariableNotFound => flash.Error.ConfigError,
        else => flash.Error.IOError,
    };
}

fn mapShellExecError(err: anyerror) flash.Error {
    return switch (err) {
        error.OutOfMemory => flash.Error.OutOfMemory,
        else => flash.Error.AsyncExecutionFailed,
    };
}

fn printUsage() void {
    var stderr_file = std.fs.File.stderr();
    stderr_file.writeAll(
        "Usage:\n  gshell [--config PATH] [-c command]\n  gshell [--config PATH] script.gsh [args...]\n  gshell --init [--config PATH]\n  gshell init [--force] [--config PATH]\n  gshell completions <shell>\n",
    ) catch {};
}

fn reportConfigError(err: anyerror) void {
    var stderr_file = std.fs.File.stderr();
    stderr_file.writeAll("gshell: failed to load configuration: ") catch {};
    stderr_file.writeAll(@errorName(err)) catch {};
    stderr_file.writeAll("\n") catch {};
}
