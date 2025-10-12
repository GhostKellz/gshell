const std = @import("std");
const ghostlang = @import("ghostlang");
const ShellState = @import("state.zig").ShellState;
const PromptEngine = @import("prompt.zig").PromptEngine;
const Executor = @import("executor.zig");
const log = @import("logging.zig");

pub const ScriptingError = error{
    EngineInitFailed,
    ScriptLoadFailed,
    ScriptExecutionFailed,
    FunctionRegistrationFailed,
};

/// Wrapper around Ghostlang script engine for shell integration
pub const ScriptEngine = struct {
    allocator: std.mem.Allocator,
    engine: ghostlang.ScriptEngine,
    state: *ShellState,
    prompt_engine: ?*PromptEngine = null,

    pub fn init(allocator: std.mem.Allocator, state: *ShellState) !ScriptEngine {
        // Security: Configure Ghostlang with sandbox limits
        const config = ghostlang.EngineConfig{
            .allocator = allocator,
            .memory_limit = 50 * 1024 * 1024, // 50MB max per script (prevents DoS)
            .execution_timeout_ms = 5000, // 5 second timeout (prevents infinite loops)
            // allow_io defaults to true (needed for shell scripts)
            // allow_syscalls defaults to false (blocked for security)
            // deterministic defaults to false (allow time functions)
        };

        const engine = ghostlang.ScriptEngine.create(config) catch {
            return ScriptingError.EngineInitFailed;
        };

        var self = ScriptEngine{
            .allocator = allocator,
            .engine = engine,
            .state = state,
        };

        // Register shell API functions
        try self.registerShellAPI();

        return self;
    }

    pub fn deinit(self: *ScriptEngine) void {
        self.engine.deinit();
    }

    pub fn setPromptEngine(self: *ScriptEngine, prompt_engine: *PromptEngine) void {
        self.prompt_engine = prompt_engine;
    }

    /// Execute a .gza script file
    pub fn executeFile(self: *ScriptEngine, path: []const u8) !void {
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            std.debug.print("[ERROR] Failed to open script file '{s}': {}\n", .{ path, err });
            return ScriptingError.ScriptLoadFailed;
        };
        defer file.close();

        const stat = file.stat() catch |err| {
            std.debug.print("[ERROR] Failed to stat script file '{s}': {}\n", .{ path, err });
            return ScriptingError.ScriptLoadFailed;
        };

        const content = self.allocator.alloc(u8, stat.size) catch |err| {
            std.debug.print("[ERROR] Failed to allocate memory for script '{s}': {}\n", .{ path, err });
            return ScriptingError.ScriptLoadFailed;
        };
        defer self.allocator.free(content);

        _ = file.readAll(content) catch |err| {
            std.debug.print("[ERROR] Failed to read script file '{s}': {}\n", .{ path, err });
            return ScriptingError.ScriptLoadFailed;
        };

        self.executeString(content) catch |err| {
            std.debug.print("[ERROR] Failed to execute script '{s}': {}\n", .{ path, err });
            return err;
        };
    }

    /// Execute a Ghostlang script string
    pub fn executeString(self: *ScriptEngine, source: []const u8) !void {
        // Set global context for FFI functions
        const old_engine = global_engine;
        global_engine = self;
        defer global_engine = old_engine;

        var script = self.engine.loadScript(source) catch |err| {
            std.debug.print("[ERROR] Failed to parse Ghostlang script: {}\n", .{err});
            std.debug.print("Script content: {s}\n", .{source[0..@min(source.len, 200)]});
            return ScriptingError.ScriptLoadFailed;
        };
        defer script.deinit();

        _ = script.run() catch |err| {
            std.debug.print("[ERROR] Script execution failed: {}\n", .{err});
            return ScriptingError.ScriptExecutionFailed;
        };
    }

    /// Register all shell API functions with the Ghostlang engine
    fn registerShellAPI(self: *ScriptEngine) !void {
        // Core shell functions
        try self.registerFunction("exec", shellExec);
        try self.registerFunction("cd", shellCd);
        try self.registerFunction("getenv", shellGetEnv);
        try self.registerFunction("setenv", shellSetEnv);
        try self.registerFunction("print", shellPrint);
        try self.registerFunction("error", shellError);

        // Shell configuration
        try self.registerFunction("alias", shellAlias);
        try self.registerFunction("use_starship", shellUseStarship);

        // File operations
        try self.registerFunction("path_exists", shellPathExists);
        try self.registerFunction("read_file", shellReadFile);
        try self.registerFunction("write_file", shellWriteFile);

        // Utility functions
        try self.registerFunction("command_exists", shellCommandExists);

        // Configuration functions
        try self.registerFunction("load_vivid_theme", shellLoadVividTheme);
        try self.registerFunction("enable_plugin", shellEnablePlugin);
        try self.registerFunction("set_history_size", shellSetHistorySize);
        try self.registerFunction("set_history_file", shellSetHistoryFile);

        // Directory/file listing
        try self.registerFunction("list_files", shellListFiles);
        try self.registerFunction("list_dirs", shellListDirs);

        // Git helpers
        try self.registerFunction("git_branch", shellGitBranch);
        try self.registerFunction("git_dirty", shellGitDirty);
        try self.registerFunction("git_repo_root", shellGitRepoRoot);
        try self.registerFunction("in_git_repo", shellInGitRepo);

        // Prompt helpers
        try self.registerFunction("get_user", shellGetUser);
        try self.registerFunction("get_hostname", shellGetHostname);
        try self.registerFunction("get_cwd", shellGetCwd);
        try self.registerFunction("enable_git_prompt", shellEnableGitPrompt);
    }

    fn registerFunction(self: *ScriptEngine, name: []const u8, func: anytype) !void {
        self.engine.registerFunction(name, func) catch {
            return ScriptingError.FunctionRegistrationFailed;
        };
    }
};

