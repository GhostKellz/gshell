# 🔍 GShell Integration Discovery & Priority Matrix
## Comprehensive TODO List for the Ghost Stack Integration

---

## 📊 **Project Dependency Map**

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        The Ghost Stack Ecosystem                         │
└─────────────────────────────────────────────────────────────────────────┘

                              Ghostshell (Terminal)
                                      ↓
                                   GShell
                                      ↓
        ┌──────────────────┬─────────┴─────────┬──────────────────┐
        │                  │                   │                  │
     GVault            zssh/zcrypto        Grove/ghostls       Grim
  (Keychain)            (SSH 2.0)       (Tree-sitter/LSP)   (Editor)
        │                  │                   │                  │
        └──────────────────┴───────────────────┴──────────────────┘
                                      ↓
                              Underlying Libraries
        ┌──────────────────┬─────────┴─────────┬──────────────────┐
        │                  │                   │                  │
    zsync/zigzag        zqlite             zlog/flare          phantom
   (Async Runtime)     (Database)          (Logging)           (TUI)
```

---

## 🎯 **Priority Matrix**

### **P0: Critical Path (Ship v0.2.0)** - Next 2-3 weeks
Must have for a compelling demo and daily use.

1. ✅ **GVault Integration** - SSH key storage and auto-loading
2. ✅ **zssh Integration** - Native SSH client
3. ✅ **Grove Integration** - Tree-sitter syntax highlighting
4. ✅ **Basic Ghostshell Protocol** - OSC 133 semantic zones

### **P1: High Value (Ship v0.3.0)** - 1 month
Significantly differentiate from competitors.

5. ✅ **ghostls Integration** - LSP-powered completions and diagnostics
6. ✅ **Grim Quick-Edit** - `e file` opens in Grim
7. ✅ **Advanced GVault Features** - GPG keys, API tokens
8. ✅ **Connection Pooling** - Reuse SSH connections

### **P2: Polish & Power (Ship v0.4.0)** - 2 months
Advanced features for power users.

9. ✅ **Jump Host Automation** - Transparent bastion hosts
10. ✅ **Port Forwarding** - Built-in -L/-R/-D support
11. ✅ **SCP/SFTP Commands** - Native file transfer
12. ✅ **Git + GPG Signing** - Automatic commit signing

### **P3: Future Vision (Ship v1.0)** - 3-6 months
Game-changing features.

13. ✅ **Multi-Server Management** - Parallel SSH execution
14. ✅ **Web-Based Terminal** - Browser SSH access
15. ✅ **Team Collaboration** - Shared credentials (encrypted)
16. ✅ **Audit & Compliance** - Full credential access logging

---

## 📋 **Detailed Integration Tasks**

---

## 🔐 **1. GVault Integration (P0)** - Week 1-2

### **What GVault Needs to Build:**

#### **1.1 GShell-Specific API Module**

**File: `gvault/src/shell_api.zig`**

```zig
/// GShell-optimized API for credential management
pub const ShellApi = struct {
    vault: *Vault,

    /// Get SSH key for host pattern matching
    pub fn getSshKeyForHost(self: *ShellApi, host: []const u8) !?KeyData {
        // Pattern matching: *.example.com, github.com, etc.
    }

    /// Get GPG key for git signing
    pub fn getGpgKeyForGit(self: *ShellApi) !?KeyData {
        // Return configured git signing key
    }

    /// Get API token by service name
    pub fn getApiToken(self: *ShellApi, service: []const u8) !?[]const u8 {
        // Return token for "github", "gitlab", "docker", etc.
    }

    /// Fast credential check without full unlock
    pub fn hasCredentialsFor(self: *ShellApi, pattern: []const u8) bool {
        // Quick check if we have matching credentials
    }

    /// Auto-load based on command being executed
    pub fn autoLoadForCommand(self: *ShellApi, cmd: []const u8, args: [][]const u8) !void {
        // Smart auto-loading: "ssh user@host" loads SSH key
        // "git push" loads GPG key, "docker login" loads API token
    }
};
```

**Priority:** 🔴 P0 - Required for basic SSH integration

**Deliverable:** GVault exports `shell_api.zig` module

---

#### **1.2 Pattern Matching Engine**

**File: `gvault/src/patterns.zig`**

```zig
/// Advanced pattern matching for host/service detection
pub const PatternMatcher = struct {
    /// Match glob patterns: *.example.com
    pub fn matchGlob(pattern: []const u8, value: []const u8) bool {}

    /// Match regex patterns: ^prod-.*\.internal$
    pub fn matchRegex(pattern: []const u8, value: []const u8) !bool {}

    /// Rank matches by specificity
    pub fn rankMatches(patterns: []Pattern, value: []const u8) []RankedMatch {}
};
```

**Priority:** 🔴 P0

**Deliverable:** Pattern matching for auto-loading SSH keys

---

#### **1.3 Async Unlock Support**

**File: `gvault/src/async_unlock.zig`**

```zig
/// Non-blocking vault unlock for shell responsiveness
pub fn unlockAsync(
    vault: *Vault,
    password: []const u8,
    callback: fn(*Vault, error) void
) !void {
    // Use zsync for async unlock
    // Don't block shell prompt
}
```

**Priority:** 🟡 P1 - UX improvement

**Deliverable:** Shell stays responsive during unlock

---

### **What GShell Needs to Build:**

#### **1.4 Vault Manager Module**

**File: `gshell/src/vault.zig`**

```zig
pub const VaultManager = struct {
    vault: gvault.ShellApi,
    cache: KeyCache,

    pub fn initFromConfig(allocator: std.mem.Allocator) !VaultManager {}
    pub fn getSshKeyForHost(self: *VaultManager, host: []const u8) !?[]const u8 {}
    pub fn autoLoadForCommand(self: *VaultManager, cmd: []const u8) !void {}
};
```

**Priority:** 🔴 P0

**Status:** ⏳ Waiting for GVault shell_api.zig

---

#### **1.5 Vault Built-in Commands**

**File: `gshell/src/builtins/vault.zig`**

Commands to implement:
- `vault init` - Initialize vault
- `vault list` - List all credentials
- `vault add-key <name> <path>` - Add SSH key
- `vault generate <type> <name>` - Generate key (SSH, GPG)
- `vault profile <name>` - Manage connection profiles
- `vault unlock` - Unlock vault manually
- `vault lock` - Lock vault

**Priority:** 🔴 P0

**Status:** ⏳ Waiting for GVault shell_api.zig

---

#### **1.6 GPG Integration**

**File: `gshell/src/gpg.zig`**

```zig
pub const GpgManager = struct {
    vault: *VaultManager,

    /// Sign git commit
    pub fn signCommit(self: *GpgManager, commit_msg: []const u8) ![]const u8 {}

    /// Configure git to use vault GPG key
    pub fn configureGit(self: *GpgManager) !void {}

    /// Encrypt/decrypt data
    pub fn encrypt(self: *GpgManager, data: []const u8, recipient: []const u8) ![]const u8 {}
};
```

**Priority:** 🟡 P1 - Important for git workflows

---

---

## 🌐 **2. zssh Integration (P0)** - Week 3-4

### **What zssh Needs to Build:**

#### **2.1 High-Level Client API**

**File: `zssh/src/easy_client.zig`**

```zig
/// Simplified API for shell integration
pub const EasyClient = struct {
    /// One-shot command execution (most common use case)
    pub fn exec(allocator: std.mem.Allocator, config: ConnectConfig) !ExecResult {
        // Connect, execute, return output, disconnect
    }

    /// Interactive session with PTY
    pub fn interactive(allocator: std.mem.Allocator, config: ConnectConfig) !void {
        // Setup PTY, handle terminal I/O
    }

    /// Connect and return reusable client
    pub fn connect(allocator: std.mem.Allocator, config: ConnectConfig) !*Client {
        // Return client for connection pooling
    }
};

