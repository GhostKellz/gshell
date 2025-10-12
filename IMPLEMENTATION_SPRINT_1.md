# 🚀 GShell Sprint 1: Foundation for Next-Gen Features
## Implementation Plan (2-3 weeks)

---

## 📋 **Sprint Goals**

Build the foundation for GShell's next-generation features:
1. ✅ Syntax highlighting infrastructure
2. ✅ Autosuggestions from history
3. ✅ Git-aware prompt
4. ✅ Smart tab completion framework
5. ✅ Ghostshell semantic protocol integration

---

## 🏗️ **Architecture Overview**

```
┌─────────────────────────────────────────────────────────────┐
│                         GShell Core                          │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌───────────────┐  ┌─────────────────┐ │
│  │   Parser     │  │   Executor    │  │   State Mgmt   │ │
│  │  (existing)  │  │  (existing)   │  │   (existing)    │ │
│  └──────────────┘  └───────────────┘  └─────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│                      NEW COMPONENTS                          │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌───────────────┐  ┌─────────────────┐ │
│  │ Highlighter  │  │  Suggestions  │  │   Completions   │ │
│  │   Engine     │  │    Engine     │  │     Engine      │ │
│  └──────────────┘  └───────────────┘  └─────────────────┘ │
│  ┌──────────────┐  ┌───────────────┐  ┌─────────────────┐ │
│  │   Prompt     │  │   Terminal    │  │   Git Info      │ │
│  │   Engine     │  │   Protocol    │  │     Cache       │ │
│  └──────────────┘  └───────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## 📁 **New File Structure**

```
src/
├── highlight/
│   ├── root.zig           # Public API
│   ├── engine.zig         # Core highlighting logic
│   ├── theme.zig          # Color themes
│   └── ansi.zig           # ANSI escape codes
├── suggest/
│   ├── root.zig           # Public API
│   ├── engine.zig         # Suggestion algorithm
│   ├── history.zig        # History search
│   └── ranking.zig        # Frecency calculation
├── complete/
│   ├── root.zig           # Public API
│   ├── engine.zig         # Completion framework
│   ├── file.zig           # File path completions
│   ├── command.zig        # Command completions
│   ├── git.zig            # Git-specific completions
│   └── option.zig         # Flag/option parsing
├── prompt/
│   ├── root.zig           # Public API
│   ├── builder.zig        # Prompt construction
│   ├── git.zig            # Git status
│   ├── async.zig          # Async updates
│   └── themes/            # Prompt themes
│       ├── default.zig
│       ├── minimal.zig
│       └── powerline.zig
├── terminal/
│   ├── root.zig           # Public API
│   ├── protocol.zig       # OSC sequences
│   ├── capabilities.zig   # Feature detection
│   └── ghostshell.zig     # Ghostshell-specific
└── git/
    ├── root.zig           # Public API
    ├── status.zig         # Fast git status
    └── cache.zig          # Status caching
```

---

## 🔨 **Task Breakdown**

### **Task 1: Syntax Highlighting Engine** (Days 1-3)

#### **1.1 Create Highlight Engine**

**File: `src/highlight/engine.zig`**

```zig
/// Real-time syntax highlighting engine
const std = @import("std");
const parser = @import("../parser.zig");
const theme = @import("theme.zig");

pub const HighlightSpan = struct {
    start: usize,
    end: usize,
    style: theme.Style,
};