// ============================================================================
// Shell API Functions (exposed to Ghostlang)
// ============================================================================

// Global context for FFI functions (not thread-safe, but shells are single-threaded)
var global_engine: ?*ScriptEngine = null;

/// Helper to check if a process exited successfully
fn processExitedClean(term: std.process.Child.Term) bool {
    return switch (term) {
        .Exited => |code| code == 0,
        else => false,
    };
}

/// Execute a shell command from script: shell.exec("ls -la")
fn shellExec(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    if (args.len < 1) return ghostlang.ScriptValue{ .nil = {} };

    const engine = global_engine orelse return ghostlang.ScriptValue{ .boolean = false };

    // Extract command string
    const cmd_str = switch (args[0]) {
        .string => |s| s,
        else => return ghostlang.ScriptValue{ .boolean = false },
    };

    // Parse and execute the command
    const parser_mod = @import("parser.zig");
    const executor_mod = @import("executor.zig");

    const pipeline = parser_mod.parseLine(engine.allocator, cmd_str) catch {
        return ghostlang.ScriptValue{ .boolean = false };
    };
    defer pipeline.deinit(engine.allocator);

    _ = executor_mod.runPipeline(engine.allocator, engine.state, pipeline) catch {
        return ghostlang.ScriptValue{ .boolean = false };
    };

    return ghostlang.ScriptValue{ .boolean = true };
}

/// Change directory: shell.cd("/tmp")
fn shellCd(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    if (args.len < 1) return ghostlang.ScriptValue{ .nil = {} };

    const engine = global_engine orelse return ghostlang.ScriptValue{ .boolean = false };

    const path_str = switch (args[0]) {
        .string => |s| s,
        else => return ghostlang.ScriptValue{ .boolean = false },
    };

    var path_z = engine.allocator.allocSentinel(u8, path_str.len, 0) catch {
        return ghostlang.ScriptValue{ .boolean = false };
    };
    defer engine.allocator.free(path_z);
    std.mem.copyForwards(u8, path_z[0..path_str.len], path_str);

    std.posix.chdir(path_z) catch {
        return ghostlang.ScriptValue{ .boolean = false };
    };

    return ghostlang.ScriptValue{ .boolean = true };
}

