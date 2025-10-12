# Ghostlang Scripting Reference

**Lua-like scripting language for GShell configuration**

Ghostlang is GShell's embedded scripting language, designed for shell configuration and automation. It provides a familiar Lua-like syntax with deep integration into GShell's core functionality.

## Overview

Ghostlang scripts (`.gza` files) are used for:
- Shell configuration (`~/.gshrc.gza`)
- Plugin development (`assets/plugins/*/plugin.gza`)
- Prompt themes (`assets/prompts/*.gza`)
- Custom automation scripts

## Basic Syntax

Ghostlang syntax is similar to Lua:

```ghostlang
-- Comments start with --

-- Variables
local name = "GhostKellz"
local version = 1.0
local enabled = true

-- Functions
function greet(name)
    print("Hello, " .. name)
end

greet("World")

-- Conditionals
if enabled then
    print("Enabled!")
elseif version > 0.5 then
    print("Recent version")
else
    print("Old version")
end

-- Loops
for i = 1, 10 do
    print(i)
end

-- Tables
local colors = {"red", "green", "blue"}
for i, color in ipairs(colors) do
    print(i .. ": " .. color)
end

-- String concatenation
local greeting = "Hello" .. " " .. "World"
```

## Data Types

### Nil
```ghostlang
local x = nil
```

### Boolean
```ghostlang
local enabled = true
local disabled = false
```

### Number
```ghostlang
local integer = 42
local float = 3.14
```

### String
```ghostlang
local str = "Hello World"
local multiline = [[
This is a
multiline string
]]
```

### Table
```ghostlang
-- Array
local arr = {1, 2, 3}

-- Dictionary
local dict = {
    name = "GShell",
    version = "0.1.0"
}

-- Mixed
local mixed = {
    "item1",
    "item2",
    key = "value"
}
```

### Function
```ghostlang
function add(a, b)
    return a + b
end

local result = add(5, 3)
```

## GShell FFI API

Ghostlang scripts can call native GShell functions through the FFI (Foreign Function Interface). All FFI functions are defined in `src/scripting.zig`.

---

## Environment Functions

### `getenv(name)`
Gets an environment variable.

```ghostlang
local home = getenv("HOME")
local editor = getenv("EDITOR")
```

**Parameters:**
- `name` (string) - Variable name

**Returns:** `string` or `nil`

---

### `setenv(name, value)`
Sets an environment variable.

```ghostlang
setenv("EDITOR", "nvim")
setenv("PAGER", "less")
```

**Parameters:**
- `name` (string) - Variable name
- `value` (string) - Variable value

**Returns:** `boolean`

---

## File System Functions

### `path_exists(path)`
Checks if a path exists.

```ghostlang
if path_exists("/usr/bin/git") then
    print("Git is installed")
end
```

**Parameters:**
- `path` (string) - File or directory path

**Returns:** `boolean`

---

### `is_file(path)`
Checks if path is a file.

```ghostlang
if is_file("~/.gshrc.gza") then
    print("Config file exists")
end
```

**Parameters:**
- `path` (string) - Path to check

**Returns:** `boolean`

---

### `is_dir(path)`
Checks if path is a directory.

```ghostlang
if is_dir("~/projects") then
    print("Projects directory exists")
end
```

**Parameters:**
- `path` (string) - Path to check

**Returns:** `boolean`

---

### `read_file(path)`
Reads entire file contents.

```ghostlang
local contents = read_file("~/.gshrc.gza")
if contents then
    print("Config loaded: " .. #contents .. " bytes")
end
```

**Parameters:**
- `path` (string) - File path

**Returns:** `string` or `nil`

---

### `write_file(path, contents)`
Writes string to file.

```ghostlang
local config = "alias ls 'ls --color'\n"
write_file("~/.gshrc.gza", config)
```

**Parameters:**
- `path` (string) - File path
- `contents` (string) - Data to write

**Returns:** `boolean`

---

### `list_dirs(path)`
Lists directories in a path.

```ghostlang
local dirs = list_dirs("~/projects")
for i, dir in ipairs(dirs) do
    print(dir)
end
```

**Parameters:**
- `path` (string) - Directory path

**Returns:** `table` (array of strings)

---

### `list_files(path)`
Lists files in a path.

```ghostlang
local files = list_files("~/Documents")
for i, file in ipairs(files) do
    print(file)
end
```

**Parameters:**
- `path` (string) - Directory path

**Returns:** `table` (array of strings)

---

## Shell Functions

### `exec(command)`
Executes a shell command and returns output.

```ghostlang
local output = exec("git status")
print(output)

-- Command chaining
exec("git add . && git commit -m 'update'")
```

