const std = @import("std");
const gcode = @import("gcode");
const parser = @import("parser.zig");
const executor = @import("executor.zig");
const state = @import("state.zig");
const config_mod = @import("config.zig");
const prompt_mod = @import("prompt.zig");
const scripting = @import("scripting.zig");
const completion_mod = @import("completion.zig");
const history_mod = @import("history.zig");
const setup_mod = @import("setup.zig");
const permissions = @import("permissions.zig");

const posix = std.posix;
var sigint_flag = std.atomic.Value(bool).init(false);
var sigtstp_flag = std.atomic.Value(bool).init(false);
var sigchld_flag = std.atomic.Value(bool).init(false);
const MAX_LINE_BYTES: usize = 1 << 16;

fn signalHandler(sig: c_int) callconv(.c) void {
    if (sig == posix.SIG.INT) {
        sigint_flag.store(true, .seq_cst);
    } else if (sig == posix.SIG.TSTP) {
        sigtstp_flag.store(true, .seq_cst);
    } else if (sig == posix.SIG.CHLD) {
        sigchld_flag.store(true, .seq_cst);
    }
}

pub const Shell = struct {
    allocator: std.mem.Allocator,
    config: config_mod.ShellConfig,
    state: state.ShellState,
    handlers_installed: bool = false,
    raw_mode_enabled: bool = false,
    termios_backup: posix.termios = undefined,
    has_termios_backup: bool = false,
    prompt_engine: prompt_mod.PromptEngine,
    history_buffer: std.ArrayListUnmanaged([]const u8) = .{},
    history_index: ?usize = null,
    history_store: ?history_mod.HistoryStore = null,
    script_engine: ?scripting.ScriptEngine = null,
    completion_engine: completion_mod.CompletionEngine,

    pub fn init(allocator: std.mem.Allocator, config: config_mod.ShellConfig) !Shell {
        // Check for first run and setup
        const is_first_run = setup_mod.isFirstRun(allocator) catch false;
        if (is_first_run) {
            setup_mod.runFirstTimeSetup(allocator) catch |err| {
                std.debug.print("Warning: First-time setup failed: {s}\n", .{@errorName(err)});
            };
        }

        var prompt_engine = prompt_mod.PromptEngine.init(allocator);
        prompt_engine.setUseStarship(config.use_starship);
        try prompt_engine.addSegment("${user}@${host} ", .left);
        try prompt_engine.addSegment("${cwd} ", .left);
        try prompt_engine.addSegment("› ", .left);

        var shell_state = try state.ShellState.init(allocator);
        var script_engine = scripting.ScriptEngine.init(allocator, &shell_state) catch null;
        const completion_engine = completion_mod.CompletionEngine.init(allocator);

        // Initialize persistent history with permission checks
        const home = std.posix.getenv("HOME") orelse ".";
        const history_path = std.fmt.allocPrint(allocator, "{s}/.gshell_history", .{home}) catch null;
        var history_store: ?history_mod.HistoryStore = null;
        if (history_path) |path| {
            defer allocator.free(path);

            // Security: Check and fix history file permissions (should be 600)
            permissions.ensureSecureFile(allocator, path, true) catch |err| {
                std.debug.print("Warning: Could not secure history file permissions: {s}\n", .{@errorName(err)});
            };

            history_store = history_mod.HistoryStore.init(allocator, path) catch null;
        }

        // Give script engine access to prompt engine for use_starship()
        if (script_engine) |*engine| {
            engine.setPromptEngine(&prompt_engine);
        }

        return Shell{
            .allocator = allocator,
            .config = config,
            .state = shell_state,
            .prompt_engine = prompt_engine,
            .history_store = history_store,
            .script_engine = script_engine,
            .completion_engine = completion_engine,
        };
    }

    pub fn deinit(self: *Shell) void {
        for (self.history_buffer.items) |item| {
            self.allocator.free(item);
        }
        self.history_buffer.deinit(self.allocator);

        // Flush and close history store
        if (self.history_store) |*store| {
            store.flush() catch {};
            store.deinit();
        }

        self.prompt_engine.deinit();
        if (self.script_engine) |*engine| {
            engine.deinit();
        }
        self.completion_engine.deinit();
        self.state.deinit();
        if (self.handlers_installed) {
            self.restoreDefaultSignals() catch {};
        }
        if (self.raw_mode_enabled) {
            self.disableRawMode(std.posix.STDIN_FILENO);
        }
    }

    fn loadGshrc(self: *Shell) !void {
        // Get home directory
        const home = std.posix.getenv("HOME") orelse return error.NoHomeDir;

        // Build path to .gshrc.gza (Ghostlang config)
        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const gshrc_path = try std.fmt.bufPrint(&path_buf, "{s}/.gshrc.gza", .{home});

        // Check if file exists
        std.fs.cwd().access(gshrc_path, .{}) catch {
            // Try legacy .gshrc (without .gza extension)
            const legacy_path = try std.fmt.bufPrint(&path_buf, "{s}/.gshrc", .{home});
            std.fs.cwd().access(legacy_path, .{}) catch {
                // Neither file exists, that's ok
                return;
            };
            // Use legacy path if it exists
            const final_path = legacy_path;
            if (self.script_engine) |*engine| {
                engine.executeFile(final_path) catch |err| {
                    std.log.warn("gshell: error executing {s}: {s}", .{ final_path, @errorName(err) });
                    return err;
                };
            }
            return;
        };

        // Execute the .gshrc.gza file if we have a script engine
        if (self.script_engine) |*engine| {
            engine.executeFile(gshrc_path) catch |err| {
                std.log.warn("gshell: error executing .gshrc.gza: {s}", .{@errorName(err)});
                return err;
            };
        }
    }

    pub fn runInteractive(self: *Shell) !i32 {
        try self.installSignalHandlers();
        defer self.restoreDefaultSignals() catch {};

        var stdin_file = std.fs.File{ .handle = std.posix.STDIN_FILENO };
        var stdout_file = std.fs.File{ .handle = std.posix.STDOUT_FILENO };
        var stderr_file = std.fs.File{ .handle = std.posix.STDERR_FILENO };

        const is_tty = stdin_file.isTty() and stdout_file.isTty();

        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        var exit_status: i32 = 0;

        var using_raw_mode = false;
        if (self.config.interactive and is_tty) {
            self.enableRawMode(stdin_file.handle) catch |err| {
                std.log.warn("gshell: failed to enable raw mode: {s}", .{@errorName(err)});
            };
            using_raw_mode = self.raw_mode_enabled;
        }
        defer {
            if (using_raw_mode) {
                self.disableRawMode(stdin_file.handle);
            }
        }

        // Load .gshrc if it exists
        self.loadGshrc() catch |err| {
            std.log.warn("gshell: failed to load .gshrc: {s}", .{@errorName(err)});
        };

        while (!self.state.should_exit) {
            _ = arena.reset(.retain_capacity);

            if (sigchld_flag.swap(false, .seq_cst)) {
                self.reapJobs();
            }

            const cwd = std.fs.cwd().realpathAlloc(arena.allocator(), ".") catch ".";
            const user = std.posix.getenv("USER") orelse "user";
            const host = std.posix.getenv("HOSTNAME") orelse "localhost";

            const prompt_ctx = prompt_mod.PromptContext{
                .allocator = arena.allocator(),
                .user = user,
                .host = host,
                .cwd = cwd,
                .exit_code = exit_status,
                .shell_state = &self.state,
            };

            const rendered_prompt = self.prompt_engine.render(prompt_ctx, 80) catch self.config.prompt;

            var maybe_line: ?[]const u8 = null;

            if (using_raw_mode) {
                maybe_line = self.readLineInteractiveWithHistory(
                    arena.allocator(),
                    &stdin_file,
                    &stdout_file,
                    rendered_prompt,
                    MAX_LINE_BYTES,
                ) catch |err| switch (err) {
                    error.OperationAborted => {
                        if (sigint_flag.swap(false, .seq_cst)) {
                            try stdout_file.writeAll("\r\n");
                        }
                        self.history_index = null;
                        continue;
                    },
                    error.LineTooLong => {
                        try stdout_file.writeAll("\r\n");
                        try stderr_file.writeAll("error: input line too long\n");
                        self.history_index = null;
                        continue;
                    },
                    else => return err,
                };
            } else {
                if (self.config.interactive and is_tty) {
                    try stdout_file.writeAll(self.config.prompt);
                }
                maybe_line = readLineAlloc(arena.allocator(), &stdin_file, MAX_LINE_BYTES) catch |err| switch (err) {
                    error.OperationAborted => {
                        if (sigint_flag.swap(false, .seq_cst)) {
                            try stdout_file.writeAll("\n");
                        }
                        continue;
                    },
                    error.LineTooLong => {
                        try stderr_file.writeAll("error: input line too long\n");
                        continue;
                    },
                    else => return err,
                };
            }

            if (sigint_flag.swap(false, .seq_cst)) {
                if (using_raw_mode) {
                    try stdout_file.writeAll("\r\n");
                } else {
                    try stdout_file.writeAll("\n");
                }
                continue;
            }
            if (sigtstp_flag.swap(false, .seq_cst)) {
                if (using_raw_mode) {
                    try stdout_file.writeAll("\r\n[gshell] job control not implemented yet\n");
                } else {
                    try stdout_file.writeAll("\n[gshell] job control not implemented yet\n");
                }
                continue;
            }

            if (maybe_line == null) break;
            const line = maybe_line.?;
            if (line.len == 0) {
                continue;
            }

            const trimmed = std.mem.trim(u8, line, " \t\r\n");
            if (trimmed.len == 0) {
                continue;
            }

            // Record command in history (deduplicate if same as last entry)
            const should_record = if (self.history_buffer.items.len == 0)
                true
            else
                !std.mem.eql(u8, self.history_buffer.items[self.history_buffer.items.len - 1], trimmed);

            if (should_record) {
                const hist_entry = try self.allocator.dupe(u8, trimmed);
                errdefer self.allocator.free(hist_entry);
                try self.history_buffer.append(self.allocator, hist_entry);
            }

            try self.restoreDefaultSignals();
            const outcome = self.execute(trimmed, arena.allocator()) catch |err| {
                var msg_buf: [128]u8 = undefined;
                const msg = std.fmt.bufPrint(&msg_buf, "error: {s}\n", .{@errorName(err)}) catch "error: unexpected\n";
                try stderr_file.writeAll(msg);
                try self.installSignalHandlers();
                exit_status = 1;
                continue;
            };
            try self.installSignalHandlers();

            exit_status = outcome.status;
            self.state.exit_code = outcome.status;

            // Save to persistent history
            if (self.history_store) |*store| {
                store.append(trimmed, outcome.status) catch {};
            }

            if (outcome.job_id) |job_id| {
                const msg = try std.fmt.allocPrint(arena.allocator(), "[{d}] started\n", .{job_id});
                try stdout_file.writeAll(msg);
            }

            if (outcome.output.len > 0) {
                try stdout_file.writeAll(outcome.output);
                if (outcome.output[outcome.output.len - 1] != '\n') {
                    try stdout_file.writeAll("\n");
                }
            }
        }

        if (self.state.exit_code != 0) return self.state.exit_code;
        return exit_status;
    }

    pub fn runCommand(self: *Shell, command: []const u8) !i32 {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        const trimmed = std.mem.trim(u8, command, " \t\r\n");
        if (trimmed.len == 0) return 0;

        if (self.handlers_installed) try self.restoreDefaultSignals();
        const outcome = try self.execute(trimmed, arena.allocator());
        if (self.handlers_installed) try self.installSignalHandlers();

        self.state.exit_code = outcome.status;
        if (outcome.output.len > 0) {
            var stdout_file = std.fs.File{ .handle = std.posix.STDOUT_FILENO };
            try stdout_file.writeAll(outcome.output);
            if (outcome.output[outcome.output.len - 1] != '\n') {
                try stdout_file.writeAll("\n");
            }
        }

        return outcome.status;
    }

    pub fn runScript(self: *Shell, path: []const u8, args: []const []const u8) !i32 {
        // Check if this is a Ghostlang script (.gza)
        if (std.mem.endsWith(u8, path, ".gza")) {
            return self.runGhostlangScript(path, args);
        }

        // Otherwise, execute as a shell script line by line
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        try self.state.setEnv("0", path);
        for (args, 0..) |arg, idx| {
            var key_buf: [12]u8 = undefined;
            const key = try std.fmt.bufPrint(&key_buf, "{d}", .{idx + 1});
            try self.state.setEnv(key, arg);
        }

        var file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
        defer file.close();

        var exit_status: i32 = 0;

        while (true) {
            _ = arena.reset(.retain_capacity);
            const maybe_line = readLineAlloc(arena.allocator(), &file, MAX_LINE_BYTES) catch |err| switch (err) {
                error.OperationAborted => continue,
                else => return err,
            };
            if (maybe_line == null) break;
            const line = maybe_line.?;

            const trimmed = std.mem.trim(u8, line, " \t\r\n");
            if (trimmed.len == 0 or trimmed[0] == '#') {
                continue;
            }

            const outcome = try self.execute(trimmed, arena.allocator());
            exit_status = outcome.status;
            self.state.exit_code = outcome.status;
            if (self.state.should_exit) break;
        }

        if (self.state.exit_code != 0) return self.state.exit_code;
        return exit_status;
    }

    fn runGhostlangScript(self: *Shell, path: []const u8, args: []const []const u8) !i32 {
        if (self.script_engine) |*engine| {
            // Set up script arguments in environment
            try self.state.setEnv("0", path);
            for (args, 0..) |arg, idx| {
                var key_buf: [12]u8 = undefined;
                const key = try std.fmt.bufPrint(&key_buf, "{d}", .{idx + 1});
                try self.state.setEnv(key, arg);
            }

            // Execute the Ghostlang script
            engine.executeFile(path) catch |err| {
                var stderr_file = std.fs.File{ .handle = std.posix.STDERR_FILENO };
                var buf: [256]u8 = undefined;
                const msg = std.fmt.bufPrint(&buf, "gshell: failed to execute {s}: {}\n", .{ path, err }) catch "gshell: script execution failed\n";
                stderr_file.writeAll(msg) catch {};
                return 1;
            };

            return 0;
        } else {
            var stderr_file = std.fs.File{ .handle = std.posix.STDERR_FILENO };
            stderr_file.writeAll("gshell: Ghostlang engine not initialized\n") catch {};
            return 1;
        }
    }

    fn execute(self: *Shell, line: []const u8, allocator: std.mem.Allocator) !executor.ExecOutcome {
        const pipeline = try parser.parseLine(allocator, line);
        return try executor.runPipeline(allocator, &self.state, pipeline);
    }

    fn installSignalHandlers(self: *Shell) !void {
        var action = posix.Sigaction{
            .handler = .{ .handler = signalHandler },
            .mask = std.mem.zeroes(posix.sigset_t),
            .flags = posix.SA.RESTART, // Automatically restart system calls
        };

        // Install handlers for shell control
        _ = posix.sigaction(posix.SIG.INT, &action, null);
        _ = posix.sigaction(posix.SIG.TSTP, &action, null);
        _ = posix.sigaction(posix.SIG.CHLD, &action, null);

        // Ignore SIGQUIT in shell (Ctrl+\)
        var ignore_action = posix.Sigaction{
            .handler = .{ .handler = posix.SIG.IGN },
            .mask = std.mem.zeroes(posix.sigset_t),
            .flags = 0,
        };
        _ = posix.sigaction(posix.SIG.QUIT, &ignore_action, null);

        self.handlers_installed = true;
    }

    fn restoreDefaultSignals(self: *Shell) !void {
        var action = posix.Sigaction{
            .handler = .{ .handler = posix.SIG.DFL },
            .mask = std.mem.zeroes(posix.sigset_t),
            .flags = 0,
        };
        _ = posix.sigaction(posix.SIG.INT, &action, null);
        _ = posix.sigaction(posix.SIG.TSTP, &action, null);
        _ = posix.sigaction(posix.SIG.CHLD, &action, null);
        _ = posix.sigaction(posix.SIG.QUIT, &action, null);
        self.handlers_installed = false;
    }

    fn reapJobs(self: *Shell) void {
        while (true) {
            // Use syscall directly to handle ECHILD gracefully
            var status: u32 = undefined;
            const rc = std.os.linux.syscall4(
                .wait4,
                @as(usize, @bitCast(@as(isize, -1))), // pid = -1
                @intFromPtr(&status),
                std.posix.W.NOHANG,
                0, // rusage = NULL
            );

            // Check for errors
            if (@as(isize, @bitCast(rc)) < 0) {
                // ECHILD or other error - no more children
                break;
            }

            const pid: i32 = @intCast(@as(isize, @bitCast(rc)));

            // No more children to reap right now
            if (pid == 0) break;

            if (self.state.getJobByPid(pid)) |job| {
                if (std.posix.W.IFEXITED(status) or std.posix.W.IFSIGNALED(status)) {
                    job.status = .done;
                }
            }
        }
    }

    fn enableRawMode(self: *Shell, fd: posix.fd_t) !void {
        if (self.raw_mode_enabled) return;

        const current = try posix.tcgetattr(fd);
        self.termios_backup = current;
        self.has_termios_backup = true;

        var raw = current;
        raw.lflag.ICANON = false;
        raw.lflag.ECHO = false;
        raw.iflag.IXON = false;
        raw.iflag.ICRNL = false;
        raw.oflag.OPOST = false;
        const vmin_index: usize = @as(usize, @intCast(@intFromEnum(posix.V.MIN)));
        const vtime_index: usize = @as(usize, @intCast(@intFromEnum(posix.V.TIME)));
        raw.cc[vmin_index] = 1;
        raw.cc[vtime_index] = 0;

        try posix.tcsetattr(fd, posix.TCSA.FLUSH, raw);
        self.raw_mode_enabled = true;
    }

    fn disableRawMode(self: *Shell, fd: posix.fd_t) void {
        if (!self.raw_mode_enabled) return;
        if (self.has_termios_backup) {
            posix.tcsetattr(fd, posix.TCSA.FLUSH, self.termios_backup) catch {};
            self.has_termios_backup = false;
        }
        self.raw_mode_enabled = false;
    }

    fn matchesSearch(haystack: []const u8, needle: []const u8) bool {
        if (needle.len == 0) return true;
        if (needle.len > haystack.len) return false;

        // Simple substring search (case-insensitive)
        var i: usize = 0;
        while (i + needle.len <= haystack.len) : (i += 1) {
            var match = true;
            for (needle, 0..) |ch, j| {
                const hay_ch = haystack[i + j];
                const needle_ch = ch;
                // Case-insensitive comparison
                const hay_lower = if (hay_ch >= 'A' and hay_ch <= 'Z') hay_ch + 32 else hay_ch;
                const needle_lower = if (needle_ch >= 'A' and needle_ch <= 'Z') needle_ch + 32 else needle_ch;
                if (hay_lower != needle_lower) {
                    match = false;
                    break;
                }
            }
            if (match) return true;
        }
        return false;
    }

    fn findSearchMatch(history: *const std.ArrayListUnmanaged([]const u8), query: []const u8, start_from: ?usize) ?usize {
        if (history.items.len == 0) return null;
        if (query.len == 0) {
            return if (start_from) |idx| if (idx > 0) idx - 1 else history.items.len - 1 else history.items.len - 1;
        }

        const start = start_from orelse history.items.len;
        var i = start;
        while (i > 0) {
            i -= 1;
            if (matchesSearch(history.items[i], query)) {
                return i;
            }
        }
        return null;
    }

    fn renderSearchPrompt(
        stdout_file: *std.fs.File,
        query: *const std.ArrayListUnmanaged(u8),
        match_index: ?usize,
        history: *const std.ArrayListUnmanaged([]const u8),
        original_prompt_width: usize,
    ) !void {
        _ = original_prompt_width;

        // Clear current line
        try stdout_file.writeAll("\r\x1b[K");

        // Build search prompt
        var buf: [512]u8 = undefined;
        const matched_cmd = if (match_index) |idx| history.items[idx] else "";

        const search_prompt = if (match_index != null)
            std.fmt.bufPrint(&buf, "(reverse-i-search)`{s}': {s}", .{ query.items, matched_cmd }) catch "(search)"
        else
            std.fmt.bufPrint(&buf, "(failed reverse-i-search)`{s}': ", .{query.items}) catch "(search)";

        try stdout_file.writeAll(search_prompt);
    }

    fn readLineInteractiveWithHistory(
        self: *Shell,
        allocator: std.mem.Allocator,
        stdin_file: *std.fs.File,
        stdout_file: *std.fs.File,
        prompt: []const u8,
        max_len: usize,
    ) ReadLineError!?[]const u8 {
        const fallback_prompt = "gshell> ";
        const prompt_bytes = if (gcode.utf8.validate(prompt)) prompt else fallback_prompt;
        const prompt_width = gcode.stringWidth(prompt_bytes);

        try stdout_file.writeAll(prompt_bytes);

        var buffer = std.ArrayListUnmanaged(u8){};
        defer buffer.deinit(allocator);

        var cursor: usize = 0;
        var rendered_width = prompt_width;

        // Start with no history position (browsing from end)
        var history_pos: ?usize = null;
        // Save the current input when starting to browse history
        var saved_input: ?[]u8 = null;
        defer if (saved_input) |si| allocator.free(si);

        // Incremental search state
        var search_mode = false;
        var search_query = std.ArrayListUnmanaged(u8){};
        defer search_query.deinit(allocator);
        var search_match_index: ?usize = null;

        var byte_buf: [1]u8 = undefined;

        while (true) {
            if (buffer.items.len >= max_len) {
                return error.LineTooLong;
            }

            const bytes_read = stdin_file.read(&byte_buf) catch |err| switch (err) {
                error.OperationAborted => return error.OperationAborted,
                else => return err,
            };

            if (bytes_read == 0) {
                if (buffer.items.len == 0) {
                    return null;
                }
                break;
            }

            const ch = byte_buf[0];

            switch (ch) {
                '\r', '\n' => {
                    if (search_mode) {
                        // Accept search match
                        search_mode = false;
                        if (search_match_index) |idx| {
                            // Replace buffer with matched command
                            buffer.clearRetainingCapacity();
                            try buffer.appendSlice(allocator, self.history_buffer.items[idx]);
                            cursor = buffer.items.len;
                        }
                        search_query.clearRetainingCapacity();
                        search_match_index = null;
                        // Redraw with normal prompt
                        try stdout_file.writeAll("\r\n");
                        try stdout_file.writeAll(prompt_bytes);
                        try stdout_file.writeAll(buffer.items);
                        rendered_width = prompt_width + gcode.stringWidth(buffer.items);
                        continue;
                    }
                    try stdout_file.writeAll("\r\n");
                    break;
                },
                0x04 => { // Ctrl-D
                    if (buffer.items.len == 0) {
                        return null;
                    }
                    continue;
                },
                0x03 => { // Ctrl-C
                    if (search_mode) {
                        // Cancel search, restore to normal mode
                        search_mode = false;
                        search_query.clearRetainingCapacity();
                        search_match_index = null;
                        buffer.clearRetainingCapacity();
                        cursor = 0;
                        // Redraw with normal prompt
                        try stdout_file.writeAll("\r\n");
                        try stdout_file.writeAll(prompt_bytes);
                        rendered_width = prompt_width;
                        continue;
                    }
                    return error.OperationAborted;
                },
                0x09 => { // Tab - completion
                    if (search_mode) continue; // Skip completion in search mode

                    // Get completion results
                    var result = self.completion_engine.complete(buffer.items, cursor) catch continue;
                    defer result.deinit();

                    if (result.matches.items.len == 0) {
                        // No matches - do nothing
                        continue;
                    } else if (result.matches.items.len == 1) {
                        // Single match - auto-complete
                        const match = result.matches.items[0];
                        buffer.clearRetainingCapacity();
                        try buffer.appendSlice(allocator, match);
                        cursor = buffer.items.len;

                        // Redraw line
                        rendered_width = try rewriteInteractiveLine(
                            stdout_file,
                            prompt_bytes,
                            prompt_width,
                            buffer.items,
                            cursor,
                            rendered_width,
                        );
                    } else {
                        // Multiple matches - complete common prefix
                        if (result.common_prefix.len > cursor) {
                            buffer.clearRetainingCapacity();
                            try buffer.appendSlice(allocator, result.common_prefix);
                            cursor = buffer.items.len;

                            // Redraw line
                            rendered_width = try rewriteInteractiveLine(
                                stdout_file,
                                prompt_bytes,
                                prompt_width,
                                buffer.items,
                                cursor,
                                rendered_width,
                            );
                        } else {
                            // Show available matches
                            try stdout_file.writeAll("\r\n");
                            for (result.matches.items, 0..) |match, i| {
                                if (i > 0 and i % 4 == 0) {
                                    try stdout_file.writeAll("\r\n");
                                }
                                try stdout_file.writeAll(match);
                                try stdout_file.writeAll("  ");
                                if (i >= 19) { // Limit to 20 matches shown
                                    try stdout_file.writeAll("...");
                                    break;
                                }
                            }
                            try stdout_file.writeAll("\r\n");

                            // Redraw prompt and current input
                            try stdout_file.writeAll(prompt_bytes);
                            try stdout_file.writeAll(buffer.items);
                            rendered_width = prompt_width + gcode.stringWidth(buffer.items);
                        }
                    }
                    continue;
                },
                0x12 => { // Ctrl-R (reverse incremental search)
                    if (!search_mode) {
                        // Enter search mode
                        search_mode = true;
                        search_query.clearRetainingCapacity();
                        search_match_index = null;

                        // Find first match
                        if (self.history_buffer.items.len > 0) {
                            search_match_index = self.history_buffer.items.len - 1;
                        }

                        // Display search prompt
                        try renderSearchPrompt(stdout_file, &search_query, search_match_index, &self.history_buffer, prompt_width);
                    } else {
                        // Already in search mode - find previous match
                        if (search_match_index) |current_idx| {
                            if (current_idx > 0) {
                                // Search backwards from current position
                                var i = current_idx;
                                while (i > 0) {
                                    i -= 1;
                                    if (matchesSearch(self.history_buffer.items[i], search_query.items)) {
                                        search_match_index = i;
                                        break;
                                    }
                                }
                            }
                        }
                        try renderSearchPrompt(stdout_file, &search_query, search_match_index, &self.history_buffer, prompt_width);
                    }
                    continue;
                },
                0x01 => { // Ctrl-A
                    if (cursor != 0) {
                        cursor = 0;
                        rendered_width = try rewriteInteractiveLine(stdout_file, prompt_bytes, prompt_width, buffer.items, cursor, rendered_width);
                    }
                    continue;
                },
                0x05 => { // Ctrl-E
                    if (cursor != buffer.items.len) {
                        cursor = buffer.items.len;
                        rendered_width = try rewriteInteractiveLine(stdout_file, prompt_bytes, prompt_width, buffer.items, cursor, rendered_width);
                    }
                    continue;
                },
                0x08, 0x7f => { // Backspace / DEL key
                    if (search_mode) {
                        // Remove character from search query
                        if (search_query.items.len > 0) {
                            search_query.shrinkRetainingCapacity(search_query.items.len - 1);
                            // Re-search with new query
                            search_match_index = findSearchMatch(&self.history_buffer, search_query.items, null);
                            try renderSearchPrompt(stdout_file, &search_query, search_match_index, &self.history_buffer, prompt_width);
                        }
                        continue;
                    }
                    if (cursor > 0) {
                        const prev = gcode.findPreviousGrapheme(buffer.items, cursor);
                        const remove_len = cursor - prev;
                        const old_len = buffer.items.len;
                        std.mem.copyForwards(u8, buffer.items[prev .. old_len - remove_len], buffer.items[cursor..old_len]);
                        buffer.shrinkRetainingCapacity(old_len - remove_len);
                        cursor = prev;
                        rendered_width = try rewriteInteractiveLine(stdout_file, prompt_bytes, prompt_width, buffer.items, cursor, rendered_width);
                    }
                    continue;
                },
                0x1b => { // Escape sequences (arrow keys, delete, home/end)
                    var seq_buf: [8]u8 = undefined;
                    var consumed: usize = 0;
                    while (consumed < seq_buf.len) {
                        const r = stdin_file.read(seq_buf[consumed .. consumed + 1]) catch |err| switch (err) {
                            error.OperationAborted => return error.OperationAborted,
                            else => return err,
                        };
                        if (r == 0) break;
                        consumed += r;
                        const last = seq_buf[consumed - 1];
                        if ((last >= 'A' and last <= 'Z') or last == '~') break;
                    }

                    if (consumed >= 2 and seq_buf[0] == '[') {
                        const final = seq_buf[consumed - 1];
                        switch (final) {
                            'A' => { // Up arrow - go back in history
                                if (self.history_buffer.items.len > 0) {
                                    // Save current input if first time browsing history
                                    if (history_pos == null) {
                                        if (saved_input) |si| allocator.free(si);
                                        saved_input = try allocator.dupe(u8, buffer.items);
                                        history_pos = self.history_buffer.items.len;
                                    }

                                    if (history_pos.? > 0) {
                                        history_pos = history_pos.? - 1;
                                        const hist_item = self.history_buffer.items[history_pos.?];

                                        // Clear buffer and replace with history item
                                        buffer.clearRetainingCapacity();
                                        try buffer.appendSlice(allocator, hist_item);
                                        cursor = buffer.items.len;
                                        rendered_width = try rewriteInteractiveLine(stdout_file, prompt_bytes, prompt_width, buffer.items, cursor, rendered_width);
                                    }
                                }
                            },
                            'B' => { // Down arrow - go forward in history
                                if (history_pos) |pos| {
                                    if (pos + 1 < self.history_buffer.items.len) {
                                        history_pos = pos + 1;
                                        const hist_item = self.history_buffer.items[history_pos.?];

                                        // Clear buffer and replace with history item
                                        buffer.clearRetainingCapacity();
                                        try buffer.appendSlice(allocator, hist_item);
                                        cursor = buffer.items.len;
                                        rendered_width = try rewriteInteractiveLine(stdout_file, prompt_bytes, prompt_width, buffer.items, cursor, rendered_width);
                                    } else {
                                        // Reached end of history, restore saved input
                                        history_pos = null;
                                        buffer.clearRetainingCapacity();
                                        if (saved_input) |si| {
                                            try buffer.appendSlice(allocator, si);
                                        }
                                        cursor = buffer.items.len;
                                        rendered_width = try rewriteInteractiveLine(stdout_file, prompt_bytes, prompt_width, buffer.items, cursor, rendered_width);
                                    }
                                }
                            },
                            'C' => { // Right arrow
                                const next = gcode.findNextGrapheme(buffer.items, cursor);
                                if (next != cursor) {
                                    cursor = next;
                                    rendered_width = try rewriteInteractiveLine(stdout_file, prompt_bytes, prompt_width, buffer.items, cursor, rendered_width);
                                }
                            },
                            'D' => { // Left arrow
                                const prev = gcode.findPreviousGrapheme(buffer.items, cursor);
                                if (prev != cursor) {
                                    cursor = prev;
                                    rendered_width = try rewriteInteractiveLine(stdout_file, prompt_bytes, prompt_width, buffer.items, cursor, rendered_width);
                                }
                            },
                            'H' => { // Home
                                if (cursor != 0) {
                                    cursor = 0;
                                    rendered_width = try rewriteInteractiveLine(stdout_file, prompt_bytes, prompt_width, buffer.items, cursor, rendered_width);
                                }
                            },
                            'F' => { // End
                                if (cursor != buffer.items.len) {
                                    cursor = buffer.items.len;
                                    rendered_width = try rewriteInteractiveLine(stdout_file, prompt_bytes, prompt_width, buffer.items, cursor, rendered_width);
                                }
                            },
                            '~' => {
                                if (consumed >= 2 and seq_buf[1] == '3') { // Delete key
                                    if (cursor < buffer.items.len) {
                                        const next = gcode.findNextGrapheme(buffer.items, cursor);
                                        const remove_len = next - cursor;
                                        const old_len = buffer.items.len;
                                        std.mem.copyForwards(u8, buffer.items[cursor .. old_len - remove_len], buffer.items[next..old_len]);
                                        buffer.shrinkRetainingCapacity(old_len - remove_len);
                                        rendered_width = try rewriteInteractiveLine(stdout_file, prompt_bytes, prompt_width, buffer.items, cursor, rendered_width);
                                    }
                                }
                            },
                            else => {},
                        }
                    }
                    continue;
                },
                else => {
                    // Handle search mode character input
                    if (search_mode and ch >= 0x20) {
                        // Add character to search query
                        try search_query.append(allocator, ch);
                        // Find new match
                        search_match_index = findSearchMatch(&self.history_buffer, search_query.items, null);
                        try renderSearchPrompt(stdout_file, &search_query, search_match_index, &self.history_buffer, prompt_width);
                        continue;
                    }

                    // Any other character input resets history browsing
                    if (history_pos != null) {
                        history_pos = null;
                        if (saved_input) |si| {
                            allocator.free(si);
                            saved_input = null;
                        }
                    }
                },
            }

            if (ch < 0x20 and ch != '\t') {
                continue;
            }

            try buffer.append(allocator, 0);
            const new_len = buffer.items.len;
            if (cursor < new_len - 1) {
                std.mem.copyBackwards(u8, buffer.items[cursor + 1 .. new_len], buffer.items[cursor .. new_len - 1]);
            }
            buffer.items[cursor] = ch;
            cursor += 1;
            rendered_width = try rewriteInteractiveLine(stdout_file, prompt_bytes, prompt_width, buffer.items, cursor, rendered_width);
        }

        return try buffer.toOwnedSlice(allocator);
    }
};

