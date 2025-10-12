# GShell Documentation

**Next-generation Linux shell with built-in PowerLevel10k and plugin system**

Welcome to the GShell documentation! GShell replaces the need for separate PowerLevel10k + ZSH installations with a single, fast, native binary written in Zig.

## Philosophy

> **One Binary to Customize**

Why manage multiple tools when your shell can include everything out-of-the-box? GShell provides:
- **GPPrompt** - Native PowerLevel10k-style prompt system (no external dependencies)
- **GhostPlug** - Plugin system for extending functionality (no Oh-My-Zsh needed)
- **Ghostlang** - Lua-like scripting language for configuration (.gza files)

## Quick Links

### Core Features
- [**GPPrompt**](gprompt/README.md) - PowerLevel10k-style prompt with Nerd Font icons
- [**GhostPlug**](ghostplug/README.md) - 3rd party plugin system
- [**Ghostlang**](integration/ghostlang.md) - Scripting language and FFI API reference

### Vendor Libraries
- [**zfont**](vendor/zfont.md) - Nerd Font icons and PowerLevel10k rendering
- [**gcode**](vendor/gcode.md) - Unicode/emoji support for terminals

## Documentation Structure

```
docs/
├── README.md                    # This file
├── gprompt/
│   └── README.md               # GPPrompt prompt system
├── ghostplug/
│   └── README.md               # GhostPlug plugin system
├── integration/
│   └── ghostlang.md            # Ghostlang scripting reference
└── vendor/
    ├── zfont.md                # zfont library integration
    └── gcode.md                # gcode library integration
```

## Getting Started

### Installation

```bash
# Clone and build
git clone https://github.com/GhostKellz/gshell
cd gshell
zig build -Doptimize=ReleaseFast

# Install binary
sudo cp zig-out/bin/gshell /usr/local/bin/

# Initialize configuration
gshell init
```

### First Run

GShell creates `~/.gshrc.gza` on first run with GPPrompt enabled by default:

```ghostlang
-- ~/.gshrc.gza

-- Enable GPPrompt (PowerLevel10k-style)
gprompt_enable()

-- Enable plugins
enable_plugin("git")

-- Set environment
setenv("EDITOR", "nvim")
setenv("PAGER", "less")

-- Create aliases
alias("ll", "ls -lah")
alias("gs", "git status")
```

### Default Prompt

```
╭─  arch  ~/projects/gshell   main*
╰─ ❯
```

## Key Features

### 1. GPPrompt - Built-in PowerLevel10k

**No external dependencies required** - GPPrompt is compiled directly into GShell.

- Two-line layout with PowerLine separators (╭─ / ╰─)
- Nerd Font icons from zfont PowerLevel10k library
- Ghost Hacker Blue color theme (256-color ANSI)
- Git integration (branch, dirty status)
- Lightning fast (native Zig, no script overhead)

[📚 Read GPPrompt Documentation](gprompt/README.md)

**Quick Example:**
```ghostlang
-- Enable GPPrompt
gprompt_enable()

-- Use icons in scripts
local arch = icon_arch()
local git = icon_git_branch()
print(arch .. " Welcome to GShell " .. git)
```

---

### 2. GhostPlug - Plugin System

**Zero-dependency plugins** written in Ghostlang (.gza).

Built-in plugins:
- **git** - 80+ git aliases and helpers
- **docker** - Docker and docker-compose shortcuts
- **network** - Network utilities and diagnostics
- **kubectl** - Kubernetes helpers
- **dev-tools** - Version detection (Node, Rust, Go, Python)
- **system** - System information and monitoring

[📚 Read GhostPlug Documentation](ghostplug/README.md)

**Quick Example:**
```ghostlang
-- Enable built-in plugins
enable_plugin("git")
enable_plugin("docker")

-- Load custom plugin
enable_plugin("myplugin", "~/.config/gshell/plugins/myplugin")
```

---

### 3. Ghostlang - Configuration Language

**Lua-like syntax** for shell configuration and automation.

- Familiar syntax (variables, functions, loops, conditionals)
- Deep GShell integration via FFI
- Access to 50+ shell functions
- Plugin development support

[📚 Read Ghostlang Documentation](integration/ghostlang.md)