**Parameters:**
- `command` (string) - Command to execute

**Returns:** `string` (stdout + stderr)

---

### `cd(path)`
Changes current working directory.

```ghostlang
cd("~/projects")
cd("..")
```

**Parameters:**
- `path` (string) - Directory path

**Returns:** `boolean`

---

### `get_cwd()`
Gets current working directory.

```ghostlang
local cwd = get_cwd()
print("Current directory: " .. cwd)
```

**Returns:** `string`

---

### `get_user()`
Gets current username.

```ghostlang
local user = get_user()
print("Logged in as: " .. user)
```

**Returns:** `string`

---

### `get_hostname()`
Gets system hostname.

```ghostlang
local host = get_hostname()
print("Hostname: " .. host)
```

**Returns:** `string`

---

### `command_exists(name)`
Checks if a command is available in PATH.

```ghostlang
if command_exists("docker") then
    enable_plugin("docker")
end
```

**Parameters:**
- `name` (string) - Command name

**Returns:** `boolean`

---

## Alias Functions

### `alias(name, command)`
Creates a command alias.

```ghostlang
alias("ll", "ls -lah")
alias("gs", "git status")
alias("k", "kubectl")
```

**Parameters:**
- `name` (string) - Alias name
- `command` (string) - Command to run

**Returns:** `boolean`

---

### `unalias(name)`
Removes an alias.

```ghostlang
unalias("ll")
```

**Parameters:**
- `name` (string) - Alias name

**Returns:** `boolean`

---

## Git Functions

### `in_git_repo()`
Checks if current directory is in a git repository.

```ghostlang
if in_git_repo() then
    print("This is a git repo")
end
```

**Returns:** `boolean`

---

### `git_branch()`
Gets current git branch name.

```ghostlang
if in_git_repo() then
    local branch = git_branch()
    print("On branch: " .. branch)
end
```

**Returns:** `string` or `nil`

---

### `git_dirty()`
Checks if git working directory has uncommitted changes.

```ghostlang
if git_dirty() then
    print("You have uncommitted changes")
end
```

**Returns:** `boolean`

---

### `git_ahead_behind()`
Gets commits ahead/behind remote.

```ghostlang
local ahead, behind = git_ahead_behind()
if ahead > 0 then
    print("Ahead by " .. ahead .. " commits")
end
if behind > 0 then
    print("Behind by " .. behind .. " commits")
end
```

**Returns:** `number, number` (ahead, behind)

---

## Prompt Functions

### `gprompt_enable()`
Enables GPPrompt (PowerLevel10k-style).

```ghostlang
gprompt_enable()
```

**Returns:** `boolean`

---

### `gprompt_disable()`
Disables GPPrompt.

```ghostlang
gprompt_disable()
```

**Returns:** `boolean`

---

### `gprompt_is_enabled()`
Checks if GPPrompt is active.

```ghostlang
if gprompt_is_enabled() then
    print("Using GPPrompt")
end
```

**Returns:** `boolean`

---

### `enable_git_prompt()`
Enables simple git prompt segment.

```ghostlang
gprompt_disable()
enable_git_prompt()
```

**Returns:** `boolean`

---

### `use_starship(enabled)`
Enables/disables Starship prompt integration.

```ghostlang
if command_exists("starship") then
    gprompt_disable()
    use_starship(true)
end
```

**Parameters:**
- `enabled` (boolean) - Enable or disable

**Returns:** `boolean`

---

## Icon Functions

### `icon_get(name)`
Gets a Nerd Font icon by name.

```ghostlang
local rust = icon_get("RUST_ICON")
local python = icon_get("PYTHON_ICON")
local go = icon_get("GO_ICON")
```

**Parameters:**
- `name` (string) - Icon identifier from zfont PowerLevel10k library

**Returns:** `string` (UTF-8 icon) or `nil`

**Available Icons:**
- Languages: `RUST_ICON`, `PYTHON_ICON`, `GO_ICON`, `NODEJS_ICON`, `RUBY_ICON`, `JAVA_ICON`, `CPP_ICON`, `CSHARP_ICON`, etc.
- OS: `LINUX_ARCH_ICON`, `LINUX_UBUNTU_ICON`, `APPLE_ICON`, `WINDOWS_ICON`
- Tools: `DOCKER_ICON`, `KUBERNETES_ICON`, `GIT_ICON`, `VIM_ICON`
- Files: `FOLDER_ICON`, `HOME_ICON`, `FILE_ICON`

