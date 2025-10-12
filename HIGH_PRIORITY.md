# 🚨 HIGH PRIORITY: GShell Syntax Highlighting & UX
## Grove Integration - Ready to Ship!

**Status:** Grove 100% complete, Gshell integration ready to begin
**Timeline:** 1-2 weeks for basic highlighting, 2-3 weeks for full UX
**Impact:** 🔥 **CRITICAL** - Makes gshell visually competitive with Fish/Zsh

---

## ✅ What's Ready (Grove Side)

**Grove v0.1.1 shipped with:**
1. ✅ GShell grammar (15th bundled language)
2. ✅ RealtimeHighlighter API (<5ms latency)
3. ✅ Command validation API
4. ✅ Completion context detection
5. ✅ Error highlighting support
6. ✅ 20+ tests, all passing

**Grove is waiting for you!** 🎉

---

## 🎯 Implementation Checklist

### Phase 1: Basic Highlighting (Week 1) - P0

#### ✅ Grove Integration
- [ ] Add Grove to `build.zig.zon`
- [ ] Fetch Grove dependency: `zig fetch --save https://github.com/GhostKellz/grove/archive/refs/tags/v0.1.1.tar.gz`
- [ ] Wire Grove into `build.zig` imports
- [ ] Test: `zig build` compiles successfully

#### ✅ Highlighter Module
**File:** `src/highlight.zig`

```zig
const grove = @import("grove");

pub const Highlighter = struct {
    realtime: grove.RealtimeHighlighter,

    pub fn init(allocator: std.mem.Allocator) !Highlighter {
        const lang = try grove.Languages.gshell.get();
        const query = @embedFile("../grammar/queries/highlights.scm");

        return .{
            .realtime = try grove.RealtimeHighlighter.init(
                allocator,
                lang,
                query,
            ),
        };
    }

    pub fn deinit(self: *Highlighter) void {
        self.realtime.deinit();
    }

    pub fn highlightLine(self: *Highlighter, line: []const u8) ![]ColoredSegment {
        const spans = try self.realtime.highlightLine(line);
        return try applyTheme(spans);
    }
};
```

**Tasks:**
- [ ] Create `src/highlight.zig`
- [ ] Implement `Highlighter` wrapper
- [ ] Add `applyTheme()` function
- [ ] Test: Parse "ls -la | grep test"

#### ✅ Shell Integration
**File:** `src/shell.zig` (modify existing)

Integrate into `readLineInteractive()`:

```zig
// After reading user input, before displaying
const highlighted = try self.highlighter.highlightLine(buffer.items);

// Redraw line with colors
try self.redrawWithHighlighting(highlighted);
```

**Tasks:**
- [ ] Add `highlighter: ?*Highlighter` field to Shell struct
- [ ] Initialize highlighter in `Shell.init()`
- [ ] Hook into readline loop
- [ ] Add `redrawWithHighlighting()` function
- [ ] Test: Type commands, see colors live

#### ✅ Color Theme
**File:** `src/themes.zig`

```zig
pub const Theme = struct {
    command: []const u8,         // Green
    builtin: []const u8,         // Cyan/Aquamarine
    flag: []const u8,            // Yellow
    string: []const u8,          // Magenta
    variable: []const u8,        // Blue
    operator: []const u8,        // Orange
    error_node: []const u8,      // Red
};

pub const ghost_hacker_blue = Theme{
    .command = "\x1b[32m",        // Green
    .builtin = "\x1b[36m",        // Cyan
    .flag = "\x1b[33m",           // Yellow
    .string = "\x1b[35m",         // Magenta
    .variable = "\x1b[34m",       // Blue
    .operator = "\x1b[38;5;208m", // Orange
    .error_node = "\x1b[31m",     // Red
};
```

**Tasks:**
- [ ] Create `src/themes.zig`
- [ ] Define `Theme` struct
- [ ] Add `ghost_hacker_blue` theme
- [ ] Wire into `applyTheme()`
- [ ] Test: All colors render correctly

---

### Phase 2: Command Validation (Week 2) - P0

#### ✅ PATH Validator
**File:** `src/command_validator.zig`

```zig
pub fn isCommandValid(command: []const u8) bool {
    // Check builtins first (instant)
    if (isBuiltin(command)) return true;

    // Check PATH
    const path_env = std.posix.getenv("PATH") orelse return false;
    var iter = std.mem.splitScalar(u8, path_env, ':');

    while (iter.next()) |dir| {
        const full_path = std.fmt.allocPrint(
            allocator,
            "{s}/{s}",
            .{dir, command},
        ) catch continue;
        defer allocator.free(full_path);

        if (std.fs.accessAbsolute(full_path, .{})) |_| {
            return true;
        } else |_| {}
    }

    return false;
}
```

**Tasks:**
- [ ] Create `src/command_validator.zig`
- [ ] Implement PATH checking
- [ ] Add builtin command list
- [ ] Cache results for performance
- [ ] Test: Valid vs invalid commands

#### ✅ Error Highlighting
**File:** `src/highlight.zig` (extend)

```zig
pub fn highlightWithValidation(
    self: *Highlighter,
    line: []const u8,
) ![]ColoredSegment {
    const spans = try self.realtime.highlightLine(line);
    const results = try grove.validateCommands(
        allocator,
        tree.rootNode(),
        line,
        isCommandValid,
    );

    // Override colors for invalid commands
    return try applyValidation(spans, results);
}
```

**Tasks:**
- [ ] Integrate `validateCommands()` API
- [ ] Pass custom validator function
- [ ] Override colors for invalid commands (red)
- [ ] Test: "invalidcmd" shows red, "ls" shows green

