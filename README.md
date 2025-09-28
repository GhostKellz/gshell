<p align="center">
  <img src="assets/icons/gshell.png" alt="GShell logo" width="180" />
</p>

![zig](https://img.shields.io/badge/Built%20with-Zig-yellow?logo=zig)
![zig-ver](https://img.shields.io/badge/zig-0.16.0--dev-orange?logo=zig)
![async](https://img.shields.io/badge/Async-zsync%20powered-blueviolet?logo=zig)
![ghostlang](https://img.shields.io/badge/Config-Ghostlang%20(.gza)-purple?logo=lua)
![shell](https://img.shields.io/badge/Shell-Next%20Gen%20Linux%20Shell-green?logo=gnubash)

# GShell

**File Extension:** `.gsh`  
**Tagline:** A modern shell for the post-bash era.

---

## ✨ Overview

GShell (`gshell`) is a next-generation Linux shell designed to replace Bash, Zsh, and Fish with a modern, secure, and extensible foundation.  
It blends the familiarity of classic shells with futuristic features like async I/O, structured error handling, and deep integration with the Ghost ecosystem.

---

## 🎯 Features

- **Modern Language Design**
  - Clean syntax, async primitives, first-class functions
  - Pattern matching & structured error handling
  - `.gsh` script format with strict parsing

- **Ghost Ecosystem Integration**
  - Inline GhostLang (`.gza`) scripting support
  - Works seamlessly with GhostShell (terminal)
  - Logging via `zlog`, secure secrets via `gvault`

- **Developer Experience**
  - Strong completion system (like Fish, programmable)
  - Smart, async prompts
  - Plugin architecture for Zig/Rust extensions
  - Compatibility layer for `.sh`/`.zsh` migration

- **Security**
  - Memory-safe core (Zig/Rust foundation)
  - Sandboxed execution mode
  - Signed scripts with `gvault` keys

---

## 🚀 Quick Start

```bash
# Run the interactive shell
gshell
```

```bash
# Execute a .gsh script
gshell myscript.gsh
```
## ✨ Zig Integration
```bash
zig fetch --save https://github.com/ghostkellz/gshell/archive/refs/head/main.tar.gz
```