pub const ConnectConfig = struct {
    host: []const u8,
    port: u16 = 22,
    user: []const u8,
    auth: AuthMethod,
    jump_host: ?*Client = null, // For bastion hosts
};

pub const AuthMethod = union(enum) {
    password: []const u8,
    private_key: []const u8,
    agent: void, // Use ssh-agent (fallback)
};
```

**Priority:** 🔴 P0 - Required for basic SSH

**Deliverable:** Simple API for shell commands

---

#### **2.2 Connection Health Checking**

**File: `zssh/src/health.zig`**

```zig
pub const HealthChecker = struct {
    /// Check if connection is still alive
    pub fn isAlive(client: *Client) bool {}

    /// Send keepalive if needed
    pub fn keepAlive(client: *Client) !void {}

    /// Get connection stats
    pub fn getStats(client: *Client) ConnectionStats {}
};
```

**Priority:** 🔴 P0 - Required for connection pooling

**Deliverable:** Shell can check if cached connections are valid

---

#### **2.3 Jump Host / ProxyJump Support**

**File: `zssh/src/jump.zig`**

```zig
pub const JumpHost = struct {
    /// Connect through jump host
    pub fn connectViaJump(
        allocator: std.mem.Allocator,
        jump: *Client,
        target: ConnectConfig,
    ) !*Client {}

    /// Setup port forward tunnel
    pub fn tunnel(
        jump: *Client,
        local_port: u16,
        remote_host: []const u8,
        remote_port: u16,
    ) !*Tunnel {}
};
```

**Priority:** 🟡 P1 - Important for production access

**Deliverable:** Transparent bastion host support

---

#### **2.4 Port Forwarding**

**File: `zssh/src/forward.zig`**

```zig
pub const PortForward = struct {
    /// Local port forwarding (-L)
    pub fn localForward(
        client: *Client,
        local_port: u16,
        remote_host: []const u8,
        remote_port: u16,
    ) !*Forward {}

    /// Remote port forwarding (-R)
    pub fn remoteForward(
        client: *Client,
        remote_port: u16,
        local_host: []const u8,
        local_port: u16,
    ) !*Forward {}

    /// Dynamic SOCKS proxy (-D)
    pub fn dynamicForward(
        client: *Client,
        local_port: u16,
    ) !*SocksProxy {}
};
```

**Priority:** 🟠 P2 - Power user feature

**Deliverable:** Full SSH port forwarding support

---

### **What GShell Needs to Build:**

#### **2.5 SSH Built-in Command**

**File: `gshell/src/builtins/ssh.zig`**

```zig
pub fn sshCommand(ctx: *builtins.Context, args: [][]const u8) !builtins.ExecResult {
    // Parse ssh arguments: [user@]host [command]
    // Get key from GVault
    // Use zssh to connect
    // Handle interactive vs command mode
}
```

**Priority:** 🔴 P0

**Status:** ⏳ Waiting for zssh easy_client.zig

---

#### **2.6 Connection Pool Manager**

**File: `gshell/src/ssh_pool.zig`**

```zig
pub const ConnectionPool = struct {
    connections: std.StringHashMap(*zssh.Client),
    mutex: std.Thread.Mutex,

    /// Get or create connection
    pub fn getConnection(self: *ConnectionPool, host: []const u8) !*zssh.Client {}

    /// Check and cleanup dead connections
    pub fn cleanupDead(self: *ConnectionPool) void {}
};
```

**Priority:** 🔴 P0 - Required for performance

---

#### **2.7 SCP Built-in Command**

**File: `gshell/src/builtins/scp.zig`**

```zig
pub fn scpCommand(ctx: *builtins.Context, args: [][]const u8) !builtins.ExecResult {
    // Parse: scp src dst
    // Detect direction (upload vs download)
    // Use zssh for transfer
}
```

**Priority:** 🟠 P2

**Status:** ⏳ Waiting for zssh SFTP support

---

---

## 🌲 **3. Grove Integration (P0)** - Week 1-2 (Parallel)

### **What Grove Needs to Build:**

#### **3.1 Shell Script Grammar**

**File: `grove/grammars/shell/`**

Grove needs a Tree-sitter grammar for shell scripting:

```javascript
// grammar.js
module.exports = grammar({
  name: 'gshell',

  rules: {
    source_file: $ => repeat($._statement),

    _statement: $ => choice(
      $.command,
      $.pipeline,
      $.redirect,
      $.comment,
      $.variable_assignment,
    ),

    command: $ => seq(
      field('name', $.word),
      repeat(field('argument', $.word)),
    ),

    pipeline: $ => seq(
      $.command,
      repeat(seq('|', $.command)),
    ),

    // ... more rules
  }
});
```

**Priority:** 🔴 P0 - Required for syntax highlighting

**Deliverable:** GShell grammar for Grove

---

#### **3.2 Real-Time Highlighting API**

**File: `grove/src/realtime.zig`**

```zig
/// API optimized for interactive shell highlighting
pub const RealtimeHighlighter = struct {
    parser: *Parser,
    tree: ?*Tree,

    /// Parse and highlight partial input (as user types)
    pub fn highlightPartial(
        self: *RealtimeHighlighter,
        input: []const u8,
    ) ![]HighlightSpan {}

    /// Update highlights incrementally
    pub fn updateIncremental(
        self: *RealtimeHighlighter,
        old_input: []const u8,
        new_input: []const u8,
        edit: Edit,
    ) ![]HighlightSpan {}
};
```

**Priority:** 🔴 P0

**Deliverable:** Fast highlighting for REPL

---

### **What GShell Needs to Build:**

#### **3.3 Syntax Highlighter Module**

**File: `gshell/src/highlight.zig`**

```zig
pub const SyntaxHighlighter = struct {
    grove: grove.RealtimeHighlighter,
    theme: Theme,

    pub fn init(allocator: std.mem.Allocator) !SyntaxHighlighter {}

    /// Highlight command line as user types
    pub fn highlight(self: *SyntaxHighlighter, line: []const u8) ![]Span {}

    /// Apply theme colors
    pub fn applyTheme(self: *SyntaxHighlighter, spans: []Span) ![]const u8 {}
};
```

**Priority:** 🔴 P0

**Status:** ⏳ Waiting for Grove shell grammar + realtime API

---

#### **3.4 Theme System**

**File: `gshell/src/themes/`**

Color themes for syntax highlighting:
- `default.zig` - Default GShell colors
- `gruvbox.zig` - Gruvbox theme
- `dracula.zig` - Dracula theme
- `nord.zig` - Nord theme

**Priority:** 🟡 P1

---

---

## 🧠 **4. ghostls Integration (P1)** - Week 3-4

### **What ghostls Needs to Build:**

#### **4.1 Shell Script Language Support**

**File: `ghostls/src/languages/gshell.zig`**

ghostls needs to understand shell script syntax:

```zig
pub const GShellLanguage = struct {
    /// Provide completions for shell commands
    pub fn getCompletions(
        context: CompletionContext,
    ) ![]CompletionItem {
        // Complete commands, flags, file paths
    }

    /// Provide diagnostics (errors, warnings)
    pub fn getDiagnostics(
        source: []const u8,
    ) ![]Diagnostic {
        // Check syntax errors
        // Warn about undefined variables
        // Suggest command corrections
    }

    /// Provide hover information
    pub fn getHover(
        source: []const u8,
        position: Position,
    ) !?Hover {
        // Show command documentation
        // Show variable values
    }
};
```

**Priority:** 🟡 P1 - Enhances UX

**Deliverable:** LSP support for shell scripts

---

#### **4.2 Command Documentation Database**

**File: `ghostls/src/command_docs.zig`**

```zig
/// Documentation for common commands
pub const CommandDocs = struct {
    docs: std.StringHashMap(CommandDoc),

    pub fn getDoc(self: *CommandDocs, cmd: []const u8) ?CommandDoc {}

    pub const CommandDoc = struct {
        name: []const u8,
        description: []const u8,
        flags: []FlagDoc,
        examples: [][]const u8,
    };
};
```

**Priority:** 🟡 P1

**Deliverable:** Hover shows command help

---

### **What GShell Needs to Build:**

#### **4.3 LSP Client Integration**

**File: `gshell/src/lsp_client.zig`**

```zig
/// Minimal LSP client for talking to ghostls
pub const LspClient = struct {
    process: std.process.Child,
    stdin: std.io.Writer,
    stdout: std.io.Reader,

    pub fn init(allocator: std.mem.Allocator) !LspClient {}

    /// Request completions
    pub fn getCompletions(
        self: *LspClient,
        source: []const u8,
        position: usize,
    ) ![]Completion {}

    /// Get diagnostics
    pub fn getDiagnostics(
        self: *LspClient,
        source: []const u8,
    ) ![]Diagnostic {}
};
```

**Priority:** 🟡 P1

**Status:** ⏳ Waiting for ghostls shell language support

---

#### **4.4 Smart Completions**

**File: `gshell/src/completions.zig`**

```zig
pub const CompletionEngine = struct {
    lsp: ?*LspClient,
    history: *HistoryStore,
    commands: CommandRegistry,

    /// Get completions from multiple sources
    pub fn getCompletions(
        self: *CompletionEngine,
        partial: []const u8,
    ) ![]Completion {
        // Merge from:
        // - ghostls LSP (syntax-aware)
        // - History (frecency-based)
        // - Command registry (builtins)
        // - File system (path completion)
    }
};
```

**Priority:** 🟡 P1

---

---

## 🖥️ **5. Ghostshell Integration (P0)** - Week 1-2

### **What Ghostshell Needs to Build:**

#### **5.1 Shell Integration API**

**File: `ghostshell/src/shell_api.zig`**

```zig
/// API for shell integration
pub const ShellApi = struct {
    /// Register as shell integration handler
    pub fn registerShell(shell_name: []const u8) !void {}

    /// Notify terminal of shell state changes
    pub fn notifyPromptStart() !void {}
    pub fn notifyCommandStart() !void {}
    pub fn notifyCommandEnd(exit_code: i32) !void {}

    /// Request keychain access
    pub fn requestKeychainAccess() !KeychainHandle {}
};
```

**Priority:** 🔴 P0

**Deliverable:** Ghostshell recognizes GShell

---

#### **5.2 Keychain IPC Protocol**

**File: `ghostshell/src/keychain_ipc.zig`**

```zig
/// IPC protocol for shell <-> keychain communication
pub const KeychainIpc = struct {
    /// Request credential from keychain
    pub fn requestCredential(
        service: []const u8,
        pattern: []const u8,
    ) !?Credential {}

    /// Store credential in keychain
    pub fn storeCredential(
        service: []const u8,
        credential: Credential,
    ) !void {}
};
```

**Priority:** 🔴 P0 - Required for GVault <-> Ghostshell

**Deliverable:** GVault can talk to Ghostshell keychain

---

### **What GShell Needs to Build:**

#### **5.3 Terminal Protocol Module**

**File: `gshell/src/terminal.zig`**

```zig
pub const TerminalProtocol = struct {
    writer: std.io.Writer,

    /// Send OSC 133 marks
    pub fn markPromptStart(self: *TerminalProtocol) !void {}
    pub fn markCommandStart(self: *TerminalProtocol) !void {}
    pub fn markCommandEnd(self: *TerminalProtocol, exit_code: i32) !void {}

    /// Detect terminal capabilities
    pub fn detectCapabilities(self: *TerminalProtocol) !Capabilities {}

    /// Check if running in Ghostshell
    pub fn isGhostshell(self: *TerminalProtocol) bool {}
};
```

**Priority:** 🔴 P0

---

#### **5.4 Ghostshell Feature Detection**

**File: `gshell/src/ghostshell_detect.zig`**

```zig
/// Detect if running in Ghostshell and available features
pub fn detectGhostshell() GhostshellInfo {
    // Check $TERM, $GHOSTSHELL_VERSION
    // Query terminal capabilities
    // Return available features
}

