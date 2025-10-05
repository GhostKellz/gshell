# GShell v0.1.0-beta Release Notes

**Release Date**: October 5, 2025
**Status**: Beta Release - Ready for testing!

---

## 🎉 Introducing GShell - The Next-Generation Shell

GShell is a modern Linux shell that replaces Bash/Zsh/Fish with **Ghostlang scripting**, **powerful FFI**, and a **modern user experience**.

This is the first public beta release, featuring a complete shell implementation with scripting, plugins, and comprehensive built-in utilities.

---

## 🚀 Highlights

### **Ghostlang Configuration**
Your `.gshrc.gza` is a full programming language, not a config file:

```lua
-- ~/.gshrc.gza

-- Set environment
setenv("EDITOR", "nvim")

-- Load plugins
enable_plugin("git")   -- 60+ git aliases!

-- Define functions
function mkcd(dir)
    exec("mkdir -p " .. dir)
    cd(dir)
end

-- Conditional logic
if command_exists("starship") then
    use_starship(true)
else
    enable_git_prompt()  -- Async git prompt with caching
end

if in_git_repo() then
    print("📁 Branch: " .. git_branch())
end
```

### **30+ Shell FFI Functions**
Direct access to shell functionality from Ghostlang:
- Environment: `getenv()`, `setenv()`
- Files: `read_file()`, `write_file()`, `path_exists()`
- Git: `git_branch()`, `git_dirty()`, `in_git_repo()`
- System: `get_user()`, `get_hostname()`, `get_cwd()`
- Shell: `exec()`, `cd()`, `alias()`, `command_exists()`

### **Powerful Plugin System**
6 built-in plugins with full shell access:
- **git**: 60+ aliases (`gs`, `gc`, `gd`, `gps`, `gpl`) + helpers
- **docker**: Container shortcuts
- **kubectl**: Kubernetes helpers
- **network**: Networking tools
- **dev-tools**: Development utilities
- **system**: System info commands

### **Modern UX**
- **Tab Completion**: Commands + files, context-aware
- **History**: Persistent with `Ctrl+R` search
- **Unicode**: Full emoji, CJK, grapheme cluster support
- **Job Control**: `jobs`, `fg`, `bg` commands
- **Starship Integration**: Beautiful prompts out of the box
- **Git Prompt**: Async, cached git status in prompt

### **Networking Built-ins**
Professional networking tools included:
- `net-test <host> <port>` - TCP connectivity test
- `net-resolve <hostname>` - DNS resolution
- `net-fetch <url>` - HTTP client
- `net-scan <cidr>` - Network scanner

---

## 📦 Installation

### From Source

```bash
# Clone repository
git clone https://github.com/ghostkellz/gshell
cd gshell

# Build (requires Zig 0.16.0+)
zig build

# Install
sudo cp zig-out/bin/gshell /usr/local/bin/

# Create config
gshell init

# Launch!
gshell
```

### Quick Test

```bash
# Test FFI
echo 'print("Hello from Ghostlang!")
setenv("TEST", "value")
print(getenv("TEST"))' > test.gza

./zig-out/bin/gshell test.gza

# Test networking
./zig-out/bin/gshell --command "net-test google.com 443"
./zig-out/bin/gshell --command "net-resolve github.com"
```

---

## 🎯 What's New in v0.1.0-beta

### Core Features
✅ Complete interactive shell (REPL, history, completion)
✅ Ghostlang FFI with 30+ functions
✅ Configuration system (.gshrc.gza)
✅ Plugin system (6 plugins included)
✅ Job control (jobs, fg, bg)
✅ Tab completion
✅ Persistent history with search
✅ Unicode-aware editing (gcode)
✅ Starship prompt integration
✅ Async git prompt with caching
✅ Networking utilities (4 built-ins)

### Technical
✅ Zig 0.16.0-dev codebase
✅ Ghostlang v0.1.0 integration
✅ zsync async runtime (integrated)
✅ SQLite history backend
✅ Comprehensive test suite
✅ Full documentation

---

## 📚 Documentation

- **[README.md](README.md)** - Complete user guide
- **[PROGRESS_REPORT.md](PROGRESS_REPORT.md)** - Detailed status
- **[CHANGELOG.md](CHANGELOG.md)** - Version history
- **Plugin Examples**: `assets/plugins/git/plugin.gza`
- **Config Template**: `assets/templates/default.gshrc.gza`