/// Get environment variable: shell.getenv("PATH")
fn shellGetEnv(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    if (args.len < 1) return ghostlang.ScriptValue{ .nil = {} };

    const engine = global_engine orelse return ghostlang.ScriptValue{ .nil = {} };

    const key_str = switch (args[0]) {
        .string => |s| s,
        else => return ghostlang.ScriptValue{ .nil = {} },
    };

    if (engine.state.getEnv(key_str)) |value| {
        return ghostlang.ScriptValue{ .string = value };
    }

    return ghostlang.ScriptValue{ .nil = {} };
}

/// Set environment variable: shell.setenv("EDITOR", "vim")
fn shellSetEnv(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    if (args.len < 2) return ghostlang.ScriptValue{ .nil = {} };

    const engine = global_engine orelse return ghostlang.ScriptValue{ .boolean = false };

    const key_str = switch (args[0]) {
        .string => |s| s,
        else => return ghostlang.ScriptValue{ .boolean = false },
    };

    const value_str = switch (args[1]) {
        .string => |s| s,
        else => return ghostlang.ScriptValue{ .boolean = false },
    };

    engine.state.setEnv(key_str, value_str) catch {
        return ghostlang.ScriptValue{ .boolean = false };
    };

    return ghostlang.ScriptValue{ .boolean = true };
}

/// Print to stdout: shell.print("hello")
fn shellPrint(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    var stdout_file = std.fs.File{ .handle = std.posix.STDOUT_FILENO };
    for (args) |arg| {
        // Simple print - just convert to string representation
        switch (arg) {
            .nil => stdout_file.writeAll("nil\n") catch {},
            .boolean => |b| {
                if (b) {
                    stdout_file.writeAll("true\n") catch {};
                } else {
                    stdout_file.writeAll("false\n") catch {};
                }
            },
            .number => |n| {
                var buf: [64]u8 = undefined;
                const formatted = std.fmt.bufPrint(&buf, "{d}\n", .{n}) catch "NaN\n";
                stdout_file.writeAll(formatted) catch {};
            },
            .string => |s| {
                stdout_file.writeAll(s) catch {};
                stdout_file.writeAll("\n") catch {};
            },
            .function => stdout_file.writeAll("[function]\n") catch {},
            .native_function => stdout_file.writeAll("[native_function]\n") catch {},
            .table => stdout_file.writeAll("[table]\n") catch {},
            .array => stdout_file.writeAll("[array]\n") catch {},
            .script_function => stdout_file.writeAll("[script_function]\n") catch {},
            .iterator => stdout_file.writeAll("[iterator]\n") catch {},
            .upvalue => stdout_file.writeAll("[upvalue]\n") catch {},
        }
    }
    return ghostlang.ScriptValue{ .nil = {} };
}

/// Print error: shell.error("Something went wrong")
fn shellError(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    var stderr_file = std.fs.File{ .handle = std.posix.STDERR_FILENO };
    stderr_file.writeAll("Error: ") catch {};
    for (args) |arg| {
        switch (arg) {
            .nil => stderr_file.writeAll("nil") catch {},
            .boolean => |b| {
                if (b) {
                    stderr_file.writeAll("true") catch {};
                } else {
                    stderr_file.writeAll("false") catch {};
                }
            },
            .number => |n| {
                var buf: [64]u8 = undefined;
                const formatted = std.fmt.bufPrint(&buf, "{d}", .{n}) catch "NaN";
                stderr_file.writeAll(formatted) catch {};
            },
            .string => |s| stderr_file.writeAll(s) catch {},
            .function => stderr_file.writeAll("[function]") catch {},
            .native_function => stderr_file.writeAll("[native_function]") catch {},
            .table => stderr_file.writeAll("[table]") catch {},
            .array => stderr_file.writeAll("[array]") catch {},
            .script_function => stderr_file.writeAll("[script_function]") catch {},
            .iterator => stderr_file.writeAll("[iterator]") catch {},
            .upvalue => stderr_file.writeAll("[upvalue]") catch {},
        }
    }
    stderr_file.writeAll("\n") catch {};
    return ghostlang.ScriptValue{ .nil = {} };
}

