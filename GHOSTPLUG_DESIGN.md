# GhostPlug - GShell Plugin System Design

## Overview
GhostPlug is GShell's plugin architecture, inspired by OhMyZsh but designed for Zig/Ghostlang integration.

## Architecture Analysis from OhMyZsh

### OhMyZsh Structure
```
ohmyzsh/
├── lib/              # Core library functions
├── plugins/          # Official plugins
│   └── <name>/
│       ├── <name>.plugin.zsh
│       ├── completions/
│       └── README.md
├── custom/           # User overrides
├── themes/           # Prompt themes
└── oh-my-zsh.sh     # Main loader
```

### Key Concepts
1. **Plugin Discovery**: Check `plugins/$name/$name.plugin.zsh`
2. **Lazy Loading**: Check if command exists before loading
3. **Completion Caching**: Generate/cache completions separately
4. **Override System**: Custom directory can override official plugins
5. **Alias Management**: Can disable aliases via zstyle

## GhostPlug Design for GShell

### Directory Structure
```
gshell/
├── src/
│   ├── plugins.zig          # Plugin loader/manager
│   └── ghostplug/           # Built-in plugins (optional)
│       └── git/
│           ├── plugin.gza   # Ghostlang script
│           └── manifest.toml
├── ~/.config/gshell/
│   ├── plugins/             # User plugins
│   │   └── <name>/
│   │       ├── plugin.gza   # Ghostlang entry point
│   │       ├── manifest.toml
│   │       └── bin/         # Optional external binaries
│   └── ghostplug.toml       # Enabled plugins config
```

### Plugin Types

#### 1. Ghostlang Plugins (Primary)
- Written in Ghostlang (.gza files)
- Use FFI to access shell functions
- Can define aliases, functions, hooks

**Example: `git/plugin.gza`**
```lua
-- Git plugin for GShell
-- Provides git aliases and utilities

-- Check if git is available
if not exec("which git") then
    error("git not found")
    return
end

-- Define aliases
alias("gs", "git status")
alias("ga", "git add")
alias("gc", "git commit")
alias("gp", "git push")
alias("gl", "git pull")
alias("glog", "git log --oneline --graph --decorate")

-- Helper function
function git_current_branch()
    local branch = read_file(".git/HEAD")
    if branch then
        return branch:match("ref: refs/heads/(.+)")
    end
    return nil
end

-- Register completion function (future)
-- register_completion("git", git_complete)
```

#### 2. Native Plugins (Advanced)
- Compiled Zig modules
- Loaded as shared libraries
- For performance-critical operations

**Example manifest: `manifest.toml`**
```toml
name = "git"
version = "1.0.0"
description = "Git integration for GShell"
author = "ghostkellz"

type = "ghostlang"  # or "native"
entry_point = "plugin.gza"

# Dependencies
requires_commands = ["git"]
requires_plugins = []

# Hooks (optional)
[hooks]
on_load = "init"
on_cd = "check_git_repo"
```

### Plugin Loader Implementation

#### Core API in `src/plugins.zig`
```zig
pub const PluginManager = struct {
    allocator: Allocator,
    script_engine: *ScriptEngine,
    loaded_plugins: StringHashMap(Plugin),
    plugin_dirs: []const []const u8,

    pub fn init(allocator: Allocator, script_engine: *ScriptEngine) !PluginManager;
    pub fn loadPlugin(self: *PluginManager, name: []const u8) !void;
    pub fn unloadPlugin(self: *PluginManager, name: []const u8) !void;
    pub fn reloadPlugin(self: *PluginManager, name: []const u8) !void;
    pub fn listPlugins(self: *PluginManager) []const Plugin;
};

pub const Plugin = struct {
    name: []const u8,
    version: []const u8,
    type: PluginType,
    manifest: Manifest,
    loaded: bool,

    pub const PluginType = enum {
        ghostlang,
        native,
    };
};

pub const Manifest = struct {
    name: []const u8,
    version: []const u8,
    description: []const u8,
    type: PluginType,
    entry_point: []const u8,
    requires_commands: []const []const u8,
    requires_plugins: []const []const u8,

    pub fn parse(allocator: Allocator, toml_content: []const u8) !Manifest;
};
```

### Configuration: `~/.config/gshell/ghostplug.toml`
```toml
# GhostPlug Configuration

[settings]
auto_update = true
lazy_load = true
plugin_dirs = [
    "~/.config/gshell/plugins",
    "/usr/share/gshell/plugins",
]

[plugins]
# Core plugins (always loaded)
core = ["git", "docker", "kubectl"]

# Optional plugins (loaded on demand)
optional = ["node", "python", "rust"]

# Disabled plugins
disabled = []

[plugin.git]
enabled = true
aliases = true  # Enable/disable aliases

[plugin.docker]
enabled = true
completion_cache = true
```

### Loading Sequence

1. **Shell Initialization** (`shell.zig`)
   ```zig
   // After ScriptEngine init
   plugin_manager = try PluginManager.init(allocator, &script_engine);
   try plugin_manager.loadConfig("~/.config/gshell/ghostplug.toml");
   try plugin_manager.loadCorePlugins();
   ```

2. **Plugin Discovery**
   - Read `ghostplug.toml` for enabled plugins
   - Search plugin directories
   - Parse `manifest.toml` for each plugin

3. **Dependency Resolution**
   - Check `requires_commands` (e.g., "git")
   - Check `requires_plugins` (e.g., depends on "completions")
   - Load in dependency order