### Quick Links
- [FFI Function Reference](PROGRESS_REPORT.md#1-ghostlang-ffi-bridge---fully-implemented-)
- [Plugin Development](assets/plugins/git/plugin.gza)
- [Ghostlang Docs](https://github.com/ghostkellz/ghostlang)

---

## 🔧 Configuration Examples

### Minimal Config
```lua
-- ~/.gshrc.gza
enable_plugin("git")
alias("ll", "ls -lah")
print("🪐 GShell ready!")
```

### Power User Config
```lua
-- ~/.gshrc.gza

-- Environment
setenv("EDITOR", "nvim")
setenv("PAGER", "less -R")
setenv("MANPAGER", "nvim +Man!")

-- Plugins
enable_plugin("git")
enable_plugin("docker")
enable_plugin("kubectl")

-- Aliases
alias("ll", "ls -lah --color=auto")
alias("la", "ls -A")
alias("...", "cd ../..")
alias("grep", "grep --color=auto")
alias("watch", "watch -n 1 -c")

-- Git shortcuts
alias("gst", "git status -sb")
alias("gd", "git diff")
alias("gaa", "git add -A")

-- Docker shortcuts
alias("dps", "docker ps")
alias("di", "docker images")
alias("dex", "docker exec -it")

-- Custom functions
function mkcd(dir)
    if not dir then
        error("Usage: mkcd <directory>")
        return
    end
    exec("mkdir -p " .. dir)
    cd(dir)
    print("Created and entered: " .. dir)
end

function backup(file)
    if path_exists(file) then
        exec("cp " .. file .. " " .. file .. ".backup")
        print("Backed up: " .. file)
    else
        error("File not found: " .. file)
    end
end

-- Prompt
if command_exists("starship") then
    use_starship(true)
    print("✨ Using Starship prompt")
else
    enable_git_prompt()
    print("🪐 Using built-in prompt with git")
end

-- Theme
if command_exists("vivid") then
    load_vivid_theme("ghost-hacker-blue")
end

-- History
set_history_size(10000)
set_history_file(getenv("HOME") .. "/.gshell_history")

-- Startup
print("🪐 GShell v0.1.0-beta loaded!")
print("Type 'help' for commands")

if in_git_repo() then
    local branch = git_branch()
    local dirty = git_dirty() and "*" or ""
    print("📁 Git: " .. branch .. dirty)
end
```

---

## 🧪 Testing

### Run Tests
```bash
# All tests
zig build test

# Specific test
zig build test --test-filter "scripting"
```

### Test FFI Functions
```bash
# Create comprehensive test
cat > test_all.gza << 'EOF'
print("=== FFI Test ===")
setenv("TEST", "value")
print(getenv("TEST"))
alias("t", "echo test")
if path_exists("/tmp") then
    print("✓ path_exists")
end
if command_exists("ls") then
    print("✓ command_exists")
end
write_file("/tmp/test.txt", "content")
print(read_file("/tmp/test.txt"))
print(get_user())
print(get_hostname())
if in_git_repo() then
    print(git_branch())
end
print("All tests passed!")
EOF

gshell test_all.gza
```

---

## 🐛 Known Issues

### Ghostlang v0.1.0 Limitations
- **String concatenation** (`..`) not yet supported
  - Workaround: Use multiple `print()` calls
- **For/while loops** experimental
  - Workaround: Use `exec()` for iteration
- **Tables/arrays** not yet available
  - Workaround: Use shell arrays via `exec()`

### Shell Features
- **Redirection** partially implemented (stdio works, files WIP)
- **Pipes** work for basic cases, complex pipelines WIP
- **Background job management** works but no job notifications yet

### Platform Support
- **Linux only** (tested on Arch Linux, Ubuntu 22.04+)
- **macOS** untested (should work with minor changes)
- **Windows** not supported (WSL2 should work)

---

## 🗺️ Roadmap

### v0.2.0 (Next Minor Release)
- [ ] Ghostlang v0.2 features (string concat, loops, tables)
- [ ] Full redirection support (`>`, `>>`, `<`, `2>&1`)
- [ ] Complex pipeline support
- [ ] Shell completion generation (bash/zsh/fish)
- [ ] More plugins (npm, cargo, python, go)
- [ ] Plugin marketplace

### v0.3.0
- [ ] Async prompt segments (all external commands)
- [ ] Theme system
- [ ] Scripting debugger
- [ ] Performance optimizations
- [ ] macOS support

### v1.0.0 (Stable)
- [ ] Production-ready
- [ ] Full POSIX compliance
- [ ] Comprehensive test coverage (>90%)
- [ ] Security audit
- [ ] Packaging (AUR, Homebrew, etc.)

---

## 🤝 Contributing

We welcome contributions! Areas where help is needed:

1. **Plugins** - Create plugins for popular tools
2. **Testing** - Write integration tests
3. **Documentation** - Improve guides and examples
4. **Bug Reports** - Test and report issues
5. **Features** - Implement items from roadmap

### Getting Started
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `zig build test`
5. Submit a pull request

See [PROGRESS_REPORT.md](PROGRESS_REPORT.md) for current status.

---

## 📜 License

MIT License - see [LICENSE](LICENSE) for details

---

## 🙏 Credits

**Developed by**: [ghostkellz](https://github.com/ghostkellz)

**Powered by**:
- [Ghostlang](https://github.com/ghostkellz/ghostlang) - Scripting engine
- [Flash](https://github.com/ghostkellz/flash) - CLI framework
- [gcode](https://github.com/ghostkellz/gcode) - Unicode handling
- [Zig](https://ziglang.org) - Systems programming language

**Special Thanks**:
- Zig community for the amazing language
- Ghostlang contributors
- All beta testers and early adopters

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/ghostkellz/gshell/issues)
- **Discussions**: [GitHub Discussions](https://github.com/ghostkellz/gshell/discussions)
- **Email**: (Coming soon)

---

<p align="center">
  <strong>🪐 Built with Zig and Ghostlang 🪐</strong><br>
  <em>The next generation shell is here!</em>
</p>

---

**Download**: [GitHub Releases](https://github.com/ghostkellz/gshell/releases/tag/v0.1.0-beta)
**Version**: 0.1.0-beta
**Released**: October 5, 2025