const ReadLineError = std.fs.File.ReadError || std.fs.File.WriteError || error{ LineTooLong, OutOfMemory };

fn readLineAlloc(
    allocator: std.mem.Allocator,
    file: *std.fs.File,
    max_len: usize,
) ReadLineError!?[]const u8 {
    var buffer = std.ArrayListUnmanaged(u8){};
    errdefer buffer.deinit(allocator);

    var byte_buf: [1]u8 = undefined;

    while (true) {
        const bytes_read = file.read(&byte_buf) catch |err| switch (err) {
            error.OperationAborted => return error.OperationAborted,
            else => return err,
        };

        if (bytes_read == 0) {
            if (buffer.items.len == 0) {
                buffer.deinit(allocator);
                return null;
            }
            break;
        }

        const ch = byte_buf[0];
        if (ch == '\n') {
            break;
        }
        if (ch == '\r') {
            continue;
        }
        if (buffer.items.len >= max_len) {
            return error.LineTooLong;
        }
        try buffer.append(allocator, ch);
    }

    return try buffer.toOwnedSlice(allocator);
}

fn rewriteInteractiveLine(
    stdout_file: *std.fs.File,
    prompt: []const u8,
    prompt_width: usize,
    buffer: []const u8,
    cursor: usize,
    previous_total_width: usize,
) !usize {
    const line_width = prompt_width + gcode.stringWidth(buffer);
    const cursor_width = prompt_width + gcode.stringWidth(buffer[0..cursor]);

    try stdout_file.writeAll("\r");
    try stdout_file.writeAll(prompt);
    if (buffer.len > 0) {
        try stdout_file.writeAll(buffer);
    }

    if (line_width < previous_total_width) {
        const diff = previous_total_width - line_width;
        var space_block: [16]u8 = undefined;
        @memset(space_block[0..space_block.len], ' ');

        var remaining = diff;
        while (remaining > 0) {
            const chunk = @min(remaining, space_block.len);
            try stdout_file.writeAll(space_block[0..chunk]);
            remaining -= chunk;
        }

        remaining = diff;
        while (remaining > 0) : (remaining -= 1) {
            try stdout_file.writeAll("\x08");
        }
    }

    if (cursor_width < line_width) {
        try moveCursorLeft(stdout_file, line_width - cursor_width);
    }

    return line_width;
}

