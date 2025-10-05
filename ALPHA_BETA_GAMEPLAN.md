# Alpha → Beta Completion Gameplan

## Executive Summary

**Current Status**: 60% Alpha complete (Job Control ✅, Prompt Engine ✅, History ✅)

**Goal**: Complete Alpha features + selective Beta features to create a compelling daily-driver shell

**Timeline**: 4-6 weeks aggressive development

**Key Decision**: Use **Ghostlang** for advanced scripting constructs (loops, conditionals, functions) rather than building custom POSIX shell parser

---

## 🎯 Phase 1: Complete Alpha (Week 1-2)

### 1.1 Incremental Search (Ctrl+R) - **2-3 days**
**Priority**: HIGH - Essential daily-driver feature

**Implementation:**
- Add search mode state to `Shell` struct
- Implement reverse history search in `readLineInteractiveWithHistory`
- Display search prompt: `(reverse-i-search)\`query': matched_command`
- Navigate matches with repeated Ctrl+R
- Accept with Enter, cancel with Ctrl+C/Ctrl+G

**Files:**
- `src/shell.zig` - Add search mode handling
- Update keyboard handler for Ctrl+R (0x12)

**Acceptance:**
```bash
# Press Ctrl+R
(reverse-i-search)`ec': echo "hello"
# Type more to narrow
(reverse-i-search)`echo h': echo "hello world"
```

---

### 1.2 Tab Completion Framework - **3-4 days**
**Priority**: HIGH - Critical UX feature

**Scope (Minimal):**
- Command completion (search $PATH)
- File/directory completion for arguments
- Basic completion UI (inline, not menu yet)

**Implementation:**
- Add `CompletionEngine` struct in new `src/completion.zig`
- Integrate with `readLineInteractiveWithHistory` on Tab (0x09)
- Path scanning for executables
- Directory traversal for file args
- Common prefix auto-completion

**Files:**
- `src/completion.zig` (NEW) - ~200 lines
- `src/shell.zig` - Tab key handler integration

**Acceptance:**
```bash
# Type "ech" + Tab → completes to "echo"
# Type "ls /tm" + Tab → completes to "ls /tmp/"
# Multiple matches → show list or cycle
```

---

### 1.3 Aliases - **1-2 days**
**Priority**: MEDIUM - Nice-to-have for Alpha

**Implementation:**
- Add alias storage to `ShellState` (HashMap)
- Add `alias` built-in: `alias ll='ls -la'`
- Expand aliases before command execution
- Add `unalias` built-in

**Files:**
- `src/state.zig` - Add alias HashMap
- `src/builtins.zig` - Add alias/unalias commands
- `src/executor.zig` - Alias expansion before exec

**Acceptance:**
```bash
alias ll='ls -la'
ll            # Executes: ls -la
unalias ll
```

---

### 1.4 Shell Functions (Basic) - **2 days**
**Priority**: LOW for Alpha, HIGH for Beta

**Decision**: **Defer to Beta** - Use Ghostlang integration instead

**Rationale**: 
- Native shell function parsing is complex
- Ghostlang provides full language features
- Better to deliver working Ghostlang integration than half-baked shell functions

---

## 🚀 Phase 2: Strategic Beta Features (Week 3-4)

### 2.1 Ghostlang Scripting Integration - **4-5 days**
**Priority**: CRITICAL - Differentiator from Bash/Zsh

**Why Ghostlang?**
- ✅ Already in dependencies (build.zig.zon)
- ✅ Lua-like syntax (familiar to scripters)
- ✅ Sandboxing built-in (security)
- ✅ FFI for Zig interop
- ✅ Conditionals, loops, functions out-of-box
- ✅ Modern features (closures, tables, etc.)

**Implementation Plan:**

#### A. Basic Integration (2 days)
- Add `.gza` script execution support
- Wire ghostlang engine into executor
- Register shell built-ins as Ghostlang functions
- Environment variable access from scripts

