# GPPrompt

**Native PowerLevel10k-style prompt system for GShell**

GPPrompt is GShell's built-in, zero-dependency prompt engine that brings PowerLevel10k functionality directly into your shell—no external binaries, no ZSH required. It's powered by [zfont](https://github.com/GhostKellz/zfont), our Zig library for Nerd Font icons and terminal rendering.

## Philosophy

> **One Binary to Customize**

Why install separate prompt systems when your shell can include everything out-of-the-box? GPPrompt replaces the need for PowerLevel10k + ZSH with a single, fast, native implementation written in Zig.

## Features

- **Two-line layout** with PowerLine separators (╭─ / ╰─)
- **Nerd Font icons** from zfont PowerLevel10k library
- **Ghost Hacker Blue** color theme (256-color ANSI)
- **Git integration** (branch, dirty status)
- **Zero external dependencies** (unlike Starship, Oh-My-Posh)
- **Lightning fast** (native Zig, no shell script overhead)
- **Fully customizable** via Ghostlang (.gza scripts)

## Quick Start

GPPrompt is enabled by default in new GShell installations. If you've disabled it, re-enable with:

```ghostlang
-- In your ~/.gshrc.gza
gprompt_enable()
```

## Default Prompt

```
╭─  arch  ~/projects/gshell   main*
╰─ ❯
```

Segments (left to right):
1. **OS Icon** - Arch Linux logo (configurable)
2. **Directory** - Current working directory (truncated)
3. **VCS** - Git branch with dirty indicator

## Configuration

### Enabling/Disabling

```ghostlang
-- Enable GPPrompt (default)
gprompt_enable()

-- Disable GPPrompt (fall back to segments or Starship)
gprompt_disable()

-- Check if enabled
if gprompt_is_enabled() then
    print("GPPrompt is active")
end
```

### Themes

GPPrompt ships with two built-in themes:

#### 1. GhostKellz (Default)
```ghostlang
-- Load in ~/.gshrc.gza
exec("source ~/.config/gshell/prompts/ghostkellz.gza")
```

**Features:**
- Two-line PowerLevel10k layout
- Ghost Hacker Blue color scheme
- Arch Linux icon
- Git branch with dirty marker

#### 2. Minimal
```ghostlang
-- Load in ~/.gshrc.gza
exec("source ~/.config/gshell/prompts/minimal.gza")
```

**Features:**
- Single-line prompt
- Basic git integration
- No Nerd Fonts required
- Format: `user@host ~/dir (main*) $`

### Custom Themes

Create your own theme file:

```ghostlang
-- ~/.config/gshell/prompts/my-theme.gza

-- Enable GPPrompt
gprompt_enable()

-- Your custom configuration here
-- (Color schemes, icon selection, segment order)
```

Load it in `~/.gshrc.gza`:

```ghostlang
exec("source ~/.config/gshell/prompts/my-theme.gza")
```

## Color Scheme

GPPrompt uses the **Ghost Hacker Blue** palette (256-color ANSI):

| Segment   | Foreground | Background | Description         |
|-----------|------------|------------|---------------------|
| OS Icon   | 18         | 33         | Dark blue/teal      |
| Directory | 122        | 68         | Aquamarine/green    |
| VCS       | 150        | 64         | Mint green/olive    |
| Prompt ✓  | 46         | -          | Success (green)     |
| Prompt ✗  | 196        | -          | Error (red)         |

## Nerd Font Icons

GPPrompt leverages zfont's PowerLevel10k icon library. Access icons via Ghostlang FFI:

```ghostlang
-- Get specific icon by name
local rust_icon = icon_get("RUST_ICON")
print("Rust: " .. rust_icon)

-- Convenience helpers
local arch = icon_arch()          --  Arch Linux
local git = icon_git_branch()     --  Git branch
local node = icon_nodejs()        --  Node.js
local folder = icon_folder()      --  Folder
local home = icon_home()          --  Home directory

-- Use in custom prompts
print(arch .. " Welcome to GShell!")
```

### Available Icons

See [zfont PowerLevel10k icon reference](https://github.com/GhostKellz/zfont/blob/main/src/powerlevel10k.zig) for the full list of 50+ programming language and OS icons.

## API Reference

### Core Functions

#### `gprompt_enable()`
Enables GPPrompt rendering engine.

```ghostlang
gprompt_enable()
```

**Returns:** `boolean` - `true` if successful, `false` otherwise

---

#### `gprompt_disable()`
Disables GPPrompt and falls back to segment-based or Starship prompt.

```ghostlang
gprompt_disable()
```

**Returns:** `boolean` - `true` if successful, `false` otherwise

---

#### `gprompt_is_enabled()`
Checks if GPPrompt is currently active.

```ghostlang
if gprompt_is_enabled() then
    print("Using native GPPrompt")
else
    print("Using fallback prompt")
end
```

**Returns:** `boolean` - `true` if enabled, `false` otherwise

---

### Icon Functions

#### `icon_get(icon_name)`
Retrieves a specific Nerd Font icon by name from the zfont PowerLevel10k library.

```ghostlang
local rust = icon_get("RUST_ICON")
local python = icon_get("PYTHON_ICON")
```

**Parameters:**
- `icon_name` (string) - Icon identifier (e.g., "RUST_ICON", "NODEJS_ICON")

**Returns:** `string` - UTF-8 encoded icon, or `nil` if not found

---

#### `icon_arch()`
Returns the Arch Linux logo icon.

```ghostlang
local arch = icon_arch()  --
```

**Returns:** `string` - Arch Linux Nerd Font icon

---

#### `icon_nodejs()`
Returns the Node.js logo icon.

```ghostlang
local node = icon_nodejs()  --
```

**Returns:** `string` - Node.js Nerd Font icon

---

#### `icon_git_branch()`
Returns the Git branch icon.

```ghostlang
local git = icon_git_branch()  --
```

**Returns:** `string` - Git branch Nerd Font icon

---

#### `icon_folder()`
Returns the folder icon.

```ghostlang
local folder = icon_folder()  --
```

**Returns:** `string` - Folder Nerd Font icon

---

#### `icon_home()`
Returns the home directory icon.

```ghostlang
local home = icon_home()  --
```

**Returns:** `string` - Home Nerd Font icon

---

## Architecture

GPPrompt is implemented in Zig and integrated into GShell's core:

```
src/prompts/ghostkellz.zig  → Native P10k renderer
src/prompt.zig              → Prompt engine (GPPrompt, Starship, Segments)
src/scripting.zig           → Ghostlang FFI bindings (gprompt_*, icon_*)
```

**Dependencies:**
- [zfont](https://github.com/GhostKellz/zfont) - PowerLevel10k icons, terminal rendering
- [gcode](https://github.com/GhostKellz/gcode) - Unicode/emoji support

## Comparison

| Feature                | GPPrompt          | PowerLevel10k | Starship       |
|------------------------|-------------------|---------------|----------------|
| External binary        | ❌ Built-in       | ❌ ZSH plugin | ✅ Separate    |
| Language               | Zig (native)      | ZSH (script)  | Rust (binary)  |
| Configuration          | Ghostlang (.gza)  | ZSH (.zsh)    | TOML           |
| Nerd Fonts             | ✅ zfont library  | ✅            | ✅             |
| Two-line layout        | ✅                | ✅            | ⚠️ Limited     |
| Instant prompt caching | 🚧 Planned        | ✅            | ❌             |
| Git integration        | ✅                | ✅            | ✅             |
| Version detection      | 🚧 Planned        | ✅            | ✅             |

## Examples

### Full GhostKellz Configuration

See [examples/gshrc-ghostkellz.gza](../../examples/gshrc-ghostkellz.gza) for a complete 200+ line configuration porting full ZSH + P10k functionality to GShell.

Highlights:
- GPPrompt with Ghost Hacker Blue theme
- GhostPlug plugin system (git, docker, network)
- Custom functions (proj_open, git_init_pro, sysinfo)
- Modern CLI tool aliases (lsd, bat, rg, fd)
- Nerd Font icon usage in welcome banner

### Switching Between Prompts

```ghostlang
-- Use GPPrompt by default
gprompt_enable()

-- Switch to Starship if available
if command_exists("starship") then
    gprompt_disable()
    use_starship(true)
end

-- Minimal prompt (no Nerd Fonts)
gprompt_disable()
enable_git_prompt()
```

## Troubleshooting

### Icons not displaying

**Problem:** Icons appear as `?` or boxes

**Solution:** Install a Nerd Font and configure your terminal:

```bash
# Install Nerd Font (Arch Linux)
sudo pacman -S ttf-meslo-nerd ttf-firacode-nerd

# Or via Homebrew (macOS)
brew tap homebrew/cask-fonts
brew install font-meslo-lg-nerd-font
```

Configure your terminal emulator to use "MesloLGS NF" or "FiraCode Nerd Font".

### GPPrompt not loading

**Problem:** Prompt doesn't change after `gprompt_enable()`

**Solution:** Check `~/.gshrc.gza` is sourced:

```ghostlang
-- Add to top of ~/.gshrc.gza
print("Loading .gshrc.gza")
```

If you don't see the message, GShell may not be in interactive mode or the config file path is incorrect.

### Colors appear wrong

**Problem:** Colors don't match Ghost Hacker Blue theme

**Solution:** Ensure your terminal supports 256-color mode:

```bash
echo $TERM  # Should be "xterm-256color" or similar

# Test 256-color support
curl -s https://gist.githubusercontent.com/lifepillar/09a44b8cf0f9397465614e622979107f/raw/24-bit-color.sh | bash
```

## Roadmap

- [ ] **Instant prompt caching** - Load cached prompt before config evaluation
- [ ] **Version detection segments** - Auto-detect Node.js, Rust, Go, Python versions
- [ ] **Command duration segment** - Show execution time for long commands
- [ ] **Custom segment API** - Define your own segments in Ghostlang
- [ ] **Right prompt support** - Add right-aligned segments
- [ ] **Transient prompt** - Collapse old prompts to save space
- [ ] **`gsh p10ksetup` wizard** - Interactive theme configuration

## Contributing

GPPrompt is part of GShell core. To contribute:

1. Core renderer: `src/prompts/ghostkellz.zig`
2. FFI bindings: `src/scripting.zig`
3. Icon library: [zfont repository](https://github.com/GhostKellz/zfont)

## See Also

- [GhostPlug Plugin System](../ghostplug/README.md)
- [Ghostlang Scripting Reference](../integration/ghostlang.md)
- [zfont Library Documentation](../vendor/zfont.md)
- [Configuration Examples](../../examples/)