/// Create or update an alias: shell.alias("ll", "ls -la")
fn shellAlias(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    if (args.len < 2) return ghostlang.ScriptValue{ .boolean = false };

    const engine = global_engine orelse return ghostlang.ScriptValue{ .boolean = false };

    const name_str = switch (args[0]) {
        .string => |s| s,
        else => return ghostlang.ScriptValue{ .boolean = false },
    };

    const value_str = switch (args[1]) {
        .string => |s| s,
        else => return ghostlang.ScriptValue{ .boolean = false },
    };

    engine.state.setAlias(name_str, value_str) catch {
        return ghostlang.ScriptValue{ .boolean = false };
    };

    return ghostlang.ScriptValue{ .boolean = true };
}

/// Enable/disable Starship prompt: shell.use_starship(true)
fn shellUseStarship(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    if (args.len < 1) return ghostlang.ScriptValue{ .boolean = false };

    const engine = global_engine orelse return ghostlang.ScriptValue{ .boolean = false };

    const enable = switch (args[0]) {
        .boolean => |b| b,
        else => return ghostlang.ScriptValue{ .boolean = false },
    };

    // Set Starship usage on the prompt engine
    if (engine.prompt_engine) |prompt_eng| {
        prompt_eng.setUseStarship(enable);
        return ghostlang.ScriptValue{ .boolean = true };
    }

    return ghostlang.ScriptValue{ .boolean = false };
}

/// Check if a path exists: shell.path_exists("/tmp/file.txt")
fn shellPathExists(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    if (args.len < 1) return ghostlang.ScriptValue{ .boolean = false };

    const path_str = switch (args[0]) {
        .string => |s| s,
        else => return ghostlang.ScriptValue{ .boolean = false },
    };

    std.fs.cwd().access(path_str, .{}) catch {
        return ghostlang.ScriptValue{ .boolean = false };
    };

    return ghostlang.ScriptValue{ .boolean = true };
}

/// Read file contents: shell.read_file("/tmp/file.txt")
fn shellReadFile(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    if (args.len < 1) return ghostlang.ScriptValue{ .nil = {} };

    const engine = global_engine orelse return ghostlang.ScriptValue{ .nil = {} };

    const path_str = switch (args[0]) {
        .string => |s| s,
        else => return ghostlang.ScriptValue{ .nil = {} },
    };

    const file = std.fs.cwd().openFile(path_str, .{}) catch {
        return ghostlang.ScriptValue{ .nil = {} };
    };
    defer file.close();

    const stat = file.stat() catch {
        return ghostlang.ScriptValue{ .nil = {} };
    };

    const content = engine.allocator.alloc(u8, stat.size) catch {
        return ghostlang.ScriptValue{ .nil = {} };
    };
    // Note: This leaks memory - Ghostlang should own the string
    // TODO: Use Ghostlang's string allocation when available

    _ = file.readAll(content) catch {
        engine.allocator.free(content);
        return ghostlang.ScriptValue{ .nil = {} };
    };

    return ghostlang.ScriptValue{ .string = content };
}

/// Write file contents: shell.write_file("/tmp/file.txt", "content")
fn shellWriteFile(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    if (args.len < 2) return ghostlang.ScriptValue{ .boolean = false };

    const path_str = switch (args[0]) {
        .string => |s| s,
        else => return ghostlang.ScriptValue{ .boolean = false },
    };

    const content_str = switch (args[1]) {
        .string => |s| s,
        else => return ghostlang.ScriptValue{ .boolean = false },
    };

    const file = std.fs.cwd().createFile(path_str, .{}) catch {
        return ghostlang.ScriptValue{ .boolean = false };
    };
    defer file.close();

    file.writeAll(content_str) catch {
        return ghostlang.ScriptValue{ .boolean = false };
    };

    return ghostlang.ScriptValue{ .boolean = true };
}