**Files:**
- `src/scripting.zig` (NEW) - Ghostlang wrapper ~300 lines
- `src/executor.zig` - Detect .gza files, delegate to scripting engine
- `src/shell.zig` - Initialize ghostlang engine

#### B. Shell Function Replacement (1 day)
Instead of native functions, use Ghostlang:

```bash
# In .gshrc (shell config)
function greet(name) {
    print("Hello, " .. name .. "!")
}

# Call from prompt
greet("World")  # Works!
```

#### C. FFI Bridge (2 days)
Expose shell APIs to Ghostlang scripts:

```lua
-- scripts/backup.gza
local shell = require("gshell")

if shell.path_exists("/data/backup") then
    shell.exec("tar czf backup.tar.gz /data")
    shell.notify("Backup complete!")
else
    shell.error("Backup directory missing!")
    shell.exit(1)
end
```

**Exposed APIs:**
- `shell.exec(cmd)` - Run shell command
- `shell.cd(path)` - Change directory
- `shell.getenv(var)` - Get environment variable
- `shell.setenv(var, val)` - Set environment variable
- `shell.path_exists(path)` - Check file/dir
- `shell.prompt_confirm(msg)` - Interactive prompt

**Acceptance:**
```bash
# Test conditionals
./test_script.gza
# Output: Grade: B

# Test functions
./test_functions.gza
# Output: 7

# Shell integration
gshell --script backup.gza
```

---

### 2.2 Advanced Parser (Partial) - **2-3 days**
**Priority**: MEDIUM - Enable scripting constructs

**Scope:**
- Add heredoc support (`<<EOF`)
- Improve error recovery
- Add syntax validation

**Implementation:**
- Extend tokenizer for heredoc markers
- Add heredoc content accumulation
- Better error messages with position info

**Files:**
- `src/parser.zig` - Heredoc tokenization
- Add `test_parser.zig` - Parser unit tests

**Acceptance:**
```bash
cat <<EOF
Hello
World
EOF
# Outputs both lines
```

---

### 2.3 Async Prompt Segments (Foundation) - **3 days**
**Priority**: HIGH - Key Beta feature

**Why?**
- Git status checks can be slow
- External API calls shouldn't block prompt
- Professional shell experience

**Implementation:**

#### A. Async Segment API (1 day)
```zig
pub const AsyncSegment = struct {
    renderer: *const fn(*Shell, []u8) anyerror![]const u8,
    fallback: []const u8,
    timeout_ms: u64,
    
    pub fn renderAsync(self: *AsyncSegment, allocator: Allocator) !Future([]const u8) {
        // Use zsync for async execution
    }
};
```

#### B. Git Status Segment (1 day)
```zig
fn renderGitStatus(shell: *Shell, buf: []u8) ![]const u8 {
    // Check .git directory
    // Run: git rev-parse --abbrev-ref HEAD
    // Return branch name with dirty indicator
    return "main*";  // * = dirty
}
```

#### C. Integration (1 day)
- Add async segments to `PromptEngine`
- Render loop with timeout handling
- Fallback display if timeout exceeded
- Cache results per-directory

**Files:**
- `src/prompt.zig` - Async segment support
- `src/segments/git.zig` (NEW) - Git status segment
- Wire into zsync runtime

**Acceptance:**
```bash
cd /path/to/git/repo
# Prompt shows: user@host ~/repo (main*) ›
#                                 ^^^^^ git branch with dirty flag
```

---

### 2.4 Grove Integration (Optional) - **2 days**
**Priority**: LOW - Nice syntax highlighting for .gza scripts

**Use Case:**
- Syntax highlight .gza files in `cat` output
- Color-coded error messages
- Future: LSP integration for script editing

**Decision**: **DEFER to Theta** - Not critical for Alpha/Beta daily driver

**Rationale:**
- Grove is for editor integration (Grim)
- Shell doesn't need syntax highlighting yet
- Focus on functionality first

