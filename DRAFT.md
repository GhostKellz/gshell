# GShell — TODO

**Project codename:** `gshell`  
**File extension:** `.gsh`  
**Goal:** A modern, ghost-branded successor to Bash/Zsh/Fish that integrates with GhostShell (terminal), GhostLang (scripting), and modern Linux workflows.

---

## 🎯 Vision

- **Lineage, not legacy**: Keep the familiarity of traditional shells but evolve past the baggage of `bash`, `zsh`, and `fish`.
- **Ghost Ecosystem Ready**: First-class integration with GhostLang `.gza`, GhostShell (terminal), and other ghost-branded tools.
- **Future-Proof**: Built with Zig/Rust foundations, modular core, async-native APIs, and security-first design.

---

## 📦 Core Milestones

### Phase 1 — Foundations
- [ ] Define `.gsh` file format (UTF-8, strict parsing, extension conventions)
- [ ] Parser/lexer design (inspired by POSIX shell but modernized)
- [ ] Minimal REPL (`gshell` interactive prompt)
- [ ] Basic script execution from `.gsh` files
- [ ] Implement variables, quoting, command substitution
- [ ] Core built-ins: `cd`, `pwd`, `echo`, `export`, `alias`, `exit`

### Phase 2 — Language Improvements
- [ ] Structured error handling (no more cryptic exit codes only)
- [ ] Functions as first-class citizens
- [ ] Improved conditionals (`if`, `match`, pattern matching)
- [ ] Iterators instead of fragile `for` loops
- [ ] Async/await primitives for I/O
- [ ] Integration with GhostLang scripting blocks

### Phase 3 — Modern Developer Features
- [ ] Plugin system for builtins (Zig/Rust modules)
- [ ] Cross-platform support (Linux, BSD, macOS, Windows WSL)
- [ ] Virtual environments for scripts
- [ ] Unified package runner (`gshell run package.gsh`)
- [ ] Strong completion system (like Fish but programmable)
- [ ] Smart prompts: async git status, system info, etc.

---

## 🌐 Ghost Ecosystem Integration
- [ ] Native support for `.gza` (GhostLang) inline scripting
- [ ] Tight integration with GhostShell terminal emulator
- [ ] Logging hooks to `zlog` (structured logs)
- [ ] Configurable via `gvault` for secure secrets
- [ ] Package/build awareness via `zpack` and `zbuild`

---

## 🔒 Security
- [ ] No arbitrary code execution on import
- [ ] Sandboxed execution mode for `.gsh` scripts
- [ ] Memory-safe foundation (Zig or Rust runtime)
- [ ] Signed script execution (integrate with gvault keys)

---

## 🚀 Stretch Goals
- [ ] Compatibility layer for `.sh`/`.zsh`/`.fish` scripts
- [ ] Interactive TUI debugger for `.gsh` scripts
- [ ] Direct REPL-to-Cloud integration (GhostMesh, GhostBay, etc.)
- [ ] WASM runtime support for sandboxed plugin execution
- [ ] IDE integration: LSP server for `.gsh`

---

## 📊 Success Metrics
- Runs core Linux automation tasks without regressions
- Developers can replace `.sh`/`.zsh` scripts with `.gsh` confidently
- At least one production system running entirely on `.gsh`
- First-class adoption in Ghost ecosystem tooling

---

**Tagline:**  
✨ `gshell` — A modern shell for the post-bash era. ✨