See [zfont PowerLevel10k library](https://github.com/GhostKellz/zfont/blob/main/src/powerlevel10k.zig) for full list.

---

### `icon_arch()`
Arch Linux logo.

```ghostlang
local arch = icon_arch()
print(arch .. " Arch Linux")
```

**Returns:** `string`

---

### `icon_nodejs()`
Node.js logo.

```ghostlang
local node = icon_nodejs()
print(node .. " Node.js")
```

**Returns:** `string`

---

### `icon_git_branch()`
Git branch icon.

```ghostlang
local git = icon_git_branch()
local branch = git_branch()
print(git .. " " .. branch)
```

**Returns:** `string`

---

### `icon_folder()`
Folder icon.

```ghostlang
local folder = icon_folder()
print(folder .. " " .. get_cwd())
```

**Returns:** `string`

---

### `icon_home()`
Home directory icon.

```ghostlang
local home = icon_home()
print(home .. " " .. getenv("HOME"))
```

**Returns:** `string`

---

## Plugin Functions

### `enable_plugin(name, path?)`
Loads a plugin.

```ghostlang
enable_plugin("git")
enable_plugin("myplugin", "~/.config/gshell/plugins/myplugin")
```

**Parameters:**
- `name` (string) - Plugin name
- `path` (string, optional) - Custom plugin path

**Returns:** `boolean`

---

### `disable_plugin(name)`
Unloads a plugin.

```ghostlang
disable_plugin("git")
```

**Parameters:**
- `name` (string) - Plugin name

**Returns:** `boolean`

---

### `plugin_loaded(name)`
Checks if plugin is loaded.

```ghostlang
if plugin_loaded("git") then
    print("Git plugin active")
end
```

**Parameters:**
- `name` (string) - Plugin name

**Returns:** `boolean`

---

## History Functions

### `set_history_size(size)`
Sets maximum history entries.

```ghostlang
set_history_size(10000)
```

**Parameters:**
- `size` (number) - Max entries

**Returns:** `boolean`

---

### `set_history_file(path)`
Sets history file path.

```ghostlang
set_history_file(getenv("HOME") .. "/.gshell_history")
```

**Parameters:**
- `path` (string) - File path

**Returns:** `boolean`

---

## Theme Functions

### `load_vivid_theme(name)`
Loads a vivid color theme for LS_COLORS.

```ghostlang
if command_exists("vivid") then
    load_vivid_theme("ghost-hacker-blue")
end
```

**Parameters:**
- `name` (string) - Theme name from `assets/vivid/`

**Available Themes:**
- `ghost-hacker-blue`
- `tokyonight-night`
- `tokyonight-moon`
- `dracula`

**Returns:** `boolean`

---

## Output Functions

### `print(message)`
Prints to stdout.

```ghostlang
print("Hello World")
print("Value: " .. tostring(42))
```

**Parameters:**
- `message` (string) - Message to print

**Returns:** `nil`

---

### `error(message)`
Prints error to stderr.

```ghostlang
if not path_exists("/required/file") then
    error("Required file missing")
end
```

**Parameters:**
- `message` (string) - Error message

**Returns:** `nil`

---

## String Functions

### `string:match(pattern)`
Pattern matching (Lua-style).

```ghostlang
local file = "test.tar.gz"
if file:match("%.tar%.gz$") then
    print("Tarball detected")
end
```

---

### `string:gsub(pattern, replacement)`
String substitution.

```ghostlang
local text = "Hello World"
local new = text:gsub("World", "GShell")
-- new = "Hello GShell"
```

---

### `string:sub(start, end?)`
Substring extraction.

```ghostlang
local str = "Hello World"
local sub = str:sub(1, 5)  -- "Hello"
```

---

### `string:upper()` / `string:lower()`
Case conversion.

```ghostlang
local str = "Hello"
print(str:upper())  -- "HELLO"
print(str:lower())  -- "hello"
```

---

### `string:len()` / `#string`
String length.

```ghostlang
local str = "Hello"
print(str:len())  -- 5
print(#str)       -- 5
```

---

## Table Functions

### `table.insert(table, value)`
Appends to array.

```ghostlang
local arr = {1, 2, 3}
table.insert(arr, 4)
-- arr = {1, 2, 3, 4}
```

---

### `table.concat(table, separator?)`
Joins array elements.

```ghostlang
local arr = {"a", "b", "c"}
local str = table.concat(arr, ", ")
-- str = "a, b, c"
```

---

### `ipairs(table)`
Iterate array.

```ghostlang
local colors = {"red", "green", "blue"}
for i, color in ipairs(colors) do
    print(i .. ": " .. color)
end
```

---

### `pairs(table)`
Iterate dictionary.

```ghostlang
local config = {
    editor = "nvim",
    theme = "dark"
}
for key, value in pairs(config) do
    print(key .. " = " .. value)
end
```

---

## Type Functions

### `type(value)`
Gets value type.

```ghostlang
print(type(42))        -- "number"
print(type("text"))    -- "string"
print(type(true))      -- "boolean"
print(type(nil))       -- "nil"
print(type({}))        -- "table"
print(type(print))     -- "function"
```

---

### `tostring(value)`
Converts to string.

```ghostlang
local num = 42
print("Value: " .. tostring(num))
```

---

### `tonumber(value)`
Converts to number.

```ghostlang
local str = "123"
local num = tonumber(str)
-- num = 123
```

---

## Advanced Examples

### Custom Prompt with Icons

```ghostlang
-- Custom prompt function
function my_prompt()
    local user = get_user()
    local host = get_hostname()
    local cwd = get_cwd()
    local home = getenv("HOME")

    -- Replace home with ~
    if cwd:sub(1, #home) == home then
        cwd = "~" .. cwd:sub(#home + 1)
    end

    local prompt = icon_home() .. " " .. user .. "@" .. host .. " " .. cwd

    -- Add git info if in repo
    if in_git_repo() then
        local branch = git_branch()
        local dirty_marker = git_dirty() and "*" or ""
        prompt = prompt .. " " .. icon_git_branch() .. " " .. branch .. dirty_marker
    end

    prompt = prompt .. " ❯ "
    return prompt
end
```

### Plugin with Dependency Checking

```ghostlang
-- my-plugin/plugin.gza

local required_commands = {"docker", "docker-compose"}
local missing = {}

for i, cmd in ipairs(required_commands) do
    if not command_exists(cmd) then
        table.insert(missing, cmd)
    end
end

if #missing > 0 then
    error("Missing commands: " .. table.concat(missing, ", "))
    return false
end

-- Plugin logic here
alias("d", "docker")
alias("dc", "docker-compose")

print("✓ my-plugin loaded")
return true
```

### Conditional Configuration

```ghostlang
-- ~/.gshrc.gza

-- Detect OS
local os_name = exec("uname")

if os_name:match("Linux") then
    setenv("PAGER", "less")
    alias("update", "sudo pacman -Syu")

    if command_exists("vivid") then
        load_vivid_theme("ghost-hacker-blue")
    end
elseif os_name:match("Darwin") then
    setenv("PAGER", "less -R")
    alias("update", "brew update && brew upgrade")
end

-- Enable plugins based on availability
if command_exists("docker") then
    enable_plugin("docker")
end

if command_exists("kubectl") then
    enable_plugin("kubectl")
end

-- Choose prompt
if command_exists("starship") then
    use_starship(true)
else
    gprompt_enable()
end
```

### Dynamic Alias Generation

```ghostlang
-- Create numbered git aliases
local git_commands = {
    "status",
    "diff",
    "log",
    "add",
    "commit",
    "push",
    "pull"
}

for i, cmd in ipairs(git_commands) do
    alias("g" .. i, "git " .. cmd)
end

-- Now you have: g1=status, g2=diff, g3=log, etc.
```

## Best Practices

### 1. Check Before Use

Always check requirements:

```ghostlang
if not command_exists("git") then
    print("⚠️  Git not found")
    return false
end
```

### 2. Use Local Variables

Avoid polluting global namespace:

```ghostlang
-- Good
local my_var = "value"

-- Bad
my_var = "value"
```

### 3. Return Status

Functions should return success/failure:

```ghostlang
function my_function()
    if success then
        return true
    else
        return false
    end
end
```

### 4. Error Handling

Handle errors gracefully:

```ghostlang
local file = read_file("~/.config")
if not file then
    error("Failed to read config")
    return false
end
```

### 5. Comments

Document your code:

```ghostlang
-- Quick git commit and push
-- Usage: gcp("commit message")
function gcp(message)
    -- ...
end
```

## Debugging

### Enable Debug Mode

```bash
export GSHELL_DEBUG=1
gshell
```

### Print Debugging

```ghostlang
print("DEBUG: variable = " .. tostring(variable))
```

### Check FFI Availability

```ghostlang
if gprompt_enable then
    print("gprompt_enable available")
else
    print("gprompt_enable NOT available")
end
```

## Limitations

1. **No Coroutines** - Ghostlang doesn't support Lua coroutines
2. **No Metatables** - No metatable customization (yet)
3. **Limited Standard Library** - Focused on shell-related functions
4. **No File I/O Module** - Use `read_file()` and `write_file()` FFI
5. **No Network Module** - Use `exec()` to call external tools

## See Also

- [GPPrompt API Reference](../gprompt/README.md)
- [GhostPlug Plugin System](../ghostplug/README.md)
- [Configuration Examples](../../examples/)
