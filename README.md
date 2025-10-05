<p align="center">
  <img src="assets/icons/gshell.png" alt="GShell logo" width="180" />
</p>

![zig](https://img.shields.io/badge/Built%20with-Zig-yellow?logo=zig)
![zig-ver](https://img.shields.io/badge/zig-0.16.0--dev-orange?logo=zig)
![ghostlang](https://img.shields.io/badge/Powered%20by-Ghostlang-blueviolet?logo=ghost)
![status](https://img.shields.io/badge/Status-Beta%20Ready-success)

# GShell 🪐

**The Next-Generation Shell with Ghostlang Scripting**

A modern Linux shell that replaces Bash/Zsh/Fish with:
- **Ghostlang scripting** (Lua-like syntax) for configuration and plugins
- **Powerful FFI** - 30+ shell functions accessible from scripts
- **Modern UX** - Tab completion, Unicode support, Starship integration
- **Zig foundation** - Fast, safe, and maintainable

---

## ✨ Why GShell?

### 🎯 **Scriptable Everything**
Your `.gshrc.gza` config is a full Ghostlang script, not TOML:

```lua
-- ~/.gshrc.gza — Your shell configuration (Ghostlang!)

-- Set environment variables
setenv("EDITOR", "grim")
setenv("PAGER", "less")

-- Load plugins
enable_plugin("git")       -- 60+ git aliases + helpers
enable_plugin("docker")    -- Docker shortcuts
enable_plugin("kubectl")   -- Kubernetes helpers

-- Custom aliases
alias("ll", "ls -lah")
alias("...", "cd ../..")
alias("projects", "cd ~/projects")

-- Custom functions
function mkcd(dir)
    exec("mkdir -p " .. dir)
    cd(dir)
    print("Created and entered: " .. dir)
end

-- Conditional logic
if command_exists("starship") then
    use_starship(true)
end

if in_git_repo() then
    print("📁 Git branch: " .. git_branch())
end

print("🪐 GShell loaded!")
```

### 🚀 **Powerful Plugins**
Plugins are Ghostlang scripts with full shell access:

```lua
-- ~/.config/gshell/plugins/my-plugin/plugin.gza

-- Check requirements
if not command_exists("git") then
    error("Git plugin requires git!")
    return false
end

-- Define aliases
alias("gs", "git status -sb")
alias("gd", "git diff")

-- Define functions
function git_current_branch()
    if path_exists(".git/HEAD") then
        local head = read_file(".git/HEAD")
        return head:match("ref: refs/heads/(.+)")
    end
    return nil
end

function gcp(message)
    exec("git add .")
    exec("git commit -m '" .. message .. "'")
    exec("git push")
end

print("✓ My Plugin loaded")
return true
```

### 💪 **Rich FFI (30+ Functions)**

**Environment & Files**:
- `getenv(key)`, `setenv(key, value)`
- `read_file(path)`, `write_file(path, content)`
- `path_exists(path)`

**Shell Control**:
- `exec(command)` - Run shell commands
- `cd(path)` - Change directory
- `alias(name, command)` - Create alias
- `command_exists(cmd)` - Check if command in PATH

**Git Integration**:
- `in_git_repo()`, `git_branch()`, `git_dirty()`, `git_repo_root()`

**System Info**:
- `get_user()`, `get_hostname()`, `get_cwd()`

**Configuration**:
- `enable_plugin(name)` - Load plugin
- `use_starship(bool)` - Toggle Starship prompt
- `load_vivid_theme(theme)` - Set LS_COLORS theme
- `set_history_size(size)`, `set_history_file(path)`

[See full FFI reference](./PROGRESS_REPORT.md#1-ghostlang-ffi-bridge---fully-implemented-)

---

## 🚀 Quick Start

### Install
```bash
git clone https://github.com/ghostkellz/gshell
cd gshell
zig build
sudo cp zig-out/bin/gshell /usr/local/bin/
```

### Initialize Config
```bash
# Create ~/.gshrc.gza with examples
gshell init

# Force overwrite if it exists
gshell init --force
```

### Run
```bash
# Interactive shell
gshell

# Execute a command
gshell --command "echo Hello"

# Run a Ghostlang script
gshell script.gza
```

---

## 🎨 Features

### ✅ **Tab Completion**
- Commands from `$PATH`
- Files and directories
- Context-aware (commands vs arguments)
- Smart prefix matching

Press **Tab** to complete:
```bash
gshell> git che<Tab>
git checkout
```

### ✅ **Job Control**
```bash
# Background jobs
sleep 10 &

# List jobs
jobs

# Foreground job
fg %1
```

### ✅ **History**
- Persistent history (`~/.gshell_history`)
- Search with `Ctrl+R`
- Navigate with `↑` / `↓`

### ✅ **Unicode-Aware Editing**
Powered by [gcode](https://github.com/ghostkellz/gcode):
- Grapheme cluster navigation
- Emoji support (🎉 counts as 1 character)
- CJK character handling
- Combining marks

### ✅ **Starship Integration**
```lua
-- In your .gshrc.gza
if command_exists("starship") then
    use_starship(true)
end
```

Get [Starship](https://starship.rs) for beautiful prompts!

### ✅ **Vivid Themes**
```lua
-- Load LS_COLORS themes
if command_exists("vivid") then
    load_vivid_theme("ghost-hacker-blue")
    -- or: tokyonight-night, dracula, etc.
end
```

---

## 📦 Built-in Plugins

### **Git** (`enable_plugin("git")`)
60+ aliases and helpers:
- `gs` → `git status -sb`
- `gc` → `git commit`
- `gd` → `git diff`
- `gps` → `git push`
- `gpl` → `git pull`
- `gcp(msg)` → add + commit + push
- `gundo()` → undo last commit
- And many more...

[See full git plugin](./assets/plugins/git/plugin.gza)

### **Docker** (`enable_plugin("docker")`)
Docker shortcuts and helpers

### **Kubectl** (`enable_plugin("kubectl")`)
Kubernetes command shortcuts

### **Network** (`enable_plugin("network")`)
Networking utilities

### **Dev Tools** (`enable_plugin("dev-tools")`)
Development tool helpers

### **System** (`enable_plugin("system")`)
System information commands

---

## 🔧 Configuration

### Config File Locations

GShell looks for config in this order:
1. `--config <path>` flag
2. `$GSHELL_CONFIG` environment variable
3. `~/.gshrc.gza` (Ghostlang config)
4. `~/.gshrc` (legacy, for backward compatibility)

### Example Config

```lua
-- ~/.gshrc.gza

-- ============================================================
-- Environment Setup
-- ============================================================
setenv("EDITOR", "nvim")
setenv("PAGER", "less -R")
setenv("SHELL", "/usr/bin/gshell")

-- ============================================================
-- Plugins
-- ============================================================
enable_plugin("git")
enable_plugin("docker")

-- ============================================================
-- Aliases
-- ============================================================
alias("ll", "ls -lah --color=auto")
alias("la", "ls -A")
alias("...", "cd ../..")
alias("grep", "grep --color=auto")
alias("update", "sudo pacman -Syu")

-- ============================================================
-- Custom Functions
-- ============================================================

-- Create directory and cd into it
function mkcd(dir)
    if not dir then
        error("Usage: mkcd <directory>")
        return
    end
    exec("mkdir -p " .. dir)
    cd(dir)
end

-- Quick backup
function backup(file)
    if path_exists(file) then
        exec("cp " .. file .. " " .. file .. ".backup")
        print("Backed up: " .. file)
    end
end

-- ============================================================
-- Prompt Configuration
-- ============================================================
if command_exists("starship") then
    use_starship(true)
else
    -- Built-in prompt (default)
    use_starship(false)
end

-- ============================================================
-- Theme Configuration
-- ============================================================
if command_exists("vivid") then
    load_vivid_theme("ghost-hacker-blue")
end

-- ============================================================
-- History
-- ============================================================
set_history_size(10000)
set_history_file(getenv("HOME") .. "/.gshell_history")

-- ============================================================
-- Startup Message
-- ============================================================
print("🪐 GShell v0.1.0-alpha loaded!")

if in_git_repo() then
    local branch = git_branch()
    local dirty = git_dirty() and "*" or ""
    print("📁 Git: " .. branch .. dirty)
end
```

---

## 🏗️ Architecture

### Tech Stack

- **[Zig](https://ziglang.org)** - Systems programming language
- **[Ghostlang](https://github.com/ghostkellz/ghostlang)** - Scripting engine
- **[Flash](https://github.com/ghostkellz/flash)** - CLI framework
- **[Flare](https://github.com/ghostkellz/flare)** - Configuration (TOML fallback)
- **[gcode](https://github.com/ghostkellz/gcode)** - Unicode handling
- **[zsync](https://github.com/ghostkellz/zsync)** - Async runtime
- **[zqlite](https://github.com/ghostkellz/zqlite)** - SQLite wrapper (history)

### Project Structure

```
gshell/
├── src/
│   ├── main.zig              # Entry point
│   ├── shell.zig             # Shell runtime
│   ├── scripting.zig         # Ghostlang FFI bridge
│   ├── completion.zig        # Tab completion
│   ├── prompt.zig            # Prompt rendering
│   ├── parser.zig            # Command parser
│   ├── executor.zig          # Command executor
│   ├── state.zig             # Shell state (jobs, aliases, env)
│   ├── history.zig           # History management
│   └── builtins/             # Built-in commands
├── assets/
│   ├── templates/
│   │   └── default.gshrc.gza # Default config template
│   └── plugins/              # Built-in plugins
│       ├── git/
│       ├── docker/
│       ├── kubectl/
│       └── ...
└── build.zig                 # Build configuration
```

---

## 📚 Documentation

- **[Progress Report](./PROGRESS_REPORT.md)** - Detailed feature status
- **[FFI Reference](./PROGRESS_REPORT.md#1-ghostlang-ffi-bridge---fully-implemented-)** - All 30+ shell functions
- **[Ghostlang Docs](https://github.com/ghostkellz/ghostlang)** - Language reference
- **[Plugin Development](./assets/plugins/git/plugin.gza)** - Example plugin

---

## 🧪 Development

### Build
```bash
# Debug build
zig build

# Release build
zig build -Doptimize=ReleaseFast

# Run tests
zig build test
```

### Test FFI
```bash
# Create test script
cat > test.gza << 'EOF'
print("Testing FFI...")
setenv("TEST", "value")
print(getenv("TEST"))
if path_exists("/tmp") then
    print("✓ /tmp exists")
end
print("Done!")
EOF

# Run it
./zig-out/bin/gshell test.gza
```

### Create Plugin
```bash
mkdir -p ~/.config/gshell/plugins/my-plugin
cat > ~/.config/gshell/plugins/my-plugin/plugin.gza << 'EOF'
-- My custom plugin

print("Loading my-plugin...")

alias("myalias", "echo 'Hello from plugin'")

function my_function()
    print("Custom function called!")
end

print("✓ My plugin loaded")
return true
EOF

# Load it in ~/.gshrc.gza
# enable_plugin("my-plugin")
```

---

## 🎯 Roadmap

### ✅ Beta Ready (v0.1.0)
- [x] Ghostlang FFI (30+ functions)
- [x] Tab completion
- [x] Job control
- [x] History management
- [x] Plugin system (6 plugins)
- [x] Starship integration
- [x] Vivid themes
- [x] Unicode editing (gcode)

### 🔄 In Progress
- [ ] Async Git prompt (zsync-powered)
- [ ] Networking builtins
- [ ] Comprehensive test suite
- [ ] Documentation website

### 📋 Planned (v0.2.0+)
- [ ] Ghostlang v0.2 features (tables, arrays, loops)
- [ ] Shell completion generation (bash/zsh/fish)
- [ ] Plugin marketplace
- [ ] Themes system
- [ ] More built-in plugins (npm, cargo, python, etc.)
- [ ] Performance optimizations

---

## 🤝 Contributing

Contributions are welcome! Areas where help is needed:

1. **Plugins** - Create plugins for popular tools (npm, cargo, etc.)
2. **Testing** - Write integration tests
3. **Documentation** - Improve docs and examples
4. **Networking** - Implement networking builtins
5. **Async Prompts** - Complete async Git prompt with zsync

See [PROGRESS_REPORT.md](./PROGRESS_REPORT.md) for current status.

---

## 📜 License

MIT License - see [LICENSE](./LICENSE) for details

---

## 🙏 Credits

**Built by**: [ghostkellz](https://github.com/ghostkellz)
**Powered by**:
- [Ghostlang](https://github.com/ghostkellz/ghostlang) - Scripting engine
- [Flash](https://github.com/ghostkellz/flash) - CLI framework
- [gcode](https://github.com/ghostkellz/gcode) - Unicode handling

**Special thanks** to the Zig community and all contributors!

---

<p align="center">
  <strong>🪐 Built with Zig and Ghostlang 🪐</strong>
</p>