pub const HighlightEngine = struct {
    allocator: std.mem.Allocator,
    theme: theme.Theme,

    pub fn init(allocator: std.mem.Allocator) !HighlightEngine {
        return HighlightEngine{
            .allocator = allocator,
            .theme = theme.default_theme,
        };
    }

    /// Highlight a command line and return styled spans
    pub fn highlight(self: *HighlightEngine, line: []const u8) ![]HighlightSpan {
        var spans = std.ArrayList(HighlightSpan).init(self.allocator);

        // Parse the line
        const pipeline = parser.parseLine(self.allocator, line) catch |err| {
            // If parse fails, mark entire line as error
            try spans.append(.{
                .start = 0,
                .end = line.len,
                .style = self.theme.error,
            });
            return spans.toOwnedSlice();
        };
        defer pipeline.deinit(self.allocator);

        // Highlight based on token types
        for (pipeline.commands) |cmd| {
            // Command name
            if (cmd.argv.len > 0) {
                const cmd_name = cmd.argv[0];
                const style = if (isValidCommand(cmd_name))
                    self.theme.command_valid
                else
                    self.theme.command_invalid;

                // Find position in original line
                if (std.mem.indexOf(u8, line, cmd_name)) |pos| {
                    try spans.append(.{
                        .start = pos,
                        .end = pos + cmd_name.len,
                        .style = style,
                    });
                }
            }

            // Arguments
            for (cmd.argv[1..]) |arg| {
                if (std.mem.indexOf(u8, line, arg)) |pos| {
                    const style = detectArgStyle(arg);
                    try spans.append(.{
                        .start = pos,
                        .end = pos + arg.len,
                        .style = style,
                    });
                }
            }

            // Redirections
            if (cmd.stdout_file) |file| {
                if (std.mem.indexOf(u8, line, file)) |pos| {
                    try spans.append(.{
                        .start = pos,
                        .end = pos + file.len,
                        .style = self.theme.path,
                    });
                }
            }
        }

        return spans.toOwnedSlice();
    }

    fn isValidCommand(cmd: []const u8) bool {
        // Check if command exists in PATH or is a builtin
        if (builtins.lookup(cmd) != null) return true;

        // Simple check: try to find in common locations
        const paths = [_][]const u8{
            "/usr/bin/",
            "/bin/",
            "/usr/local/bin/",
        };

        var buf: [4096]u8 = undefined;
        for (paths) |path| {
            const full_path = std.fmt.bufPrint(&buf, "{s}{s}", .{path, cmd}) catch continue;
            std.fs.accessAbsolute(full_path, .{}) catch continue;
            return true;
        }

        return false;
    }

    fn detectArgStyle(arg: []const u8) theme.Style {
        if (arg.len == 0) return theme.default_theme.text;

        // Flags (-f, --flag)
        if (arg[0] == '-') return theme.default_theme.flag;

        // Strings (quoted)
        if (arg[0] == '"' or arg[0] == '\'') return theme.default_theme.string;

        // Numbers
        if (std.fmt.parseInt(i64, arg, 10)) |_| {
            return theme.default_theme.number;
        } else |_| {}

        // Paths
        if (std.mem.indexOf(u8, arg, "/") != null) {
            return theme.default_theme.path;
        }

        return theme.default_theme.text;
    }
};
```

#### **1.2 Create Theme System**

**File: `src/highlight/theme.zig`**

```zig
const std = @import("std");
const ansi = @import("ansi.zig");

pub const Style = struct {
    fg: Color,
    bg: ?Color = null,
    bold: bool = false,
    italic: bool = false,
    underline: bool = false,
};

pub const Color = union(enum) {
    rgb: struct { r: u8, g: u8, b: u8 },
    ansi256: u8,
    ansi16: u8,
};

pub const Theme = struct {
    command_valid: Style,
    command_invalid: Style,
    flag: Style,
    string: Style,
    number: Style,
    path: Style,
    operator: Style,
    text: Style,
    error: Style,
};

pub const default_theme = Theme{
    .command_valid = .{ .fg = .{ .ansi256 = 2 }, .bold = true },  // Green
    .command_invalid = .{ .fg = .{ .ansi256 = 1 } },              // Red
    .flag = .{ .fg = .{ .ansi256 = 4 } },                          // Blue
    .string = .{ .fg = .{ .ansi256 = 3 } },                        // Yellow
    .number = .{ .fg = .{ .ansi256 = 6 } },                        // Cyan
    .path = .{ .fg = .{ .ansi256 = 5 }, .underline = true },      // Magenta
    .operator = .{ .fg = .{ .ansi256 = 7 }, .bold = true },       // White
    .text = .{ .fg = .{ .ansi256 = 7 } },                          // Default
    .error = .{ .fg = .{ .ansi256 = 1 }, .bold = true },          // Bold Red
};