/// Check if a command exists in PATH: command_exists("git")
fn shellCommandExists(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    if (args.len < 1) return ghostlang.ScriptValue{ .boolean = false };

    const cmd_str = switch (args[0]) {
        .string => |s| s,
        else => return ghostlang.ScriptValue{ .boolean = false },
    };

    const engine = global_engine orelse return ghostlang.ScriptValue{ .boolean = false };

    // Use 'which' command to check existence
    var buf: [256]u8 = undefined;
    const check_cmd = std.fmt.bufPrint(&buf, "which {s} >/dev/null 2>&1", .{cmd_str}) catch {
        return ghostlang.ScriptValue{ .boolean = false };
    };

    const result = std.process.Child.run(.{
        .allocator = engine.allocator,
        .argv = &[_][]const u8{ "sh", "-c", check_cmd },
    }) catch {
        return ghostlang.ScriptValue{ .boolean = false };
    };
    defer engine.allocator.free(result.stdout);
    defer engine.allocator.free(result.stderr);

    return ghostlang.ScriptValue{ .boolean = processExitedClean(result.term) };
}

/// Load a vivid theme: load_vivid_theme("ghost-hacker-blue")
fn shellLoadVividTheme(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    if (args.len < 1) return ghostlang.ScriptValue{ .boolean = false };

    const theme_name = switch (args[0]) {
        .string => |s| s,
        else => return ghostlang.ScriptValue{ .boolean = false },
    };

    const engine = global_engine orelse return ghostlang.ScriptValue{ .boolean = false };

    // Run: vivid generate <theme>
    const result = std.process.Child.run(.{
        .allocator = engine.allocator,
        .argv = &[_][]const u8{ "vivid", "generate", theme_name },
    }) catch {
        return ghostlang.ScriptValue{ .boolean = false };
    };
    defer engine.allocator.free(result.stderr);

    if (!processExitedClean(result.term)) {
        engine.allocator.free(result.stdout);
        return ghostlang.ScriptValue{ .boolean = false };
    }

    // Set LS_COLORS environment variable
    const ls_colors = std.mem.trimRight(u8, result.stdout, "\n");

    // Dupe the string so we own it after freeing stdout
    const owned_ls_colors = engine.allocator.dupe(u8, ls_colors) catch {
        engine.allocator.free(result.stdout);
        return ghostlang.ScriptValue{ .boolean = false };
    };

    engine.allocator.free(result.stdout);

    engine.state.setEnv("LS_COLORS", owned_ls_colors) catch {
        engine.allocator.free(owned_ls_colors);
        return ghostlang.ScriptValue{ .boolean = false };
    };

    return ghostlang.ScriptValue{ .boolean = true };
}

/// Enable a plugin: enable_plugin("git")
fn shellEnablePlugin(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    if (args.len < 1) return ghostlang.ScriptValue{ .boolean = false };

    const engine = global_engine orelse return ghostlang.ScriptValue{ .boolean = false };

    // For each argument, try to load that plugin
    for (args) |arg| {
        const plugin_name = switch (arg) {
            .string => |s| s,
            else => continue,
        };

        // Try to load from assets/plugins/<name>/plugin.gza
        var buf: [512]u8 = undefined;
        const plugin_path = std.fmt.bufPrint(&buf, "assets/plugins/{s}/plugin.gza", .{plugin_name}) catch continue;

        // Execute the plugin script
        engine.executeFile(plugin_path) catch {
            // If not in assets, try ~/.config/gshell/plugins/
            const home = std.posix.getenv("HOME") orelse continue;
            const user_plugin_path = std.fmt.bufPrint(&buf, "{s}/.config/gshell/plugins/{s}/plugin.gza", .{ home, plugin_name }) catch continue;
            engine.executeFile(user_plugin_path) catch continue;
        };
    }

    return ghostlang.ScriptValue{ .boolean = true };
}

/// Set history size: set_history_size(10000)
fn shellSetHistorySize(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    if (args.len < 1) return ghostlang.ScriptValue{ .boolean = false };

    _ = switch (args[0]) {
        .number => |n| @as(usize, @intFromFloat(n)),
        else => return ghostlang.ScriptValue{ .boolean = false },
    };

    // TODO: Implement history management
    // For now, just accept the call as a no-op
    return ghostlang.ScriptValue{ .boolean = true };
}