**Quick Example:**
```ghostlang
-- Custom function
function mkcd(dir)
    exec("mkdir -p " .. dir)
    cd(dir)
    print("Created and entered: " .. dir)
end

-- Use it
mkcd("~/projects/mynewproject")
```

---

## Configuration Examples

### Minimal Configuration

```ghostlang
-- ~/.gshrc.gza - Minimal

gprompt_disable()
enable_git_prompt()

alias("ll", "ls -lah")
```

### GhostKellz Configuration

Full 200+ line configuration example: [examples/gshrc-ghostkellz.gza](../examples/gshrc-ghostkellz.gza)

Features:
- GPPrompt with Ghost Hacker Blue theme
- 6 plugins (git, docker, network, kubectl, dev-tools, system)
- Modern CLI tool aliases (lsd, bat, rg, fd)
- Custom functions (proj_open, git_init_pro, sysinfo)
- Nerd Font icon usage in welcome banner
- Tool availability checking

---

## API Quick Reference

### Prompt Control
```ghostlang
gprompt_enable()              -- Enable GPPrompt
gprompt_disable()             -- Disable GPPrompt
gprompt_is_enabled()          -- Check if enabled
enable_git_prompt()           -- Simple git prompt
use_starship(true)            -- Use Starship (if installed)
```

### Nerd Font Icons
```ghostlang
icon_get("RUST_ICON")         --
icon_arch()                   --
icon_nodejs()                 --
icon_git_branch()             --
icon_folder()                 --
icon_home()                   --
```

### Plugins
```ghostlang
enable_plugin("git")          -- Load plugin
disable_plugin("git")         -- Unload plugin
plugin_loaded("git")          -- Check if loaded
reload_plugin("git")          -- Reload plugin
```

### File System
```ghostlang
path_exists("/path")          -- Check if path exists
is_file("/path")              -- Check if file
is_dir("/path")               -- Check if directory
read_file("/path")            -- Read file contents
write_file("/path", data)     -- Write file
list_dirs("/path")            -- List directories
list_files("/path")           -- List files
```

### Shell Operations
```ghostlang
exec("command")               -- Execute command
cd("/path")                   -- Change directory
get_cwd()                     -- Current directory
get_user()                    -- Username
get_hostname()                -- Hostname
command_exists("git")         -- Check if command available
```

### Git Integration
```ghostlang
in_git_repo()                 -- Check if in repo
git_branch()                  -- Current branch
git_dirty()                   -- Uncommitted changes
git_ahead_behind()            -- Ahead/behind remote
```

### Environment
```ghostlang
getenv("HOME")                -- Get env var
setenv("EDITOR", "nvim")      -- Set env var
alias("ll", "ls -lah")        -- Create alias
unalias("ll")                 -- Remove alias
```

[📚 Full API Reference](integration/ghostlang.md)

---

## Vendor Libraries

### zfont - Nerd Font Icons
Provides 50+ Nerd Font icons from PowerLevel10k library.

[📚 Read zfont Documentation](vendor/zfont.md)

**Icons Available:**
- Languages: Rust, Python, Go, Node.js, Ruby, Java, C++, etc.
- OS: Arch Linux, Ubuntu, Debian, Fedora, macOS, Windows
- Tools: Docker, Kubernetes, Git, Vim, React, Vue, Angular
- Files: Folder, Home, File, Git Branch

**Color Support:**
- 256-color ANSI codes
- Ghost Hacker Blue palette
- PowerLine separators

---

### gcode - Unicode/Emoji Support
Handles Unicode grapheme clusters and emoji rendering.

[📚 Read gcode Documentation](vendor/gcode.md)

**Features:**
- Display width calculation (accounts for double-width CJK, emoji)
- Terminal-aware truncation
- Grapheme cluster iteration
- UTF-8 validation
- Emoji ZWJ sequence support

---

## Comparison

### GPPrompt vs Others

| Feature                | GPPrompt          | PowerLevel10k | Starship       |
|------------------------|-------------------|---------------|----------------|
| External binary        | ❌ Built-in       | ❌ ZSH plugin | ✅ Separate    |
| Language               | Zig (native)      | ZSH (script)  | Rust (binary)  |
| Configuration          | Ghostlang (.gza)  | ZSH (.zsh)    | TOML           |
| Nerd Fonts             | ✅ zfont library  | ✅            | ✅             |
| Two-line layout        | ✅                | ✅            | ⚠️ Limited     |
| Git integration        | ✅                | ✅            | ✅             |