pub const gruvbox_theme = Theme{
    .command_valid = .{ .fg = .{ .rgb = .{ .r = 152, .g = 151, .b = 26 } }, .bold = true },
    .command_invalid = .{ .fg = .{ .rgb = .{ .r = 204, .g = 36, .b = 29 } } },
    .flag = .{ .fg = .{ .rgb = .{ .r = 69, .g = 133, .b = 136 } } },
    .string = .{ .fg = .{ .rgb = .{ .r = 215, .g = 153, .b = 33 } } },
    .number = .{ .fg = .{ .rgb = .{ .r = 211, .g = 134, .b = 155 } } },
    .path = .{ .fg = .{ .rgb = .{ .r = 177, .g = 98, .b = 134 } } },
    .operator = .{ .fg = .{ .rgb = .{ .r = 146, .g = 131, .b = 116 } } },
    .text = .{ .fg = .{ .rgb = .{ .r = 235, .g = 219, .b = 178 } } },
    .error = .{ .fg = .{ .rgb = .{ .r = 251, .g = 73, .b = 52 } }, .bold = true },
};
```

---

### **Task 2: Autosuggestions Engine** (Days 4-6)

**File: `src/suggest/engine.zig`**

```zig
const std = @import("std");
const history = @import("../history.zig");

pub const Suggestion = struct {
    text: []const u8,
    score: f32,
    source: Source,

    pub const Source = enum {
        history,
        completion,
        alias,
    };
};

pub const SuggestEngine = struct {
    allocator: std.mem.Allocator,
    history_store: *history.HistoryStore,

    pub fn init(allocator: std.mem.Allocator, hist: *history.HistoryStore) !SuggestEngine {
        return SuggestEngine{
            .allocator = allocator,
            .history_store = hist,
        };
    }

    /// Get suggestion for partial input
    pub fn suggest(self: *SuggestEngine, partial: []const u8) !?Suggestion {
        if (partial.len == 0) return null;

        // Search history for matches
        const recent = try self.history_store.recent(self.allocator, 1000);
        defer {
            for (recent) |entry| self.allocator.free(entry);
            self.allocator.free(recent);
        }

        var best_match: ?Suggestion = null;
        var best_score: f32 = 0.0;

        for (recent, 0..) |entry, idx| {
            // Parse history entry (format: timestamp|exitcode|command)
            const record = history.parseRecord(entry) orelse continue;
            const cmd = record.command;

            // Check if command starts with partial input
            if (std.mem.startsWith(u8, cmd, partial)) {
                // Calculate score based on recency and frequency
                const recency_score = @as(f32, @floatFromInt(recent.len - idx)) / @as(f32, @floatFromInt(recent.len));
                const match_score = @as(f32, @floatFromInt(partial.len)) / @as(f32, @floatFromInt(cmd.len));
                const score = recency_score * 0.7 + match_score * 0.3;

                if (score > best_score) {
                    if (best_match) |old| self.allocator.free(old.text);

                    best_match = Suggestion{
                        .text = try self.allocator.dupe(u8, cmd),
                        .score = score,
                        .source = .history,
                    };
                    best_score = score;
                }
            }
        }

        return best_match;
    }
};
```

---

### **Task 3: Git-Aware Prompt** (Days 7-9)

**File: `src/prompt/git.zig`**

```zig
const std = @import("std");

pub const GitStatus = struct {
    branch: []const u8,
    dirty: bool,
    ahead: usize,
    behind: usize,
    detached: bool,

    pub fn deinit(self: GitStatus, allocator: std.mem.Allocator) void {
        allocator.free(self.branch);
    }
};

pub fn getGitStatus(allocator: std.mem.Allocator, cwd: []const u8) !?GitStatus {
    // Fast check: is this a git repo?
    var git_dir_buf: [4096]u8 = undefined;
    const git_dir = std.fmt.bufPrint(&git_dir_buf, "{s}/.git", .{cwd}) catch return null;

    std.fs.accessAbsolute(git_dir, .{}) catch return null;

    // Get branch name
    const branch = try getCurrentBranch(allocator, cwd);
    errdefer allocator.free(branch);

    // Check if dirty (has uncommitted changes)
    const dirty = try isRepoDirty(allocator, cwd);

    // Get ahead/behind counts
    const counts = try getAheadBehind(allocator, cwd);

    return GitStatus{
        .branch = branch,
        .dirty = dirty,
        .ahead = counts.ahead,
        .behind = counts.behind,
        .detached = std.mem.eql(u8, branch, "HEAD"),
    };
}