---

## 📋 Phase 3: Testing & Polish (Week 5-6)

### 3.1 Integration Testing - **3 days**
- Test all features interactively
- Create test scripts for common workflows
- Job control edge cases
- History persistence testing
- Alias + Ghostlang interaction

### 3.2 Documentation - **2 days**
- Update README with feature list
- Create USAGE.md with examples
- Document .gshrc configuration
- Ghostlang scripting guide

### 3.3 Performance & Stability - **3 days**
- Profile prompt rendering latency
- Optimize history search
- Fix memory leaks (Valgrind)
- Handle edge cases (empty input, long lines, etc.)

### 3.4 Config File Support - **2 days**
**Critical for daily driver:**

- Load `~/.gshrc` on startup
- Parse Ghostlang config
- Execute initialization commands
- Load aliases and functions

**Example ~/.gshrc:**
```lua
-- GShell Configuration

-- Aliases
alias("ll", "ls -la")
alias("gs", "git status")
alias("gd", "git diff")

-- Environment
setenv("EDITOR", "vim")
setenv("PAGER", "less")

-- Custom function
function mkcd(dir)
    shell.exec("mkdir -p " .. dir)
    shell.cd(dir)
end

-- Prompt customization
prompt.add_segment("left", "${user}@${host}", "blue")
prompt.add_segment("left", "${cwd}", "green")
prompt.add_segment("right", "${git_branch}", "yellow")
```

---

## 🎯 Deliverables Timeline

### Week 1-2: Alpha Completion
- ✅ Job Control (DONE)
- ✅ Prompt Engine (DONE)
- ✅ History Navigation (DONE)
- 🔲 Incremental Search (Ctrl+R)
- 🔲 Tab Completion Framework
- 🔲 Aliases

**Milestone**: Alpha Release candidate, tagged as `v0.1.0-alpha`

---

### Week 3-4: Beta Core Features
- 🔲 Ghostlang Integration (conditionals, loops, functions)
- 🔲 FFI Bridge (shell APIs exposed to scripts)
- 🔲 Async Prompt Segments (Git status)
- 🔲 Heredoc Support
- 🔲 Config File (.gshrc)

**Milestone**: Beta Release candidate, tagged as `v0.2.0-beta`

---

### Week 5-6: Testing & Polish
- 🔲 Integration test suite
- 🔲 Documentation updates
- 🔲 Performance optimization
- 🔲 Bug fixes

**Milestone**: Beta Release, tagged as `v0.2.0`

---

## 🔧 Technical Decisions

### ✅ Use Ghostlang for Scripting
**Instead of**: Building custom POSIX sh parser

**Reasons:**
1. Already integrated (build.zig.zon)
2. Full language features (loops, conditionals, functions, tables)
3. Sandboxing for security
4. FFI for Zig interop
5. Familiar Lua-like syntax
6. Active development

**Trade-offs:**
- Not POSIX sh compatible (intentional - we want better syntax)
- Requires .gza file extension
- Learning curve for Bash users

**Mitigation:**
- Provide migration guide (Bash → Ghostlang)
- Keep POSIX command execution compatible
- Support inline Ghostlang: `gshell -c 'if x > 5 then print("big") end'`

---

### ❌ Defer Grove Integration
**Reasoning:**
- Grove is for editor integration (tree-sitter parsing)
- Shell doesn't need syntax highlighting yet
- Not a daily-driver blocker
- Can add in Theta phase

---

### ✅ Prioritize Async Prompts
**Reasoning:**
- Git status is essential for developers
- Slow prompts are frustrating (Zsh/Oh-My-Zsh complaint)
- zsync already integrated - use it!
- Differentiator from basic shells

---

## 📊 Success Metrics

### Alpha Completion (Week 2)
- [ ] Ctrl+R search works smoothly
- [ ] Tab completion for commands + files
- [ ] Aliases persist across sessions
- [ ] No crashes in normal usage
- [ ] History saves/loads correctly