/// Set history file path: set_history_file("~/.gshell_history")
fn shellSetHistoryFile(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    if (args.len < 1) return ghostlang.ScriptValue{ .boolean = false };

    _ = switch (args[0]) {
        .string => |s| s,
        else => return ghostlang.ScriptValue{ .boolean = false },
    };

    // TODO: Implement history file configuration
    // For now, just accept the call as a no-op
    return ghostlang.ScriptValue{ .boolean = true };
}

/// List files in directory: list_files("/path", "*.txt")
fn shellListFiles(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    if (args.len < 1) return ghostlang.ScriptValue{ .nil = {} };

    const dir_path = switch (args[0]) {
        .string => |s| s,
        else => return ghostlang.ScriptValue{ .nil = {} },
    };

    const pattern = if (args.len >= 2) switch (args[1]) {
        .string => |s| s,
        else => "*",
    } else "*";

    _ = pattern; // TODO: implement pattern matching

    const engine = global_engine orelse return ghostlang.ScriptValue{ .nil = {} };

    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch {
        return ghostlang.ScriptValue{ .nil = {} };
    };
    defer dir.close();

    var iter = dir.iterate();
    var result = std.ArrayList([]const u8){};

    while (iter.next() catch null) |entry| {
        if (entry.kind == .file) {
            const name = engine.allocator.dupe(u8, entry.name) catch continue;
            result.append(engine.allocator, name) catch continue;
        }
    }

    // Convert to ghostlang array (simplified - return first file for now)
    if (result.items.len > 0) {
        const first = result.items[0];
        for (result.items[1..]) |item| engine.allocator.free(item);
        result.deinit(engine.allocator);
        return ghostlang.ScriptValue{ .string = first };
    }

    result.deinit(engine.allocator);
    return ghostlang.ScriptValue{ .nil = {} };
}

/// List directories: list_dirs("/path")
fn shellListDirs(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    if (args.len < 1) return ghostlang.ScriptValue{ .nil = {} };

    const dir_path = switch (args[0]) {
        .string => |s| s,
        else => return ghostlang.ScriptValue{ .nil = {} },
    };

    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch {
        return ghostlang.ScriptValue{ .nil = {} };
    };
    defer dir.close();

    var iter = dir.iterate();
    var count: usize = 0;

    while (iter.next() catch null) |entry| {
        if (entry.kind == .directory) {
            count += 1;
        }
    }

    return ghostlang.ScriptValue{ .number = @floatFromInt(count) };
}

/// Get current git branch: git_branch()
fn shellGitBranch(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    _ = args;

    const engine = global_engine orelse return ghostlang.ScriptValue{ .nil = {} };

    const result = std.process.Child.run(.{
        .allocator = engine.allocator,
        .argv = &[_][]const u8{ "git", "branch", "--show-current" },
    }) catch {
        return ghostlang.ScriptValue{ .nil = {} };
    };
    defer engine.allocator.free(result.stderr);

    if (!processExitedClean(result.term)) {
        engine.allocator.free(result.stdout);
        return ghostlang.ScriptValue{ .nil = {} };
    }

    const branch = std.mem.trim(u8, result.stdout, "\n\r\t ");
    const owned = engine.allocator.dupe(u8, branch) catch {
        engine.allocator.free(result.stdout);
        return ghostlang.ScriptValue{ .nil = {} };
    };

    engine.allocator.free(result.stdout);
    return ghostlang.ScriptValue{ .string = owned };
}

/// Check if git repo is dirty: git_dirty()
fn shellGitDirty(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    _ = args;

    const engine = global_engine orelse return ghostlang.ScriptValue{ .boolean = false };

    const result = std.process.Child.run(.{
        .allocator = engine.allocator,
        .argv = &[_][]const u8{ "git", "status", "--porcelain" },
    }) catch {
        return ghostlang.ScriptValue{ .boolean = false };
    };
    defer engine.allocator.free(result.stderr);
    defer engine.allocator.free(result.stdout);

    if (result.term.Exited != 0) {
        return ghostlang.ScriptValue{ .boolean = false };
    }

    const is_dirty = std.mem.trim(u8, result.stdout, "\n\r\t ").len > 0;
    return ghostlang.ScriptValue{ .boolean = is_dirty };
}