fn getCurrentBranch(allocator: std.mem.Allocator, cwd: []const u8) ![]const u8 {
    // Run: git branch --show-current
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "git", "branch", "--show-current" },
        .cwd = cwd,
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.term.Exited == 0) {
        const branch = std.mem.trim(u8, result.stdout, " \t\n\r");
        if (branch.len > 0) {
            return allocator.dupe(u8, branch);
        }
    }

    // Fallback: detached HEAD
    return allocator.dupe(u8, "HEAD");
}

fn isRepoDirty(allocator: std.mem.Allocator, cwd: []const u8) !bool {
    // Run: git status --porcelain
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "git", "status", "--porcelain" },
        .cwd = cwd,
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    return result.stdout.len > 0;
}

fn getAheadBehind(allocator: std.mem.Allocator, cwd: []const u8) !struct { ahead: usize, behind: usize } {
    // Run: git rev-list --left-right --count @{upstream}...HEAD
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "git", "rev-list", "--left-right", "--count", "@{upstream}...HEAD" },
        .cwd = cwd,
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.term.Exited != 0) {
        return .{ .ahead = 0, .behind = 0 };
    }

    // Parse output: "behind\tahead\n"
    var iter = std.mem.tokenizeScalar(u8, result.stdout, '\t');
    const behind_str = iter.next() orelse "0";
    const ahead_str = iter.next() orelse "0";

    const behind = std.fmt.parseInt(usize, std.mem.trim(u8, behind_str, " \t\n\r"), 10) catch 0;
    const ahead = std.fmt.parseInt(usize, std.mem.trim(u8, ahead_str, " \t\n\r"), 10) catch 0;

    return .{ .ahead = ahead, .behind = behind };
}
```

**File: `src/prompt/builder.zig`**

```zig
const std = @import("std");
const git = @import("git.zig");
const theme = @import("../highlight/theme.zig");
const ansi = @import("../highlight/ansi.zig");

pub const PromptBuilder = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) PromptBuilder {
        return .{ .allocator = allocator };
    }

    pub fn build(self: *PromptBuilder, cwd: []const u8, user: []const u8, host: []const u8) ![]const u8 {
        var prompt = std.ArrayList(u8).init(self.allocator);

        // User@host
        try prompt.appendSlice(ansi.color256(2));  // Green
        try prompt.appendSlice(user);
        try prompt.appendSlice("@");
        try prompt.appendSlice(host);
        try prompt.appendSlice(ansi.reset());

        try prompt.appendSlice(" ");

        // Current directory
        try prompt.appendSlice(ansi.color256(4));  // Blue
        try prompt.appendSlice(cwd);
        try prompt.appendSlice(ansi.reset());

        // Git status
        if (try git.getGitStatus(self.allocator, cwd)) |status| {
            defer status.deinit(self.allocator);

            try prompt.appendSlice(" ");
            try prompt.appendSlice(ansi.color256(5));  // Magenta
            try prompt.appendSlice("(");
            try prompt.appendSlice(status.branch);

            if (status.dirty) {
                try prompt.appendSlice(" ✗");
            }

            if (status.ahead > 0) {
                try prompt.writer().print(" ↑{}", .{status.ahead});
            }

            if (status.behind > 0) {
                try prompt.writer().print(" ↓{}", .{status.behind});
            }

            try prompt.appendSlice(")");
            try prompt.appendSlice(ansi.reset());
        }

        try prompt.appendSlice(" $ ");

        return prompt.toOwnedSlice();
    }
};
```

---

### **Task 4: Ghostshell Protocol Integration** (Days 10-12)

**File: `src/terminal/protocol.zig`**

```zig
const std = @import("std");

