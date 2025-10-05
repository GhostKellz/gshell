const std = @import("std");
const zsync = @import("zsync");
const zigzag = @import("zigzag");
const zlog = @import("zlog");

const logging = @import("logging.zig");
const history_mod = @import("history.zig");
const plugins_mod = @import("plugins.zig");
const config_mod = @import("config.zig");

const default_prompt_plugin_source = @embedFile("assets/plugins/default_prompt.ghost");

pub const Runtime = struct {
    allocator: std.mem.Allocator,
    logger: logging.Logger,
    zsync_runtime: *zsync.Runtime,
    event_loop: zigzag.EventLoop,
    stdin_watch: ?*zigzag.Watch = null,
    flush_timer: ?*zigzag.Timer = null,
    stdin_ready: std.atomic.Value(bool),
    flush_due: std.atomic.Value(bool),
    history: ?history_mod.HistoryStore,
    plugins: plugins_mod.PluginHost,
    sys: SystemInfo,
    flush_timer_id: ?u32,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, shell_config: *const config_mod.ShellConfig) !Runtime {
        var logger = try logging.Logger.init(allocator, .info);
        errdefer logger.deinit();

        const runtime_ptr = try zsync.createOptimalRuntime(allocator);
        errdefer runtime_ptr.deinit();

        var event_loop = try zigzag.EventLoop.init(allocator, .{});
        errdefer event_loop.deinit();

        var system_info = try gatherSystemInfo(allocator);
        errdefer system_info.deinit(allocator);

        const history_store = try prepareHistoryStore(allocator, shell_config, &system_info);
        errdefer if (history_store) |*store| store.deinit();

        var plugin_host = try plugins_mod.PluginHost.init(allocator, 256 * 1024);
        errdefer plugin_host.deinit();

        loadEmbeddedPromptPlugin(&plugin_host) catch |err| {
            logger.warn("failed to load embedded prompt plugin: {s}", .{@errorName(err)});
        };

        var runtime = Runtime{
            .allocator = allocator,
            .logger = logger,
            .zsync_runtime = runtime_ptr,
            .event_loop = event_loop,
            .stdin_watch = null,
            .flush_timer = null,
            .stdin_ready = std.atomic.Value(bool).init(false),
            .flush_due = std.atomic.Value(bool).init(false),
            .history = history_store,
            .plugins = plugin_host,
            .sys = system_info,
            .flush_timer_id = null,
        };

        try runtime.loadConfiguredPlugins(shell_config);

        return runtime;
    }

    pub fn deinit(self: *Runtime) void {
        if (self.flush_timer) |timer| {
            self.event_loop.cancelTimer(timer);
        }
        if (self.stdin_watch) |watch| {
            self.event_loop.removeFd(watch);
        }
        self.plugins.deinit();
        if (self.history) |*store| store.deinit();
        self.sys.deinit(self.allocator);
        self.event_loop.deinit();
        self.zsync_runtime.deinit();
        self.logger.deinit();
    }

    pub fn activate(self: *Runtime) !void {
        if (self.stdin_watch == null) {
            const watch_ptr = try self.event_loop.addFd(std.posix.STDIN_FILENO, .{ .read = true });
            self.stdin_watch = watch_ptr;
        }
        if (self.flush_timer == null) {
            const timer_ptr = try self.event_loop.addRecurringTimer(2_000, Runtime.onFlushTimer);
            timer_ptr.user_data = self;
            self.flush_timer = timer_ptr;
            self.flush_timer_id = timer_ptr.id;
        }
    }

    pub fn tick(self: *Runtime) void {
        var events: [32]zigzag.Event = undefined;
        const count = self.event_loop.poll(&events, 0) catch |err| {
            self.logger.warn("event loop poll failed: {s}", .{@errorName(err)});
            return;
        };

        for (events[0..count]) |event| {
            self.processEvent(event);
        }

        if (self.flush_due.swap(false, .acq_rel)) {
            if (self.history) |*store| {
                store.flush() catch |err| self.logger.warn("history flush failed: {s}", .{@errorName(err)});
            }
        }
    }

    pub fn waitForReadable(self: *Runtime, timeout_ms: ?u32) bool {
        if (self.stdin_ready.swap(false, .acq_rel)) {
            return true;
        }

        var events: [16]zigzag.Event = undefined;
        const count = self.event_loop.poll(&events, timeout_ms) catch |err| {
            self.logger.warn("event loop wait failed: {s}", .{@errorName(err)});
            return false;
        };

        var ready = false;
        for (events[0..count]) |event| {
            if (event.fd == std.posix.STDIN_FILENO and event.type == .read_ready) {
                ready = true;
            }
            self.processEvent(event);
        }

        if (ready) {
            _ = self.stdin_ready.swap(false, .acq_rel);
            return true;
        }
        return false;
    }

    pub fn renderPrompt(self: *Runtime, allocator: std.mem.Allocator, base_prompt: []const u8, exit_code: i32) ![]const u8 {
        var ctx = PromptTaskContext{
            .runtime = self,
            .allocator = allocator,
            .base_prompt = base_prompt,
            .exit_code = exit_code,
            .result = null,
            .err = null,
        };

        const run_err = self.zsync_runtime.run(promptTask, .{&ctx});
        if (run_err) |err| {
            self.logger.warn("prompt task failed: {s}", .{@errorName(err)});
        }

        if (ctx.err) |err| {
            return err;
        }

        if (ctx.result) |value| {
            return value;
        }

        return allocator.dupe(u8, base_prompt);
    }

    pub fn recordHistory(self: *Runtime, command: []const u8, exit_code: i32) void {
        if (self.history) |*store| {
            store.append(command, exit_code) catch |err| {
                self.logger.warn("failed to record history: {s}", .{@errorName(err)});
            };
        }
    }

    pub fn logCommand(self: *Runtime, command: []const u8, exit_code: i32) void {
        const fields = [_]zlog.Field{
            .{ .key = "exit", .value = .{ .int = exit_code } },
        };
        self.logger.scoped("{s}", .{command}, &fields);
    }

    fn processEvent(self: *Runtime, event: zigzag.Event) void {
        switch (event.type) {
            .read_ready => {
                if (event.fd == std.posix.STDIN_FILENO) {
                    self.stdin_ready.store(true, .release);
                }
            },
            .timer_expired => {
                if (self.flush_timer_id) |id| {
                    if (event.data.timer_id == id) {
                        self.flush_due.store(true, .release);
                    }
                }
            },
            else => {},
        }
    }

    fn promptTask(io: zsync.Io, args: *PromptTaskContext) zsync.IoError!void {
        _ = io;
        args.result = args.runtime.buildPrompt(args.allocator, args.base_prompt, args.exit_code) catch |err| {
            args.err = err;
            return zsync.IoError.Unexpected;
        };
    }

    fn buildPrompt(self: *Runtime, allocator: std.mem.Allocator, base_prompt: []const u8, exit_code: i32) ![]const u8 {
        var builder = std.ArrayList(u8){};
        errdefer builder.deinit(allocator);

        try builder.appendSlice(allocator, base_prompt);

        if (exit_code != 0) {
            try builder.print(allocator, "[{d}] ", .{exit_code});
        }

        const cwd = std.fs.cwd().realpathAlloc(allocator, ".") catch |err| {
            self.logger.warn("failed to resolve cwd: {s}", .{@errorName(err)});
            return builder.toOwnedSlice(allocator);
        };
        defer allocator.free(cwd);

        const plugin_segment = self.plugins.renderPromptSegments(allocator, .{
            .user = self.sys.user,
            .host = self.sys.host,
            .cwd = cwd,
            .exit_code = exit_code,
        }) catch |err| {
            self.logger.warn("prompt plugin failed: {s}", .{@errorName(err)});
            return builder.toOwnedSlice(allocator);
        };
        defer allocator.free(plugin_segment);

        if (plugin_segment.len > 0) {
            try builder.appendSlice(allocator, plugin_segment);
        }

        return builder.toOwnedSlice(allocator);
    }

    fn onFlushTimer(user_data: ?*anyopaque) void {
        if (user_data) |ptr| {
            const runtime: *Runtime = @ptrCast(@alignCast(ptr));
            runtime.flush_due.store(true, .release);
        }
    }

    fn loadConfiguredPlugins(self: *Runtime, shell_config: *const config_mod.ShellConfig) !void {
        if (shell_config.plugins.items.len == 0) return;

        for (shell_config.plugins.items) |plugin_name| {
            if (try buildPluginPath(self.allocator, self.sys.home, plugin_name)) |source| {
                defer self.allocator.free(source);
                self.plugins.loadInline(plugin_name, source) catch |err| {
                    self.logger.warn("failed to load plugin '{s}': {s}", .{ plugin_name, @errorName(err) });
                };
            } else {
                self.logger.warn("plugin '{s}' not found", .{plugin_name});
            }
        }
    }
};

