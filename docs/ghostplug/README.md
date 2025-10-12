# GhostPlug

**3rd Party Plugin System for GShell**

GhostPlug is GShell's plugin architecture that allows you to extend your shell with reusable, shareable modules written in Ghostlang. It replaces the need for Oh-My-Zsh, Prezto, or manual plugin management.

## Philosophy

> **One Binary, Infinite Extensions**

Why manage dozens of shell scripts when you can have a unified plugin system? GhostPlug provides a standard way to package, distribute, and load shell extensions—all written in Ghostlang (.gza).

## Features

- **Zero-dependency plugins** - Pure Ghostlang, no external tools required
- **Manifest-based** - TOML manifests for version, dependencies, requirements
- **Built-in plugins** - Git, Docker, Network, Dev Tools, Kubectl, System
- **Third-party plugins** - Install from Git repos or local directories
- **Automatic dependency checking** - Plugins declare required commands
- **Lazy loading** - Load plugins on-demand for faster startup
- **Hot reloading** - Reload plugins without restarting shell

## Quick Start

Enable a built-in plugin in your `~/.gshrc.gza`:

```ghostlang
-- Enable git plugin (aliases, helpers)
enable_plugin("git")

-- Enable multiple plugins
enable_plugin("docker")
enable_plugin("network")
enable_plugin("dev-tools")
```

## Built-in Plugins

GhostPlug ships with 6 built-in plugins located in `assets/plugins/`:

### 1. Git Plugin
**Aliases and helpers for Git workflows**

```ghostlang
enable_plugin("git")
```

**Provides:**
- **80+ aliases**: `gs`, `gst`, `ga`, `gc`, `gps`, `gpl`, `gco`, `gb`, `glog`, etc.
- **Helper functions**: `gcp("message")`, `gundo()`, `gfix()`
- **Utilities**: `git_current_branch()`, `git_root()`, `git_is_dirty()`

**Examples:**
```ghostlang
gst              # git status -sb
gaa              # git add .
gcm "fix bug"    # git commit -m "fix bug"
gps              # git push
gcp "hotfix"     # git add . && commit && push (all in one)
gundo            # undo last commit (keep changes)
```

Full list: [assets/plugins/git/plugin.gza](../../assets/plugins/git/plugin.gza)

---

### 2. Docker Plugin
**Docker and docker-compose shortcuts**

```ghostlang
enable_plugin("docker")
```

**Provides:**
- **Container management**: `dps`, `dstart`, `dstop`, `drm`, `dexec`, `dlogs`
- **Image management**: `di`, `drmi`, `dpull`, `dbuild`
- **Docker Compose**: `dcu`, `dcd`, `dcr`, `dcl`
- **Cleanup helpers**: `dprune`, `dclean`

**Examples:**
```ghostlang
dps              # docker ps
dexec myapp bash # docker exec -it myapp bash
dcu              # docker-compose up -d
dclean           # Remove all stopped containers
```

---

### 3. Network Plugin
**Network utilities and diagnostics**

```ghostlang
enable_plugin("network")
```

**Provides:**
- **Port scanning**: `port_scan(host, port)`, `net_scan(subnet)`
- **Connection testing**: `is_port_open(host, port)`, `ping_host(host)`
- **DNS lookup**: `dns_lookup(domain)`, `reverse_dns(ip)`
- **IP info**: `my_ip()`, `local_ip()`, `public_ip()`
- **Speed test**: `speedtest()`

**Examples:**
```ghostlang
my_ip()                  # Show public IP
port_scan("localhost", 8080)  # Check if port is open
net_scan("192.168.1.0/24")   # Scan local network
```

---

### 4. Kubectl Plugin
**Kubernetes helpers**

```ghostlang
enable_plugin("kubectl")
```

**Provides:**
- **kubectl aliases**: `k`, `kg`, `kd`, `ka`, `kdel`
- **Context switching**: `kx`, `kn`
- **Pod management**: `kpods`, `klog`, `kexec`
- **Resource helpers**: `kdesc`, `kedit`, `kscale`

**Examples:**
```ghostlang
k get pods           # kubectl get pods
klog mypod           # kubectl logs -f mypod
kx production        # Switch to production context
```

---

### 5. Dev Tools Plugin
**Development tool version managers**

```ghostlang
enable_plugin("dev-tools")
```

**Provides:**
- **Node.js detection**: `node_version()`, `npm_version()`
- **Rust detection**: `rust_version()`, `cargo_version()`
- **Go detection**: `go_version()`
- **Python detection**: `python_version()`, `pip_version()`
- **Version display**: Auto-detect and show in prompt segments