/// OSC 133 - Shell Integration Protocol
/// Used by terminals like iTerm2, VS Code, and Ghostshell
pub const Protocol = struct {
    writer: std.io.AnyWriter,

    pub fn init(writer: std.io.AnyWriter) Protocol {
        return .{ .writer = writer };
    }

    /// Mark the start of a prompt
    pub fn markPromptStart(self: Protocol) !void {
        try self.writer.writeAll("\x1b]133;A\x07");
    }

    /// Mark the end of prompt / start of command input
    pub fn markCommandStart(self: Protocol) !void {
        try self.writer.writeAll("\x1b]133;B\x07");
    }

    /// Mark command execution (right before running)
    pub fn markCommandExecute(self: Protocol) !void {
        try self.writer.writeAll("\x1b]133;C\x07");
    }

    /// Mark command completion with exit code
    pub fn markCommandEnd(self: Protocol, exit_code: i32) !void {
        var buf: [64]u8 = undefined;
        const osc = try std.fmt.bufPrint(&buf, "\x1b]133;D;{d}\x07", .{exit_code});
        try self.writer.writeAll(osc);
    }

    /// Set current working directory (for terminal to track)
    pub fn setCwd(self: Protocol, cwd: []const u8) !void {
        try self.writer.print("\x1b]7;file://{s}\x07", .{cwd});
    }

    /// Send notification
    pub fn notify(self: Protocol, title: []const u8, message: []const u8) !void {
        try self.writer.print("\x1b]9;{s}|{s}\x07", .{ title, message });
    }
};
```

---

### **Task 5: Integration into Main REPL** (Days 13-14)

**File: `src/repl.zig` (modifications)**

```zig
// Add these fields to REPL struct:
highlight_engine: highlight.HighlightEngine,
suggest_engine: suggest.SuggestEngine,
prompt_builder: prompt.PromptBuilder,
term_protocol: terminal.Protocol,

// In init():
self.highlight_engine = try highlight.HighlightEngine.init(allocator);
self.suggest_engine = try suggest.SuggestEngine.init(allocator, &self.history);
self.prompt_builder = prompt.PromptBuilder.init(allocator);
self.term_protocol = terminal.Protocol.init(std.io.getStdOut().writer().any());

// In REPL loop - before showing prompt:
try self.term_protocol.markPromptStart();
const prompt_str = try self.prompt_builder.build(cwd, user, host);
defer allocator.free(prompt_str);
try stdout.writeAll(prompt_str);
try self.term_protocol.markCommandStart();

// While user is typing:
const highlighted = try self.highlight_engine.highlight(current_line);
defer allocator.free(highlighted);
// Render highlighted spans...

// Show suggestion:
if (try self.suggest_engine.suggest(current_line)) |suggestion| {
    defer allocator.free(suggestion.text);
    // Render suggestion in gray...
}

// Before executing command:
try self.term_protocol.markCommandExecute();

// After command completes:
try self.term_protocol.markCommandEnd(exit_code);
```

---

## 🧪 **Testing Strategy**

### **Unit Tests:**

```zig
// src/highlight/engine_test.zig
test "highlight valid command" {
    var engine = try HighlightEngine.init(testing.allocator);
    const spans = try engine.highlight("ls -la");
    defer testing.allocator.free(spans);

    try testing.expect(spans.len > 0);
    try testing.expectEqual(spans[0].style, theme.default_theme.command_valid);
}

// src/suggest/engine_test.zig
test "suggest from history" {
    var hist = try history.HistoryStore.init(testing.allocator, "/tmp/test.hist");
    defer hist.deinit();

    try hist.append("git status", 0);
    try hist.append("git commit -m 'test'", 0);

    var engine = try SuggestEngine.init(testing.allocator, &hist);
    const suggestion = try engine.suggest("git st");

    try testing.expect(suggestion != null);
    try testing.expect(std.mem.startsWith(u8, suggestion.?.text, "git st"));
}
```

### **Integration Tests:**

```bash
# Test highlighting
$ echo "ls -la" | gshell --test-highlight
# Should output ANSI codes for colors

# Test suggestions
$ echo "git" | gshell --test-suggest
# Should output historical git commands

# Test prompt
$ gshell --test-prompt
# Should show prompt with git status if in repo
```

---

## 📈 **Success Metrics**

- [ ] Syntax highlighting works for 100+ common commands
- [ ] Autosuggestions have <10ms latency
- [ ] Git prompt updates in <50ms
- [ ] Terminal protocol marks visible in Ghostshell
- [ ] Zero crashes during normal usage
- [ ] Memory usage increase < 5MB

---

## 🚀 **Next Steps After Sprint 1**

After completing these foundation pieces, we can move to:

1. **Structured data pipelines** (JSON, TOML parsing)
2. **Smart tab completions** (context-aware)
3. **Plugin system** (gpm package manager)
4. **Grim integration** (quick edit command)

---

## 💡 **Tips for Implementation**

1. **Start with tests** - Write failing tests first
2. **Use existing libraries** - Don't reinvent the wheel
3. **Benchmark early** - Profile hot paths
4. **Incremental rollout** - Feature flags for new features
5. **Document as you go** - Write docs alongside code

---

Let's ship this! 🎯