const PromptTaskContext = struct {
    runtime: *Runtime,
    allocator: std.mem.Allocator,
    base_prompt: []const u8,
    exit_code: i32,
    result: ?[]const u8,
    err: ?anyerror = null,
};

const SystemInfo = struct {
    user: []const u8,
    host: []const u8,
    home: []const u8,

    fn deinit(self: *SystemInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.user);
        allocator.free(self.host);
        allocator.free(self.home);
    }
};

fn gatherSystemInfo(allocator: std.mem.Allocator) !SystemInfo {
    const user = std.process.getEnvVarOwned(allocator, "USER") catch try allocator.dupe(u8, "unknown");
    errdefer allocator.free(user);

    var host_buf: [128]u8 = undefined;
    const host_slice = std.net.getHostname(&host_buf) catch "localhost";
    const host = try allocator.dupe(u8, host_slice);
    errdefer allocator.free(host);

    const home = std.process.getEnvVarOwned(allocator, "HOME") catch try allocator.dupe(u8, ".");

    return SystemInfo{ .user = user, .host = host, .home = home };
}

fn prepareHistoryStore(
    allocator: std.mem.Allocator,
    shell_config: *const config_mod.ShellConfig,
    sys: *const SystemInfo,
) !?history_mod.HistoryStore {
    if (shell_config.history_file) |path| {
        const resolved = try resolvePath(allocator, path, sys.home);
        defer allocator.free(resolved);
        return history_mod.HistoryStore.init(allocator, resolved);
    }
    return null;
}