---

### Phase 3: Advanced Features (Week 3) - P1

#### ✅ Completion Context (Smart Tab)
**File:** `src/completion.zig` (extend existing)

```zig
pub fn getSmartCompletions(
    line: []const u8,
    cursor_pos: usize,
) ![]Completion {
    const context = try grove.getCompletionContext(
        allocator,
        tree.rootNode(),
        line,
        cursor_pos,
    );

    return switch (context.context) {
        .command => getCommandCompletions(context.partial),
        .flag => getFlagCompletions(context.command, context.partial),
        .file_path => getFileCompletions(context.partial),
        .variable => getVarCompletions(context.partial),
        else => &[_]Completion{},
    };
}
```

**Tasks:**
- [ ] Integrate `getCompletionContext()` API
- [ ] Route to appropriate completion source
- [ ] Test: Tab after "ls " suggests files
- [ ] Test: Tab after "ls -" suggests flags

#### ✅ Semantic Highlighting (Aliases/Variables)
**File:** `src/highlight.zig` (extend)

```zig
pub fn highlightSemantic(
    self: *Highlighter,
    line: []const u8,
    aliases: *AliasMap,
    vars: *VarMap,
) ![]ColoredSegment {
    const spans = try self.highlightWithValidation(line);

    // Override colors for aliases/variables
    for (spans) |*span| {
        if (aliases.get(span.text)) |_| {
            span.color = theme.alias; // Different color for aliases
        }

        if (std.mem.startsWith(u8, span.text, "$")) {
            if (vars.get(span.text[1..])) |_| {
                span.color = theme.defined_var;
            } else {
                span.color = theme.undefined_var; // Warning color
            }
        }
    }

    return spans;
}
```

**Tasks:**
- [ ] Access shell's alias/variable state
- [ ] Override colors for known aliases
- [ ] Highlight defined vs undefined variables
- [ ] Test: Alias "ll" shows special color
- [ ] Test: $UNDEFINED shows warning color

---

## 📊 Success Metrics

### Week 1 (Basic Highlighting)
- [ ] Commands highlighted green/cyan
- [ ] Flags highlighted yellow
- [ ] Strings highlighted magenta
- [ ] Variables highlighted blue
- [ ] Typing latency <5ms (imperceptible)

### Week 2 (Validation)
- [ ] Invalid commands show red in real-time
- [ ] Valid commands stay green
- [ ] PATH checking <10ms (cached)
- [ ] No false positives/negatives

### Week 3 (Advanced)
- [ ] Smart tab completion context-aware
- [ ] Aliases highlighted distinctly
- [ ] Undefined variables show warnings
- [ ] Performance: No lag on 100+ char lines

---

## 🎨 Visual Examples

### Before (Current):
```
gshell> ls -la | grep test
```
_(Plain white text)_

### After (Phase 1):
```
gshell> ls -la | grep test
        ^^     ^^^^      ^^^^
      green  yellow    green
```

### After (Phase 2):
```
gshell> invalidcmd -x
        ^^^^^^^^^^
           RED (command not found)

gshell> ls -la
        ^^
       GREEN (valid command)
```

### After (Phase 3):
```
gshell> ll /tmp
        ^^
      TEAL (alias, not command)

gshell> echo $UNDEFINED
             ^^^^^^^^^^
             ORANGE (variable not set - warning)
```

---

## 🚀 Quick Start (For You)

### 1. Add Grove Dependency

```bash
cd /data/projects/gshell
zig fetch --save https://github.com/GhostKellz/grove/archive/refs/tags/v0.1.1.tar.gz
```

### 2. Wire Into Build

```zig
// build.zig.zon
.dependencies = .{
    .grove = .{
        .url = "https://github.com/GhostKellz/grove/archive/refs/tags/v0.1.1.tar.gz",
        .hash = "...", // Will be filled by zig fetch
    },
    // ... existing deps
},
```

```zig
// build.zig
const grove_dep = b.dependency("grove", .{ .target = target, .optimize = optimize });
mod.addImport("grove", grove_dep.module("grove"));
```

### 3. Create Highlighter

```bash
touch src/highlight.zig
# Implement basic wrapper (see Phase 1 above)
```

### 4. Integrate & Test

```bash
zig build
./zig-out/bin/gshell
# Type: ls -la
# Should see colors!
```

---

## 💡 Pro Tips

1. **Start Simple:** Get basic highlighting working first, validate later
2. **Test Incrementally:** After each phase, test in actual shell usage
3. **Profile Performance:** Use `Parser.parseUtf8Timed` to verify <5ms
4. **Reuse Grove Tests:** Copy test patterns from `grove/src/editor/repl.zig`
5. **Visual QA:** Test with all 6 plugins enabled (git, docker, etc.)

---

## 📚 References

- **Grove API Docs:** `grove/README.md` (REPL/Shell Support section)
- **Grammar:** `gshell/grammar/grammar.js` + `queries/highlights.scm`
- **Grove Examples:** `grove/src/editor/repl.zig` (20+ tests)
- **Theme Colors:** `assets/vivid/ghost-hacker-blue.yml`

---

## 🔗 Related Docs

- `FUTURE_GRAMMAR.md` - Grammar sync process (in gshell repo)
- `DRAFT_DISCOVERY.md` - Grove integration planning
- `GHOSTLS_NEXT.md` - LSP support (Phase 4)

---

**Let's make gshell the prettiest shell ever!** 🎨🚀

_Last updated: 2025-10-11_