4. **Plugin Loading**
   - For Ghostlang: Execute `plugin.gza` via ScriptEngine
   - For Native: Load shared library and call `plugin_init()`

5. **Hook Registration**
   - Register lifecycle hooks (on_cd, on_command, etc.)

## Built-in Plugins (Recommended)

### Tier 1: Core (Always Available)
- `git` - Git aliases and utilities
- `docker` - Docker aliases
- `kubectl` - Kubernetes management
- `completions` - Tab completion helpers

### Tier 2: Language/Tool Specific (Lazy Loaded)
- `node` - Node.js/npm utilities
- `python` - Python/pip utilities
- `rust` - Rust/cargo utilities
- `go` - Go utilities

### Tier 3: Community
- User-contributed plugins in separate repo

## Powerlevel10k vs Starship

### Decision: Use Starship (Already Integrated)

**Why NOT Powerlevel10k:**
- ❌ Project has limited support ("HELP REQUESTS WILL BE IGNORED")
- ❌ No new features in development
- ❌ Zsh-specific (we're a Zig shell)
- ❌ Complex internal implementation (83+ files)
- ❌ Requires Nerd Fonts
- ✅ We already have Starship working

**Why Starship:**
- ✅ Already integrated in GShell (prompt.zig)
- ✅ Cross-platform (works everywhere)
- ✅ Actively maintained
- ✅ Written in Rust (fast, native binary)
- ✅ TOML configuration (consistent with our approach)
- ✅ No shell-specific code needed
- ✅ Works via `use_starship(true)` in .gshrc

### Recommendation
**Ship with Starship enabled by default, no p10k integration needed.**

## Implementation Phases

### Phase 1: Plugin Infrastructure (Alpha→Beta)
- [ ] Create `src/plugins.zig`
- [ ] Implement PluginManager
- [ ] Add TOML parsing for manifest.toml
- [ ] Create plugin loading logic
- [ ] Test with single Ghostlang plugin

### Phase 2: Built-in Plugins (Beta)
- [ ] Create `git` plugin
- [ ] Create `docker` plugin
- [ ] Create `kubectl` plugin
- [ ] Document plugin API

### Phase 3: Advanced Features (v1.0)
- [ ] Native plugin support (.so loading)
- [ ] Plugin hooks system
- [ ] Auto-update mechanism
- [ ] Plugin repository/registry

## FFI Extensions Needed

Current FFI bridge has 11 functions. Need additions:

```zig
// Plugin-specific FFI
fn shellRegisterHook(hook_name: string, callback: function) -> boolean
fn shellGetPlugin(name: string) -> table | nil
fn shellListPlugins() -> table

// Command checking
fn commandExists(cmd: string) -> boolean

// Already have:
// - alias()
// - exec()
// - path_exists()
// - read_file()
// - write_file()
```

## Example: Full Git Plugin

**Directory: `~/.config/gshell/plugins/git/`**

**`manifest.toml`:**
```toml
name = "git"
version = "1.0.0"
description = "Git integration with aliases and helpers"
type = "ghostlang"
entry_point = "plugin.gza"
requires_commands = ["git"]
```

**`plugin.gza`:**
```lua
-- Git Plugin for GShell

-- Check dependencies
if not exec("which git > /dev/null 2>&1") then
    print("git plugin: git command not found")
    return false
end

-- Aliases
alias("gs", "git status")
alias("ga", "git add")
alias("gaa", "git add --all")
alias("gc", "git commit -v")
alias("gc!", "git commit -v --amend")
alias("gp", "git push")
alias("gpl", "git pull")
alias("gl", "git log --oneline --graph --decorate")
alias("gd", "git diff")
alias("gco", "git checkout")
alias("gb", "git branch")
alias("gba", "git branch -a")

-- Helper functions
function git_current_branch()
    -- Try .git/HEAD first (fast)
    if path_exists(".git/HEAD") then
        local head = read_file(".git/HEAD")
        if head then
            local branch = head:match("ref: refs/heads/(.+)")
            if branch then
                return branch:gsub("%s+$", "")  -- trim whitespace
            end
        end
    end

    -- Fallback to git command
    exec("git branch --show-current")
end

-- Export for use in prompts (future)
-- export("git_current_branch", git_current_branch)

print("✓ Git plugin loaded")
return true
```

## CLI Commands

```bash
# Plugin management
gshell plugin list                  # List all plugins
gshell plugin enable git            # Enable plugin
gshell plugin disable git           # Disable plugin
gshell plugin reload git            # Reload plugin
gshell plugin info git              # Show plugin details
gshell plugin search <query>        # Search plugin registry (future)
gshell plugin install <url>         # Install from URL (future)
```

## Migration from OhMyZsh

Users can port plugins easily:

**OhMyZsh plugin:**
```zsh
alias gs='git status'
alias ga='git add'
```

**GhostPlug equivalent:**
```lua
alias("gs", "git status")
alias("ga", "git add")
```

Nearly 1:1 mapping for simple plugins!

## Conclusion

GhostPlug provides:
- ✅ Familiar plugin model (like OhMyZsh)
- ✅ Ghostlang scripting (powerful, safe)
- ✅ Native performance option
- ✅ Simple manifest system
- ✅ Lazy loading
- ✅ Easy migration path
- ✅ Starship for prompts (no p10k needed)