fn moveCursorLeft(stdout_file: *std.fs.File, cells: usize) !void {
    if (cells == 0) return;
    var seq_buf: [32]u8 = undefined;
    const seq = std.fmt.bufPrint(&seq_buf, "\x1b[{d}D", .{cells}) catch return error.OutOfMemory;
    try stdout_file.writeAll(seq);
}

fn moveCursorRight(stdout_file: *std.fs.File, cells: usize) !void {
    if (cells == 0) return;
    var seq_buf: [32]u8 = undefined;
    const seq = std.fmt.bufPrint(&seq_buf, "\x1b[{d}C", .{cells}) catch return error.OutOfMemory;
    try stdout_file.writeAll(seq);
}

fn readLineInteractive(
    allocator: std.mem.Allocator,
    stdin_file: *std.fs.File,
    stdout_file: *std.fs.File,
    prompt: []const u8,
    max_len: usize,
) ReadLineError!?[]const u8 {
    const fallback_prompt = "gshell> ";
    const prompt_bytes = if (gcode.utf8.validate(prompt)) prompt else fallback_prompt;
    const prompt_width = gcode.stringWidth(prompt_bytes);

    try stdout_file.writeAll(prompt_bytes);

    var buffer = std.ArrayListUnmanaged(u8){};
    defer buffer.deinit(allocator);

    var cursor: usize = 0;
    var rendered_width = prompt_width;

    var byte_buf: [1]u8 = undefined;

    while (true) {
        if (buffer.items.len >= max_len) {
            return error.LineTooLong;
        }

        const bytes_read = stdin_file.read(&byte_buf) catch |err| switch (err) {
            error.OperationAborted => return error.OperationAborted,
            else => return err,
        };

        if (bytes_read == 0) {
            if (buffer.items.len == 0) {
                return null;
            }
            break;
        }

        const ch = byte_buf[0];

        switch (ch) {
            '\r', '\n' => {
                try stdout_file.writeAll("\r\n");
                break;
            },
            0x04 => { // Ctrl-D
                if (buffer.items.len == 0) {
                    return null;
                }
                continue;
            },
            0x03 => { // Ctrl-C
                return error.OperationAborted;
            },
            0x01 => { // Ctrl-A
                if (cursor != 0) {
                    cursor = 0;
                    rendered_width = try rewriteInteractiveLine(stdout_file, prompt_bytes, prompt_width, buffer.items, cursor, rendered_width);
                }
                continue;
            },
            0x05 => { // Ctrl-E
                if (cursor != buffer.items.len) {
                    cursor = buffer.items.len;
                    rendered_width = try rewriteInteractiveLine(stdout_file, prompt_bytes, prompt_width, buffer.items, cursor, rendered_width);
                }
                continue;
            },
            0x08, 0x7f => { // Backspace / DEL key
                if (cursor > 0) {
                    const prev = gcode.findPreviousGrapheme(buffer.items, cursor);
                    const remove_len = cursor - prev;
                    const old_len = buffer.items.len;
                    std.mem.copyForwards(u8, buffer.items[prev .. old_len - remove_len], buffer.items[cursor..old_len]);
                    buffer.shrinkRetainingCapacity(old_len - remove_len);
                    cursor = prev;
                    rendered_width = try rewriteInteractiveLine(stdout_file, prompt_bytes, prompt_width, buffer.items, cursor, rendered_width);
                }
                continue;
            },
            0x1b => { // Escape sequences (arrow keys, delete, home/end)
                var seq_buf: [8]u8 = undefined;
                var consumed: usize = 0;
                while (consumed < seq_buf.len) {
                    const r = stdin_file.read(seq_buf[consumed .. consumed + 1]) catch |err| switch (err) {
                        error.OperationAborted => return error.OperationAborted,
                        else => return err,
                    };
                    if (r == 0) break;
                    consumed += r;
                    const last = seq_buf[consumed - 1];
                    if ((last >= 'A' and last <= 'Z') or last == '~') break;
                }

                if (consumed >= 2 and seq_buf[0] == '[') {
                    const final = seq_buf[consumed - 1];
                    switch (final) {
                        'A', 'B' => {}, // TODO: history
                        'C' => { // Right arrow
                            const next = gcode.findNextGrapheme(buffer.items, cursor);
                            if (next != cursor) {
                                cursor = next;
                                rendered_width = try rewriteInteractiveLine(stdout_file, prompt_bytes, prompt_width, buffer.items, cursor, rendered_width);
                            }
                        },
                        'D' => { // Left arrow
                            const prev = gcode.findPreviousGrapheme(buffer.items, cursor);
                            if (prev != cursor) {
                                cursor = prev;
                                rendered_width = try rewriteInteractiveLine(stdout_file, prompt_bytes, prompt_width, buffer.items, cursor, rendered_width);
                            }
                        },
                        'H' => { // Home
                            if (cursor != 0) {
                                cursor = 0;
                                rendered_width = try rewriteInteractiveLine(stdout_file, prompt_bytes, prompt_width, buffer.items, cursor, rendered_width);
                            }
                        },
                        'F' => { // End
                            if (cursor != buffer.items.len) {
                                cursor = buffer.items.len;
                                rendered_width = try rewriteInteractiveLine(stdout_file, prompt_bytes, prompt_width, buffer.items, cursor, rendered_width);
                            }
                        },
                        '~' => {
                            if (consumed >= 2 and seq_buf[1] == '3') { // Delete key
                                if (cursor < buffer.items.len) {
                                    const next = gcode.findNextGrapheme(buffer.items, cursor);
                                    const remove_len = next - cursor;
                                    const old_len = buffer.items.len;
                                    std.mem.copyForwards(u8, buffer.items[cursor .. old_len - remove_len], buffer.items[next..old_len]);
                                    buffer.shrinkRetainingCapacity(old_len - remove_len);
                                    rendered_width = try rewriteInteractiveLine(stdout_file, prompt_bytes, prompt_width, buffer.items, cursor, rendered_width);
                                }
                            }
                        },
                        else => {},
                    }
                }
                continue;
            },
            else => {},
        }

        if (ch < 0x20 and ch != '\t') {
            continue;
        }

        try buffer.append(allocator, 0);
        const new_len = buffer.items.len;
        if (cursor < new_len - 1) {
            std.mem.copyBackwards(u8, buffer.items[cursor + 1 .. new_len], buffer.items[cursor .. new_len - 1]);
        }
        buffer.items[cursor] = ch;
        cursor += 1;
        rendered_width = try rewriteInteractiveLine(stdout_file, prompt_bytes, prompt_width, buffer.items, cursor, rendered_width);
    }

    return try buffer.toOwnedSlice(allocator);
}

test "runCommand echo" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var cfg = config_mod.ShellConfig.initDefaults(gpa.allocator()) catch |err| {
        return err;
    };
    var shell = Shell.init(gpa.allocator(), cfg) catch |err| {
        cfg.deinit();
        return err;
    };
    defer shell.deinit();

    const status = try shell.runCommand("echo hello");
    try std.testing.expectEqual(@as(i32, 0), status);
}

test "gcode helpers width and grapheme" {
    try std.testing.expectEqual(@as(usize, 1), gcode.stringWidth("A"));
    try std.testing.expectEqual(@as(usize, 2), gcode.stringWidth("漢"));

    const accented = "e\u{0301}"; // e with combining acute
    try std.testing.expectEqual(@as(usize, 1), gcode.stringWidth(accented));
    const prev = gcode.findPreviousGrapheme(accented, accented.len);
    try std.testing.expectEqual(@as(usize, 0), prev);
}