### Beta Feature Set (Week 4)
- [ ] .gza scripts execute with conditionals/loops
- [ ] Shell functions defined in Ghostlang work
- [ ] Git branch shows in prompt
- [ ] Config file (.gshrc) loads on startup
- [ ] FFI bridge exposes ≥10 shell APIs

### Polish (Week 6)
- [ ] Documented with examples
- [ ] ≥50 integration tests passing
- [ ] Memory leak-free (Valgrind clean)
- [ ] Prompt renders <50ms (including async)
- [ ] Ready for daily use by developers

---

## 🚀 Beyond Beta: Theta Sneak Peek

**After Beta stabilizes**, we tackle:

1. **Grove Integration**: Syntax highlighting for scripts
2. **Plugin System**: Oh-My-Zsh style with Ghostlang
3. **Phantom TUI**: `gshell ui` for visual config/history
4. **Theme Marketplace**: Powerlevel10k/Starship compatibility
5. **LSP Support**: Autocomplete from language servers
6. **Zsh Migration Tool**: Convert .zshrc → .gshrc automatically

---

## 🎬 Implementation Order (Recommended)

### Week 1
**Day 1-2**: Incremental search (Ctrl+R)
**Day 3-4**: Tab completion framework
**Day 5**: Aliases
**Day 6-7**: Testing + bug fixes

### Week 2
**Day 1-2**: Ghostlang basic integration (.gza execution)
**Day 3-4**: FFI bridge (shell API exposure)
**Day 5-7**: Config file support (.gshrc loader)

### Week 3
**Day 1-3**: Async prompt segments (foundation + Git)
**Day 4-5**: Heredoc parser support
**Day 6-7**: Integration testing

### Week 4
**Day 1-2**: Documentation (README, USAGE, scripting guide)
**Day 3-5**: Performance optimization (profiling, fixes)
**Day 6-7**: Bug triage + stability improvements

---

## 🎯 Next Immediate Action

**START HERE** (in order):

1. **Incremental Search** - Most requested feature, high impact
2. **Tab Completion** - Can't be daily driver without it
3. **Ghostlang Integration** - Unlocks all scripting features at once
4. **Async Git Prompt** - Developer must-have
5. **Config File** - Enable customization

**Parallel Work** (if multiple devs):
- Track A: Search + Completion (line editor focus)
- Track B: Ghostlang + FFI (scripting focus)
- Track C: Async prompts (UX focus)

---

## 📝 Open Questions

1. **Ghostlang Syntax in Prompt?**
   - Allow inline: `gshell -c 'print(2 + 2)'` ?
   - Or require files: `gshell script.gza` ?
   - **Decision**: Support both

2. **History File Format?**
   - Plain text (Bash-compatible)
   - Or structured (JSON/SQLite via zqlite)?
   - **Decision**: Start plain text, migrate to SQLite in Beta

3. **Completion Menu UI?**
   - Inline cycling (Tab repeatedly)
   - Or popup menu (like Zsh)?
   - **Decision**: Start inline, add menu in Beta

4. **Async Prompt Caching?**
   - Cache Git status per directory?
   - Invalidate on file changes?
   - **Decision**: Yes, cache with 5s TTL

---

## 🎉 Summary

**This gameplan delivers:**
- ✅ Complete Alpha feature set (search, completion, aliases)
- ✅ Strategic Beta features (Ghostlang, async prompts, config)
- ✅ Daily-driver ready in 4-6 weeks
- ✅ Competitive with Zsh/Fish feature-wise
- ✅ Unique value prop (Ghostlang scripting, Zig performance)

**Key Innovation**: Using Ghostlang for scripting instead of building POSIX sh parser saves months of work and delivers superior language features.

**Next Step**: Start with incremental search implementation (2-3 days, high impact).