**Examples:**
```ghostlang
node_version()       # "v20.10.0"
rust_version()       # "1.75.0"
```

---

### 6. System Plugin
**System information and monitoring**

```ghostlang
enable_plugin("system")
```

**Provides:**
- **System info**: `sysinfo()`, `cpu_info()`, `mem_info()`, `disk_info()`
- **Process management**: `ps_grep(name)`, `kill_by_name(name)`
- **File helpers**: `disk_usage(path)`, `find_largest_files(dir)`
- **Monitoring**: `watch_process(name)`, `system_load()`

**Examples:**
```ghostlang
sysinfo()            # Display system overview
cpu_info()           # CPU model, cores, usage
disk_usage("/")      # Show disk space for /
```

---

## Plugin Structure

Every GhostPlug plugin consists of two files:

```
my-plugin/
├── manifest.toml    # Plugin metadata
└── plugin.gza       # Ghostlang implementation
```

### manifest.toml

Defines plugin metadata, requirements, and configuration:

```toml
[plugin]
name = "my-plugin"
version = "1.0.0"
description = "Short description of what the plugin does"
author = "Your Name"
license = "MIT"

[requirements]
# Commands that must exist for plugin to load
commands = ["git", "fzf"]

# Minimum GShell version
gshell_version = "0.1.0"

[config]
# Plugin-specific settings (accessible via plugin_config())
enable_feature_x = true
theme_color = "blue"
```

### plugin.gza

Ghostlang script implementing the plugin:

```ghostlang
-- my-plugin/plugin.gza

-- Check requirements
if not command_exists("git") then
    print("⚠️  my-plugin requires git")
    return false
end

-- Define aliases
alias("mp", "my-plugin-command")

-- Define functions
function my_helper()
    print("Hello from my-plugin!")
end

-- Plugin loaded successfully
print("✓ my-plugin loaded")
return true
```

## Creating a Plugin

### 1. Basic Plugin Template

Create a new plugin directory:

```bash
mkdir -p ~/.config/gshell/plugins/myplugin
cd ~/.config/gshell/plugins/myplugin
```

Create `manifest.toml`:

```toml
[plugin]
name = "myplugin"
version = "1.0.0"
description = "My custom plugin"
author = "Your Name"
license = "MIT"

[requirements]
commands = []

[config]
```

Create `plugin.gza`:

```ghostlang
-- My custom plugin

-- Add your aliases
alias("mp", "echo 'My Plugin'")

-- Add your functions
function my_function()
    print("Hello from MyPlugin!")
end

print("✓ myplugin loaded")
return true
```

### 2. Load Your Plugin

In `~/.gshrc.gza`:

```ghostlang
-- Load from custom plugin directory
enable_plugin("myplugin", "~/.config/gshell/plugins/myplugin")

-- Or if installed to built-in location
enable_plugin("myplugin")
```

### 3. Advanced Example: FZF Integration

Create `fzf-helpers/plugin.gza`:

```ghostlang
-- FZF Helpers Plugin
-- Fuzzy finding utilities

if not command_exists("fzf") then
    print("⚠️  fzf plugin requires fzf to be installed")
    return false
end

-- Fuzzy file search and open in editor
function fe()
    local file = exec("fzf --preview 'bat --color=always {}'")
    if file and #file > 0 then
        local editor = getenv("EDITOR") or "vim"
        exec(editor .. " " .. file)
    end
end

-- Fuzzy cd
function fcd()
    local dir = exec("find . -type d | fzf")
    if dir and #dir > 0 then
        cd(dir)
    end
end

-- Fuzzy git branch checkout
function fco()
    if not in_git_repo() then
        print("Not in a git repository")
        return
    end
    local branch = exec("git branch --all | sed 's/^[* ]*//' | fzf")
    if branch and #branch > 0 then
        exec("git checkout " .. branch)
    end
end

-- Fuzzy process kill
function fkill()
    local pid = exec("ps aux | fzf --header-lines=1 | awk '{print $2}'")
    if pid and #pid > 0 then
        exec("kill " .. pid)
    end
end

alias("f", "fzf")
alias("ff", "fe")

print("✓ fzf-helpers loaded")
return true
```

Create `fzf-helpers/manifest.toml`:

```toml
[plugin]
name = "fzf-helpers"
version = "1.0.0"
description = "Fuzzy finding utilities using fzf"
author = "GhostKellz"
license = "MIT"

[requirements]
commands = ["fzf"]

[config]
use_preview = true
```

Enable it:

```ghostlang
enable_plugin("fzf-helpers", "~/.config/gshell/plugins/fzf-helpers")
```

## API Reference

### Core Functions

#### `enable_plugin(name, path?)`
Loads a plugin by name. Searches built-in plugins first, then custom paths.

```ghostlang
-- Load built-in plugin
enable_plugin("git")

-- Load from custom path
enable_plugin("myplugin", "~/.config/gshell/plugins/myplugin")

-- Load from Git repo (planned)
enable_plugin("myplugin", "https://github.com/user/myplugin")
```

**Parameters:**
- `name` (string) - Plugin name
- `path` (string, optional) - Custom plugin directory

**Returns:** `boolean` - `true` if loaded, `false` on error

---

#### `disable_plugin(name)`
Unloads a plugin (removes aliases, functions).

```ghostlang
disable_plugin("git")
```

**Parameters:**
- `name` (string) - Plugin name

**Returns:** `boolean` - `true` if unloaded, `false` if not found

---

#### `plugin_loaded(name)`
Checks if a plugin is currently loaded.

```ghostlang
if plugin_loaded("git") then
    print("Git plugin is active")
end
```

**Parameters:**
- `name` (string) - Plugin name

**Returns:** `boolean` - `true` if loaded, `false` otherwise

---

#### `list_plugins()`
Lists all available plugins (built-in and custom).

```ghostlang
local plugins = list_plugins()
for i, plugin in ipairs(plugins) do
    print(plugin.name .. " - " .. plugin.description)
end
```

**Returns:** `table` - Array of plugin metadata

---

#### `reload_plugin(name)`
Reloads a plugin without restarting the shell.

```ghostlang
reload_plugin("git")
```

**Parameters:**
- `name` (string) - Plugin name

**Returns:** `boolean` - `true` if reloaded, `false` on error

---

### Plugin Helpers

#### `plugin_config(key, default?)`
Retrieves configuration value from plugin's manifest.toml.

```ghostlang
-- In your plugin.gza
local theme = plugin_config("theme_color", "blue")
local enabled = plugin_config("enable_feature_x", true)
```

**Parameters:**
- `key` (string) - Config key from [config] section
- `default` (any, optional) - Default value if not found

**Returns:** Value from manifest.toml or default

---

#### `plugin_path(name)`
Returns the filesystem path to a plugin's directory.

```ghostlang
local path = plugin_path("git")
-- "/usr/share/gshell/plugins/git"
```

**Parameters:**
- `name` (string) - Plugin name

**Returns:** `string` - Absolute path to plugin directory

---

## Installing 3rd Party Plugins

### From Git Repository

```bash
# Clone to custom plugin directory
git clone https://github.com/user/awesome-plugin ~/.config/gshell/plugins/awesome-plugin

# Enable in ~/.gshrc.gza
enable_plugin("awesome-plugin", "~/.config/gshell/plugins/awesome-plugin")
```

### From Local Directory

```bash
# Copy plugin to custom location
cp -r /path/to/my-plugin ~/.config/gshell/plugins/my-plugin

# Enable in ~/.gshrc.gza
enable_plugin("my-plugin", "~/.config/gshell/plugins/my-plugin")
```

### Future: Package Manager (Planned)

```bash
# Install from GhostPlug registry (coming soon)
gsh plugin install fzf-helpers

# Search for plugins
gsh plugin search docker

# Update plugins
gsh plugin update --all
```

## Best Practices

### 1. Check Requirements

Always check for required commands:

```ghostlang
if not command_exists("docker") then
    print("⚠️  docker plugin requires docker")
    return false
end
```

### 2. Use Descriptive Names

Choose clear, specific plugin names:
- ✅ `git-workflow`, `docker-dev`, `kubernetes-tools`
- ❌ `utils`, `helpers`, `stuff`

### 3. Return Status

Always return `true` on success, `false` on failure:

```ghostlang
-- Success
print("✓ plugin loaded")
return true

-- Failure
print("❌ Failed to load plugin")
return false
```

### 4. Namespace Functions

Prefix functions with plugin name to avoid conflicts:

```ghostlang
-- Good
function myplugin_helper()
    -- ...
end

-- Better: use _ prefix for internal functions
function _myplugin_internal()
    -- ...
end

function myplugin_public_api()
    _myplugin_internal()
end
```

