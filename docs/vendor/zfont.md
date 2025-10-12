# zfont Library

**Nerd Font icons and PowerLevel10k rendering for Zig**

[zfont](https://github.com/GhostKellz/zfont) is a Zig library providing Nerd Font icon support and PowerLevel10k-style prompt rendering. It powers GShell's GPPrompt system.

## Overview

zfont provides:
- **50+ Nerd Font icons** from PowerLevel10k library
- **PowerLine symbol rendering** (, , , etc.)
- **256-color ANSI support** for terminal styling
- **Segment-based prompt layout** (OS, Directory, VCS)
- **Zero-copy string handling** for performance

## Integration in GShell

zfont is integrated as a Zig dependency in `build.zig.zon`:

```zig
.dependencies = .{
    .zfont = .{
        .url = "https://github.com/GhostKellz/zfont/archive/<commit>.tar.gz",
        .hash = "<hash>",
    },
},
```

## Usage in GShell Core

### Importing zfont

```zig
const zfont = @import("zfont");
```

### PowerLevel10k Icons

```zig
const prog_manager = zfont.ProgrammingFonts.ProgrammingFontManager.init(allocator);
defer prog_manager.deinit();

const p10k = zfont.PowerLevel10k.init(allocator, &prog_manager);
defer p10k.deinit();

// Get icon by name
if (p10k.getIcon("RUST_ICON")) |icon| {
    std.debug.print("Rust icon: {s}\n", .{icon.symbol});
}
```

### Available Icons

zfont provides icons for:

**Programming Languages:**
- `RUST_ICON` -
- `PYTHON_ICON` -
- `GO_ICON` -
- `NODEJS_ICON` -
- `RUBY_ICON` -
- `JAVA_ICON` - ☕
- `CPP_ICON` -
- `CSHARP_ICON` -
- `PHP_ICON` -
- `SWIFT_ICON` -
- `KOTLIN_ICON` -
- `SCALA_ICON` -
- `HASKELL_ICON` -
- `ELIXIR_ICON` -
- `ERLANG_ICON` -
- `LUA_ICON` -

**Operating Systems:**
- `LINUX_ARCH_ICON` -
- `LINUX_UBUNTU_ICON` -
- `LINUX_DEBIAN_ICON` -
- `LINUX_FEDORA_ICON` -
- `APPLE_ICON` -
- `WINDOWS_ICON` -

**Tools & Frameworks:**
- `DOCKER_ICON` -
- `KUBERNETES_ICON` - ☸
- `GIT_ICON` -
- `VIM_ICON` -
- `REACT_ICON` -
- `VUE_ICON` -
- `ANGULAR_ICON` -

**Files & Folders:**
- `FOLDER_ICON` -
- `HOME_ICON` -
- `FILE_ICON` -
- `VCS_BRANCH_ICON` -

**PowerLine Symbols:**
- `LEFT_SEGMENT_SEPARATOR` -
- `RIGHT_SEGMENT_SEPARATOR` -
- `LEFT_SUBSEGMENT_SEPARATOR` -
- `RIGHT_SUBSEGMENT_SEPARATOR` -

See [zfont/src/powerlevel10k.zig](https://github.com/GhostKellz/zfont/blob/main/src/powerlevel10k.zig) for the complete list.

## PowerLine Rendering

zfont provides utilities for rendering PowerLevel10k-style segments with PowerLine separators.

### Segment Structure

```zig
pub const Segment = struct {
    text: []const u8,
    fg_color: u8,    // 256-color foreground
    bg_color: u8,    // 256-color background
    icon: ?[]const u8,
};
```

### Rendering Segments

```zig
const segments = [_]zfont.Segment{
    .{
        .text = "arch",
        .fg_color = 18,
        .bg_color = 33,
        .icon = " ",
    },
    .{
        .text = "~/projects/gshell",
        .fg_color = 122,
        .bg_color = 68,
        .icon = null,
    },
    .{
        .text = "main*",
        .fg_color = 150,
        .bg_color = 64,
        .icon = " ",
    },
};

for (segments) |segment| {
    // Render with PowerLine separators
    try renderSegment(writer, segment);
}
```

## Color Scheme

zfont uses 256-color ANSI codes for styling.

### ANSI Color Format

```zig
// Foreground: \x1b[38;5;<code>m
// Background: \x1b[48;5;<code>m
// Reset: \x1b[0m
```

### Ghost Hacker Blue Palette

| Color Name    | ANSI Code | RGB Approx   | Usage            |
|---------------|-----------|--------------|------------------|
| Dark Blue     | 18        | #000087      | OS icon FG       |
| Teal          | 33        | #0087ff      | OS icon BG       |
| Aquamarine    | 122       | #87ffd7      | Directory FG     |
| Green         | 68        | #5f87d7      | Directory BG     |
| Mint Green    | 150       | #afd787      | VCS FG           |
| Olive         | 64        | #5f8700      | VCS BG           |
| Bright Green  | 46        | #00ff00      | Success prompt   |
| Bright Red    | 196       | #ff0000      | Error prompt     |

### Example Usage

```zig
const std = @import("std");

fn renderColored(writer: anytype, text: []const u8, fg: u8, bg: u8) !void {
    try writer.print("\x1b[38;5;{d}m", .{fg});  // Foreground
    try writer.print("\x1b[48;5;{d}m", .{bg});  // Background
    try writer.writeAll(text);
    try writer.writeAll("\x1b[0m");  // Reset
}
```

## GShell Integration Points

### 1. GPPrompt Renderer

**File:** `src/prompts/ghostkellz.zig`

Uses zfont to render PowerLevel10k-style prompt:

```zig
const zfont = @import("zfont");

pub fn renderGhostKellz(
    allocator: std.mem.Allocator,
    context: PromptContext,
) ![]const u8 {
    const prog_manager = zfont.ProgrammingFonts.ProgrammingFontManager.init(allocator);
    defer prog_manager.deinit();

    const p10k = zfont.PowerLevel10k.init(allocator, &prog_manager);
    defer p10k.deinit();

    // Get icons
    const arch_icon = p10k.getIcon("LINUX_ARCH_ICON") orelse "";
    const git_icon = p10k.getIcon("VCS_BRANCH_ICON") orelse "";

    // Build prompt with segments
    // ...
}
```

### 2. Ghostlang FFI

**File:** `src/scripting.zig`

Exposes zfont icons to Ghostlang:

```zig
fn shellIconGet(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    const icon_name = args[0].string;

    const zfont = @import("zfont");
    const prog_manager = zfont.ProgrammingFonts.ProgrammingFontManager.init(allocator);
    defer prog_manager.deinit();

    const p10k = zfont.PowerLevel10k.init(allocator, &prog_manager);
    defer p10k.deinit();

    if (p10k.getIcon(icon_name)) |icon| {
        return ghostlang.ScriptValue{ .string = icon.symbol };
    }

    return ghostlang.ScriptValue{ .nil = {} };
}
```

### 3. Prompt Engine

**File:** `src/prompt.zig`

Integrates GPPrompt into prompt rendering pipeline:

```zig
pub fn render(self: *PromptEngine) ![]const u8 {
    if (self.use_ghostkellz) {
        return try ghostkellz.renderGhostKellz(self.allocator, self.context);
    }

    // Fallback to other prompt systems
    // ...
}
```

## API Reference

### Types

#### `Icon`
```zig
pub const Icon = struct {
    name: []const u8,
    symbol: []const u8,
    description: ?[]const u8,
};
```

#### `ProgrammingFontManager`
```zig
pub const ProgrammingFontManager = struct {
    pub fn init(allocator: std.mem.Allocator) ProgrammingFontManager;
    pub fn deinit(self: *ProgrammingFontManager) void;
};
```

#### `PowerLevel10k`
```zig
pub const PowerLevel10k = struct {
    pub fn init(
        allocator: std.mem.Allocator,
        manager: *ProgrammingFontManager,
    ) PowerLevel10k;

    pub fn deinit(self: *PowerLevel10k) void;

    pub fn getIcon(self: *PowerLevel10k, name: []const u8) ?Icon;
};
```

## Building with zfont

zfont is automatically built as part of GShell's build process:

```bash
# Build GShell (includes zfont)
zig build

# Build with optimizations
zig build -Doptimize=ReleaseFast
```

## Testing zfont Integration

```bash
# Test icon rendering
gshell -c 'print(icon_arch())'

# Test GPPrompt
gshell -c 'gprompt_enable(); print("GPPrompt enabled")'
```

## Performance Considerations

1. **Icon Manager Lifetime** - Create once per prompt render, not per icon
2. **String Ownership** - Icons are owned by PowerLevel10k, don't free them
3. **ANSI Escape Codes** - Minimal overhead, rendered directly to terminal

## Troubleshooting

### Icons not displaying

**Problem:** Icons appear as `?` or boxes

**Solution:** Install a Nerd Font:

```bash
# Arch Linux
sudo pacman -S ttf-meslo-nerd ttf-firacode-nerd

# Homebrew (macOS)
brew tap homebrew/cask-fonts
brew install font-meslo-lg-nerd-font
```

Configure terminal to use "MesloLGS NF" or "FiraCode Nerd Font".

### Compilation errors

**Problem:** zfont not found during build

**Solution:** Ensure `build.zig.zon` contains zfont dependency:

```bash
# Fetch dependencies
zig fetch --save https://github.com/GhostKellz/zfont/archive/<commit>.tar.gz
```

### Wrong icons displayed

**Problem:** Icons don't match expected symbols

**Solution:** Check Nerd Font version and icon name:

```zig
if (p10k.getIcon("RUST_ICON")) |icon| {
    std.debug.print("Icon: {s} (U+{X})\n", .{icon.symbol, @as(u32, icon.symbol[0])});
}
```

## Contributing to zfont

zfont is a separate project. To contribute:

1. Fork [GhostKellz/zfont](https://github.com/GhostKellz/zfont)
2. Add new icons to `src/powerlevel10k.zig`
3. Update icon lookup table
4. Submit PR

## See Also

- [zfont GitHub Repository](https://github.com/GhostKellz/zfont)
- [GPPrompt Documentation](../gprompt/README.md)
- [Nerd Fonts Official Site](https://www.nerdfonts.com/)
- [PowerLevel10k ZSH Theme](https://github.com/romkatv/powerlevel10k)
- [ANSI 256-Color Chart](https://upload.wikimedia.org/wikipedia/commons/1/15/Xterm_256color_chart.svg)