fn resolvePath(allocator: std.mem.Allocator, raw: []const u8, home: []const u8) ![]u8 {
    var builder = std.ArrayList(u8){};
    errdefer builder.deinit(allocator);

    var i: usize = 0;
    while (i < raw.len) : (i += 1) {
        const ch = raw[i];
        if (ch == '~' and i == 0) {
            try builder.appendSlice(allocator, home);
            continue;
        }
        if (ch == '$' and i + 1 < raw.len and raw[i + 1] == '{') {
            const closing = std.mem.indexOfScalarPos(u8, raw, i + 2, '}') orelse break;
            const key = raw[i + 2 .. closing];
            const value = std.process.getEnvVarOwned(allocator, key) catch |err| switch (err) {
                error.EnvironmentVariableNotFound => null,
                else => return err,
            };
            defer if (value) |val| allocator.free(val);
            if (value) |val| {
                try builder.appendSlice(allocator, val);
            }
            i = closing;
            continue;
        }
        try builder.append(allocator, ch);
    }

    return builder.toOwnedSlice(allocator);
}

fn loadEmbeddedPromptPlugin(host: *plugins_mod.PluginHost) !void {
    try host.loadInline("default_prompt", default_prompt_plugin_source);
}

fn buildPluginPath(
    allocator: std.mem.Allocator,
    home: []const u8,
    plugin_name: []const u8,
) !?[]u8 {
    const path = try std.fmt.allocPrint(allocator, "{s}/.config/gshell/plugins/{s}.ghost", .{ home, plugin_name });
    defer allocator.free(path);

    if (std.fs.cwd().access(path, .{})) {
        return allocator.dupe(u8, path);
    } else |_| {}

    const asset_path = try std.fmt.allocPrint(allocator, "assets/plugins/{s}.ghost", .{plugin_name});
    defer allocator.free(asset_path);

    if (std.fs.cwd().access(asset_path, .{})) {
        return allocator.dupe(u8, asset_path);
    } else |_| {}

    return null;
}
