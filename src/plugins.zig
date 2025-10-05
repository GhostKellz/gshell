const std = @import("std");
const ghostlang = @import("ghostlang");

pub const PluginError = error{
    ScriptFailure,
    UnsupportedHook,
    InvalidReturnType,
    OutOfMemory,
};

pub const PromptContext = struct {
    user: []const u8,
    host: []const u8,
    cwd: []const u8,
    exit_code: i32,
};

pub const PluginHost = struct {
    allocator: std.mem.Allocator,
    engine: ghostlang.ScriptEngine,
    plugins: std.ArrayList(Plugin),

    const Plugin = struct {
        name: []const u8,
        script: ghostlang.Script,
    };

    pub fn init(allocator: std.mem.Allocator, memory_limit: usize) !PluginHost {
        const engine = try ghostlang.ScriptEngine.create(.{
            .allocator = allocator,
            .memory_limit = memory_limit,
            .execution_timeout_ms = 10,
            .allow_io = false,
            .allow_syscalls = false,
            .deterministic = true,
        });

        return PluginHost{
            .allocator = allocator,
            .engine = engine,
            .plugins = std.ArrayList(Plugin){},
        };
    }

    pub fn deinit(self: *PluginHost) void {
        for (self.plugins.items) |plugin| {
            plugin.script.deinit();
            self.allocator.free(plugin.name);
        }
        self.plugins.deinit(self.allocator);
        self.engine.deinit();
    }

    pub fn loadInline(self: *PluginHost, name: []const u8, source: []const u8) !void {
        const owned_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(owned_name);

        var script = try self.engine.loadScript(source);
        errdefer script.deinit();

        var exec_result = try script.run();
        defer exec_result.deinit(self.engine.config.allocator);

        try self.plugins.append(self.allocator, .{ .name = owned_name, .script = script });
    }

    pub fn renderPromptSegments(self: *PluginHost, allocator: std.mem.Allocator, ctx: PromptContext) ![]u8 {
        if (self.plugins.items.len == 0) {
            return allocator.alloc(u8, 0);
        }

        var builder = std.ArrayList(u8){};
        errdefer builder.deinit(allocator);

        for (self.plugins.items) |_| {
            var result = self.engine.call("prompt_segment", .{ ctx.user, ctx.host, ctx.cwd, ctx.exit_code }) catch |err| switch (err) {
                ghostlang.ExecutionError.FunctionNotFound => continue,
                else => return PluginError.ScriptFailure,
            };
            defer result.deinit(self.engine.config.allocator);

            switch (result) {
                .string => |output| try builder.appendSlice(allocator, output),
                .nil => {},
                else => return PluginError.InvalidReturnType,
            }
        }

        const output = try builder.toOwnedSlice(allocator);
        builder.deinit(allocator);
        return output;
    }
};