pub const GhostshellInfo = struct {
    is_ghostshell: bool,
    version: ?[]const u8,
    has_keychain: bool,
    has_inline_graphics: bool,
    has_ssh_integration: bool,
};
```

**Priority:** 🔴 P0

---

---

## ✏️ **6. Grim Integration (P1)** - Week 3-4

### **What Grim Needs to Build:**

#### **6.1 Shell Command Execution**

**File: `grim/src/shell_executor.zig`**

```zig
/// Execute shell commands from editor
pub const ShellExecutor = struct {
    /// Execute command and capture output
    pub fn execute(cmd: []const u8) !ExecuteResult {}

    /// Execute and insert output into buffer
    pub fn executeAndInsert(buffer: *Buffer, cmd: []const u8) !void {}

    /// Open shell in split
    pub fn openShell(direction: SplitDirection) !void {}
};
```

**Priority:** 🟡 P1

**Deliverable:** `:Shell` command in Grim

---

#### **6.2 Quick-Edit Protocol**

**File: `grim/src/quick_edit.zig`**

```zig
/// Handle quick-edit requests from shell
pub const QuickEdit = struct {
    /// Open file from shell `e` command
    pub fn openFromShell(
        file: []const u8,
        line: ?usize,
        column: ?usize,
    ) !void {}

    /// Edit command in editor (fc equivalent)
    pub fn editCommand(cmd: []const u8) ![]const u8 {}
};
```

**Priority:** 🟡 P1

**Deliverable:** Shell `e` command opens Grim

---

### **What GShell Needs to Build:**

#### **6.3 Edit Built-in Command**

**File: `gshell/src/builtins/edit.zig`**

```zig
pub fn editCommand(ctx: *builtins.Context, args: [][]const u8) !builtins.ExecResult {
    // e file.txt → Opens in Grim
    // e - → Edit last command
    // fc 42 → Edit command #42 from history
}
```

**Priority:** 🟡 P1

---

#### **6.4 Grim IPC**

**File: `gshell/src/grim_ipc.zig`**

```zig
/// Communication with Grim editor
pub const GrimIpc = struct {
    socket_path: []const u8,

    /// Send file to open in Grim
    pub fn openFile(
        self: *GrimIpc,
        file: []const u8,
    ) !void {}

    /// Edit text in Grim and return result
    pub fn editText(
        self: *GrimIpc,
        text: []const u8,
    ) ![]const u8 {}
};
```

**Priority:** 🟡 P1

---

---

## 📦 **Integration Dependency Matrix**

### **Who Needs What From Whom:**

| Project | Depends On | Module Needed | Priority |
|---------|-----------|---------------|----------|
| **GShell** | GVault | `shell_api.zig`, `patterns.zig` | 🔴 P0 |
| **GShell** | zssh | `easy_client.zig`, `health.zig` | 🔴 P0 |
| **GShell** | Grove | Shell grammar, `realtime.zig` | 🔴 P0 |
| **GShell** | ghostls | Shell language support | 🟡 P1 |
| **GShell** | Ghostshell | `shell_api.zig`, `keychain_ipc.zig` | 🔴 P0 |
| **GShell** | Grim | `quick_edit.zig` | 🟡 P1 |
| **GVault** | zcrypto | Encryption primitives | ✅ Done |
| **GVault** | zqlite | Database storage | ✅ Done |
| **zssh** | zcrypto | SSH crypto | ✅ Done |
| **zssh** | zsync | Async I/O | ✅ Done |
| **Grove** | tree-sitter | Parser runtime | ✅ Done |
| **ghostls** | Grove | Tree-sitter integration | ✅ Done |

---

## 🎯 **Action Items by Project**

### **GVault Action Items:**

- [ ] **P0:** Create `shell_api.zig` module
- [ ] **P0:** Implement pattern matching (`patterns.zig`)
- [ ] **P0:** SSH key auto-loading based on host patterns
- [ ] **P1:** Async unlock support
- [ ] **P1:** GPG key storage and signing
- [ ] **P1:** API token storage
- [ ] **P2:** Hardware security key support (YubiKey)

**Estimated Time:** 2 weeks

---

### **zssh Action Items:**

- [ ] **P0:** Create `easy_client.zig` simplified API
- [ ] **P0:** Implement connection health checking
- [ ] **P0:** PTY support for interactive sessions
- [ ] **P1:** Jump host / ProxyJump support
- [ ] **P2:** Port forwarding (-L/-R/-D)
- [ ] **P2:** SFTP file transfer

**Estimated Time:** 3-4 weeks

---

### **Grove Action Items:**

- [ ] **P0:** Create GShell Tree-sitter grammar
- [ ] **P0:** Implement `realtime.zig` for REPL highlighting
- [ ] **P0:** Optimize for incremental updates
- [ ] **P1:** Theme query support
- [ ] **P1:** Error recovery for partial input

**Estimated Time:** 1-2 weeks

---

### **ghostls Action Items:**

- [ ] **P1:** Add shell script language support
- [ ] **P1:** Command documentation database
- [ ] **P1:** Context-aware completions for shell
- [ ] **P1:** Diagnostics for shell scripts
- [ ] **P2:** Hover documentation

**Estimated Time:** 2 weeks

---

### **Ghostshell Action Items:**

- [ ] **P0:** Create `shell_api.zig` for integration
- [ ] **P0:** Implement keychain IPC protocol
- [ ] **P0:** OSC 133 semantic zone support
- [ ] **P1:** SSH key integration with GVault
- [ ] **P1:** Inline graphics protocol

**Estimated Time:** 2 weeks

---

### **Grim Action Items:**

- [ ] **P1:** Shell command execution (`:Shell`)
- [ ] **P1:** Quick-edit protocol for `e` command
- [ ] **P1:** IPC server for shell integration
- [ ] **P2:** Split terminal support

**Estimated Time:** 1 week

---

### **GShell Action Items:**

- [ ] **P0:** Vault manager integration
- [ ] **P0:** Built-in `vault` commands
- [ ] **P0:** SSH built-in with zssh
- [ ] **P0:** Connection pooling
- [ ] **P0:** Syntax highlighting with Grove
- [ ] **P0:** Terminal protocol (OSC 133)
- [ ] **P1:** Smart completions with ghostls
- [ ] **P1:** GPG signing integration
- [ ] **P1:** `edit` command for Grim
- [ ] **P2:** SCP built-in
- [ ] **P2:** Jump host automation
- [ ] **P2:** Port forwarding

**Estimated Time:** 4-6 weeks

---

## 📅 **Proposed Timeline**

### **Week 1-2: Foundation (Parallel Development)**

**GVault Team:**
- Build `shell_api.zig`
- Implement pattern matching
- SSH key auto-loading

**zssh Team:**
- Build `easy_client.zig`
- Connection health checking
- PTY support

**Grove Team:**
- Create GShell grammar
- Build `realtime.zig` API

**GShell Team:**
- Vault manager module
- SSH built-in skeleton
- Syntax highlighter skeleton

**Ghostshell Team:**
- Shell integration API
- Keychain IPC protocol

**Deliverable:** Basic SSH + GVault + highlighting working

---

### **Week 3-4: Integration**

**All Teams:**
- Integration testing
- Bug fixes
- Performance optimization

**GShell:**
- Complete vault built-ins
- Complete SSH command
- Complete highlighting
- Terminal protocol

**Deliverable:** v0.2.0 "Secure" release

---

### **Week 5-6: Polish (P1 Features)**

**ghostls:**
- Shell language support
- Completions

**Grim:**
- Quick-edit protocol
- Shell execution

**GVault:**
- GPG key support
- Async unlock

**zssh:**
- Jump host support

**GShell:**
- Smart completions
- GPG signing
- `edit` command

**Deliverable:** v0.3.0 "Smart" release

---

### **Week 7-8+: Power Features (P2)**

**zssh:**
- Port forwarding
- SFTP

**GShell:**
- SCP command
- Multi-server management
- Advanced features

**Deliverable:** v0.4.0 "Power" release

---

## 🔗 **Key Integration Points**

### **1. GShell ↔ GVault**
- **Protocol:** Direct Zig API calls
- **Data Flow:** GShell → GVault (get credentials)
- **Critical Path:** SSH key auto-loading

### **2. GShell ↔ zssh**
- **Protocol:** Direct Zig API calls
- **Data Flow:** GShell → zssh (SSH connections)
- **Critical Path:** Native SSH built-in

### **3. GShell ↔ Grove**
- **Protocol:** Direct Zig API calls
- **Data Flow:** GShell → Grove (parse & highlight)
- **Critical Path:** Real-time syntax highlighting

### **4. GShell ↔ ghostls**
- **Protocol:** LSP over stdin/stdout
- **Data Flow:** Bidirectional JSON-RPC
- **Critical Path:** Smart completions

### **5. GShell ↔ Ghostshell**
- **Protocol:** OSC sequences + IPC
- **Data Flow:** Bidirectional escape codes
- **Critical Path:** Semantic zones, keychain

### **6. GShell ↔ Grim**
- **Protocol:** UNIX socket IPC
- **Data Flow:** Bidirectional commands
- **Critical Path:** Quick-edit

### **7. GVault ↔ Ghostshell**
- **Protocol:** Keychain IPC
- **Data Flow:** Bidirectional credentials
- **Critical Path:** Unified keychain

---

## 💡 **Success Metrics**

### **v0.2.0 "Secure" Success:**
- [ ] `ssh user@host` works with auto-loaded key from GVault
- [ ] Syntax highlighting works in real-time
- [ ] Connection reuse makes subsequent SSH instant
- [ ] OSC 133 marks work in Ghostshell

### **v0.3.0 "Smart" Success:**
- [ ] Tab completions are context-aware (ghostls)
- [ ] `e file.txt` opens in Grim
- [ ] GPG key signing works for git commits
- [ ] Jump hosts work transparently

### **v1.0 "Complete" Success:**
- [ ] No external SSH client needed
- [ ] No ssh-agent needed
- [ ] No separate password manager needed
- [ ] Seamless Ghost Stack experience

---

## 🚀 **Next Steps**

### **Immediate (This Week):**

1. **Kickoff meetings** with GVault, zssh, Grove teams
2. **Define API contracts** for each integration point
3. **Create shared repository** for API specs
4. **Set up integration test suite**

### **Week 1 Deliverables:**

- [ ] GVault: `shell_api.zig` skeleton
- [ ] zssh: `easy_client.zig` skeleton
- [ ] Grove: GShell grammar started
- [ ] GShell: Integration modules scaffolded

### **Communication:**

- **Daily standups** for integration coordination
- **Shared doc** for API changes
- **Integration test CI** to catch breaks early

---

**Let's build the most integrated shell ever! 🚀**