### 5. Document Aliases

Add comments explaining aliases:

```ghostlang
-- Git status with short format
alias("gst", "git status -sb")

-- Git log with graph
alias("glog", "git log --graph --oneline")
```

### 6. Lazy Load Heavy Plugins

For plugins with expensive initialization, use lazy loading:

```ghostlang
-- Defer loading until first use
function myplugin_expensive_function()
    if not _myplugin_initialized then
        _myplugin_init()
        _myplugin_initialized = true
    end
    -- do work
end
```

## Debugging Plugins

### Enable Debug Output

```ghostlang
-- In ~/.gshrc.gza
setenv("GSHELL_DEBUG", "1")

enable_plugin("myplugin")
```

### Check Plugin Status

```ghostlang
if not plugin_loaded("myplugin") then
    print("Plugin failed to load")
else
    print("Plugin active")
end
```

### Reload After Changes

```ghostlang
# Edit plugin
vim ~/.config/gshell/plugins/myplugin/plugin.gza

# Reload in shell
reload_plugin("myplugin")
```

## Examples

### Example 1: Project Switcher Plugin

```ghostlang
-- project-switcher/plugin.gza

local projects_dir = getenv("HOME") .. "/projects"

function proj()
    if not path_exists(projects_dir) then
        error("Projects directory not found: " .. projects_dir)
        return
    end

    local dirs = list_dirs(projects_dir)
    for i, dir in ipairs(dirs) do
        print(i .. ". " .. dir)
    end

    print("\\nEnter project number: ")
    local choice = tonumber(read_line())

    if choice and dirs[choice] then
        cd(projects_dir .. "/" .. dirs[choice])
        print("📂 Switched to: " .. dirs[choice])
    else
        print("Invalid choice")
    end
end

alias("p", "proj")

print("✓ project-switcher loaded")
return true
```

### Example 2: Tmux Session Manager

```ghostlang
-- tmux-manager/plugin.gza

if not command_exists("tmux") then
    print("⚠️  tmux-manager requires tmux")
    return false
end

-- Start or attach to tmux session
function tm(session_name)
    if not session_name then
        -- List sessions
        exec("tmux list-sessions")
        return
    end

    -- Check if session exists
    local sessions = exec("tmux list-sessions -F '#{session_name}' 2>/dev/null")
    if sessions:match(session_name) then
        exec("tmux attach -t " .. session_name)
    else
        exec("tmux new -s " .. session_name)
    end
end

-- Kill tmux session
function tk(session_name)
    if not session_name then
        print("Usage: tk <session_name>")
        return
    end
    exec("tmux kill-session -t " .. session_name)
end

alias("tls", "tmux list-sessions")

print("✓ tmux-manager loaded")
return true
```

## Comparison

| Feature                | GhostPlug       | Oh-My-Zsh    | Prezto        |
|------------------------|-----------------|--------------|---------------|
| Language               | Ghostlang       | ZSH          | ZSH           |
| Plugin count (built-in)| 6               | 200+         | 100+          |
| 3rd party support      | ✅ Git/Local    | ✅ Git       | ✅ Git        |
| Manifest system        | ✅ TOML         | ❌           | ❌            |
| Dependency checking    | ✅ Auto         | ⚠️ Manual    | ⚠️ Manual     |
| Hot reloading          | ✅              | ❌           | ❌            |
| Package manager        | 🚧 Planned      | ❌           | ❌            |

## Roadmap

- [ ] **GhostPlug registry** - Central repository of community plugins
- [ ] **`gsh plugin` CLI** - Install, update, search plugins from registry
- [ ] **Plugin sandboxing** - Isolate plugins from core shell
- [ ] **Performance profiling** - Track plugin load time and impact
- [ ] **Auto-update** - Keep plugins up-to-date automatically
- [ ] **Plugin dependencies** - Plugins can depend on other plugins
- [ ] **Plugin hooks** - React to shell events (cd, prompt render, etc.)

## Contributing

To contribute a plugin to GhostPlug's built-in collection:

1. Create plugin in `assets/plugins/your-plugin/`
2. Add `manifest.toml` and `plugin.gza`
3. Document in `docs/ghostplug/plugins/your-plugin.md`
4. Submit PR to GShell repository

## See Also

- [GPPrompt Prompt System](../gprompt/README.md)
- [Ghostlang Scripting Reference](../integration/ghostlang.md)
- [Plugin Development Guide](./development.md)
- [Built-in Plugins Reference](./plugins/)