### GhostPlug vs Others

| Feature                | GhostPlug       | Oh-My-Zsh    | Prezto        |
|------------------------|-----------------|--------------|---------------|
| Language               | Ghostlang       | ZSH          | ZSH           |
| Plugin count (built-in)| 6               | 200+         | 100+          |
| 3rd party support      | ✅ Git/Local    | ✅ Git       | ✅ Git        |
| Manifest system        | ✅ TOML         | ❌           | ❌            |
| Dependency checking    | ✅ Auto         | ⚠️ Manual    | ⚠️ Manual     |
| Hot reloading          | ✅              | ❌           | ❌            |

---

## Building from Source

### Requirements
- Zig 0.13.0 or later
- Linux (x86_64, ARM64)
- Nerd Font (for icons)

### Build Commands

```bash
# Debug build
zig build

# Optimized release build
zig build -Doptimize=ReleaseFast

# Run tests
zig build test

# Install
sudo cp zig-out/bin/gshell /usr/local/bin/
```

### Binary Sizes
- Debug: ~81MB
- ReleaseFast: ~20MB

---

## Contributing

GShell is open source and welcomes contributions!

### Core Shell
- Repository: [GhostKellz/gshell](https://github.com/GhostKellz/gshell)
- Language: Zig
- Files: `src/*.zig`

### Vendor Libraries
- zfont: [GhostKellz/zfont](https://github.com/GhostKellz/zfont)
- gcode: [GhostKellz/gcode](https://github.com/GhostKellz/gcode)

### Plugin Development
Create plugins in `assets/plugins/`:
1. Create directory with `manifest.toml` and `plugin.gza`
2. Document in `docs/ghostplug/plugins/`
3. Submit PR

---

## Roadmap

### GPPrompt
- [ ] Instant prompt caching
- [ ] Version detection segments (Node, Rust, Go, Python)
- [ ] Command duration segment
- [ ] Custom segment API
- [ ] Right prompt support
- [ ] Transient prompt
- [ ] `gsh p10ksetup` wizard

### GhostPlug
- [ ] GhostPlug registry
- [ ] `gsh plugin` CLI (install, update, search)
- [ ] Plugin sandboxing
- [ ] Performance profiling
- [ ] Auto-update
- [ ] Plugin dependencies
- [ ] Plugin hooks

### Core Shell
- [ ] Completion system
- [ ] Syntax highlighting
- [ ] Vi mode
- [ ] Command history search (Ctrl-R)
- [ ] Job control
- [ ] Signal handling improvements

---

## Troubleshooting

### Icons not displaying
**Solution:** Install a Nerd Font and configure your terminal:

```bash
# Arch Linux
sudo pacman -S ttf-meslo-nerd ttf-firacode-nerd

# Homebrew (macOS)
brew tap homebrew/cask-fonts
brew install font-meslo-lg-nerd-font
```

Configure terminal to use "MesloLGS NF" or "FiraCode Nerd Font".

### Colors appear wrong
**Solution:** Ensure terminal supports 256-color mode:

```bash
echo $TERM  # Should be "xterm-256color"
```

### Config not loading
**Solution:** Check `~/.gshrc.gza` is sourced:

```ghostlang
-- Add to top of ~/.gshrc.gza
print("Loading .gshrc.gza")
```

---

## Support

- **Issues**: [GitHub Issues](https://github.com/GhostKellz/gshell/issues)
- **Discussions**: [GitHub Discussions](https://github.com/GhostKellz/gshell/discussions)
- **IRC**: `#gshell` on Libera.Chat

---

## License

GShell is licensed under the MIT License. See [LICENSE](../LICENSE) for details.

---

## Acknowledgments

GShell is built on the shoulders of giants:
- **PowerLevel10k** - Inspiration for GPPrompt
- **Oh-My-Zsh** - Inspiration for GhostPlug
- **Starship** - Modern prompt design ideas
- **Zig** - Systems programming language
- **Nerd Fonts** - Icon font collection

---

**GShell** - One Binary to Customize
Built with ⚡ by [GhostKellz](https://github.com/GhostKellz)