/// Get git repository root: git_repo_root()
fn shellGitRepoRoot(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    _ = args;

    const engine = global_engine orelse return ghostlang.ScriptValue{ .nil = {} };

    const result = std.process.Child.run(.{
        .allocator = engine.allocator,
        .argv = &[_][]const u8{ "git", "rev-parse", "--show-toplevel" },
    }) catch {
        return ghostlang.ScriptValue{ .nil = {} };
    };
    defer engine.allocator.free(result.stderr);

    if (!processExitedClean(result.term)) {
        engine.allocator.free(result.stdout);
        return ghostlang.ScriptValue{ .nil = {} };
    }

    const root = std.mem.trim(u8, result.stdout, "\n\r\t ");
    const owned = engine.allocator.dupe(u8, root) catch {
        engine.allocator.free(result.stdout);
        return ghostlang.ScriptValue{ .nil = {} };
    };

    engine.allocator.free(result.stdout);
    return ghostlang.ScriptValue{ .string = owned };
}

/// Check if in git repository: in_git_repo()
fn shellInGitRepo(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    _ = args;

    const engine = global_engine orelse return ghostlang.ScriptValue{ .boolean = false };

    const result = std.process.Child.run(.{
        .allocator = engine.allocator,
        .argv = &[_][]const u8{ "git", "rev-parse", "--git-dir" },
    }) catch {
        return ghostlang.ScriptValue{ .boolean = false };
    };
    defer engine.allocator.free(result.stdout);
    defer engine.allocator.free(result.stderr);

    return ghostlang.ScriptValue{ .boolean = processExitedClean(result.term) };
}

/// Get current username: get_user()
fn shellGetUser(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    _ = args;

    const engine = global_engine orelse return ghostlang.ScriptValue{ .nil = {} };

    const user = std.posix.getenv("USER") orelse return ghostlang.ScriptValue{ .nil = {} };
    const owned = engine.allocator.dupe(u8, user) catch {
        return ghostlang.ScriptValue{ .nil = {} };
    };

    return ghostlang.ScriptValue{ .string = owned };
}

/// Get hostname: get_hostname()
fn shellGetHostname(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    _ = args;

    const engine = global_engine orelse return ghostlang.ScriptValue{ .nil = {} };

    var buf: [64]u8 = undefined;
    const hostname = std.posix.gethostname(&buf) catch {
        return ghostlang.ScriptValue{ .nil = {} };
    };

    const owned = engine.allocator.dupe(u8, hostname) catch {
        return ghostlang.ScriptValue{ .nil = {} };
    };

    return ghostlang.ScriptValue{ .string = owned };
}

/// Get current working directory: get_cwd()
fn shellGetCwd(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    _ = args;

    const engine = global_engine orelse return ghostlang.ScriptValue{ .nil = {} };

    const cwd = std.fs.cwd().realpathAlloc(engine.allocator, ".") catch {
        return ghostlang.ScriptValue{ .nil = {} };
    };

    return ghostlang.ScriptValue{ .string = cwd };
}

/// Enable git prompt segment: enable_git_prompt()
fn shellEnableGitPrompt(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    _ = args;

    const engine = global_engine orelse return ghostlang.ScriptValue{ .boolean = false };

    // Add git segment to the prompt engine
    if (engine.prompt_engine) |prompt_eng| {
        prompt_eng.addGitSegment(.left) catch {
            return ghostlang.ScriptValue{ .boolean = false };
        };
        return ghostlang.ScriptValue{ .boolean = true };
    }

    return ghostlang.ScriptValue{ .boolean = false };
}

test "scripting engine initialization" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var state = try ShellState.init(allocator);
    defer state.deinit();

    var engine = try ScriptEngine.init(allocator, &state);
    defer engine.deinit();
}

test "execute simple script" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var state = try ShellState.init(allocator);
    defer state.deinit();

    var engine = try ScriptEngine.init(allocator, &state);
    defer engine.deinit();

    // Simple arithmetic
    try engine.executeString("3 + 4");
}
