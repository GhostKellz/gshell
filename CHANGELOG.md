# Alpha Release - Change Log

## Major Features Completed

### 1. Job Control System ✅
Complete background job management system with POSIX-compliant signal handling.

**Components:**
- **Parser Support**: Added `&` token recognition for background job suffix
- **State Management**: 
  - `Job` struct tracking: ID, PID, status, command text
  - Job lifecycle methods: `addJob`, `getJob`, `getJobByPid`, `removeJob`
- **Execution**:
  - `runPipelineBackground` for non-blocking process spawning
  - Background job tracking in `ExecOutcome`
- **Built-ins**:
  - `jobs` - List all active/stopped jobs
  - `fg <job_id>` - Foreground a background job
  - `bg <job_id>` - Continue stopped job in background
- **Signal Handling**:
  - SIGCHLD handler with automatic job reaping
  - waitpid integration (updated for Zig 0.16 API changes)

**Example Usage:**
```bash
sleep 10 &        # Start background job
[1] started       # Job ID displayed
jobs              # List all jobs
fg 1              # Bring job 1 to foreground
```

---

### 2. Prompt Engine ✅
Modular, segment-based prompt rendering system with dynamic variable expansion.

**Architecture:**
- `PromptSegment` struct: text, alignment (left/right), color
- `PromptEngine` manages segment arrays and rendering
- `PromptContext` provides runtime state (cwd, user, host, exit code, job count)

**Features:**
- **Variable Expansion**:
  - `${user}` - Current username
  - `${host}` - Hostname
  - `${cwd}` - Current working directory (compact paths)
  - `${exit_status}` - Last command exit code
  - `${jobs}` - Number of active jobs
- **Layout**:
  - Left-aligned segments (prompt prefix)
  - Right-aligned segments (status indicators)
  - Automatic padding calculation
- **Rendering**:
  - Terminal width-aware
  - ANSI color support
  - Fallback for invalid UTF-8

**Default Prompt Format:**
```
<user>@<host> <cwd> › 
```

**Integration:**
- Initialized in `Shell.init()` with default segments
- Rendered dynamically in main REPL loop
- Context updated per-command (cwd changes, exit codes, job count)

---

### 3. History Navigation ✅
Full command history with Up/Down arrow navigation.

**Implementation:**
- `Shell.history_buffer`: ArrayList storing all commands
- `Shell.history_index`: Tracks current position when browsing
- `readLineInteractiveWithHistory` method:
  - Up arrow: Navigate backward through history
  - Down arrow: Navigate forward through history
  - Saves current input when starting history browse
  - Restores saved input when reaching end of history
  - Resets on any character input (exit history mode)

**Features:**
- Automatic history recording after successful command execution
- Deduplication: Skips if identical to last entry
- Line redraw on history selection
- Proper cursor positioning

**Keyboard Bindings:**
- `↑` (Up) - Previous command
- `↓` (Down) - Next command
- Any char - Exit history mode, continue editing

---

## Bug Fixes

### 1. Zig 0.16 API Updates
- **waitpid return type**: Changed from `error union` to `WaitPidResult` struct
  - Removed `catch |err|` blocks
  - Direct access to `.pid` and `.status` fields
- **Atomic operations**: Updated to use `.seq_cst` ordering
- **File stream cleanup**: Removed manual close calls (stdlib handles cleanup in `wait()`)

### 2. Double-Close Bug in Executor
- **Issue**: Manually closing stdin/stdout streams before `proc.wait()` caused unreachable panic
- **Fix**: Let `Child.wait()` handle stream cleanup automatically
- **Impact**: All external command execution now stable

### 3. Prompt Engine Keyword Conflict
- **Issue**: `align` field name conflicted with Zig reserved keyword
- **Fix**: Renamed to `alignment` throughout `prompt.zig`

---

## Code Organization

### New Files
- **`src/prompt.zig`** (155 lines):
  - `SegmentAlign` enum (Left, Right)
  - `PromptSegment`, `PromptContext`, `PromptEngine` structs
  - `render()` and `expandVariables()` methods

### Modified Files
- **`src/shell.zig`**:
  - Added `prompt_engine`, `history_buffer`, `history_index` fields
  - New `readLineInteractiveWithHistory` method (220+ lines)
  - Integrated prompt rendering in `runInteractive` loop
  - History recording after command execution
  
- **`src/state.zig`**:
  - `Job` struct and `JobStatus` enum
  - Job management methods
  
- **`src/parser.zig`**:
  - Added `ampersand` token type
  - `Pipeline.background` field
  - Background job parsing logic
  
- **`src/executor.zig`**:
  - `runPipelineBackground` function
  - `ExecOutcome.job_id` field
  - Fixed stream cleanup in `runExternal`
  
- **`src/builtins.zig`**:
  - Added `jobs`, `fg`, `bg` built-ins

- **`build.zig.zon`**:
  - Restored all dependency declarations after corruption

---

## Testing

### Manual Testing Completed
✅ Basic command execution
✅ Background jobs with `&`
✅ Job listing with `jobs`
✅ Foreground job with `fg`
✅ Background job continuation with `bg`
✅ Prompt rendering with dynamic context
✅ History navigation (Up/Down arrows)
✅ Multi-command execution without crashes
✅ External command execution (`ls /tmp`, `echo`, etc.)

### Known Gaps
- ⚠️ No automated tests for new features yet
- ⚠️ Incremental search (Ctrl+R) not implemented
- ⚠️ Tab completion not implemented
- ⚠️ Async prompt segments not yet supported

---

## Metrics

- **Lines of Code Added**: ~800+
- **Features Completed**: 3 major (Job Control, Prompt Engine, History)
- **Build Status**: ✅ Passing on Zig 0.16.0-dev.164+bc7955306
- **Bugs Fixed**: 3 (waitpid API, double-close, keyword conflict)

---

## Next Steps (Remaining Alpha Tasks)

1. **Incremental Search** (Ctrl+R):
   - Reverse history search UI
   - Search highlighting
   - Match navigation

2. **Tab Completion**:
   - Command completion (PATH search)
   - Argument completion (file/directory)
   - Completion menu UI

3. **Aliases & Functions**:
   - Parser support for alias definitions
   - Function definition syntax
   - Alias/function execution

4. **Scripting Constructs**:
   - If/else conditionals
   - For/while loops
   - Function definitions

5. **Testing**:
   - Unit tests for job control
   - Integration tests for history
   - Prompt rendering tests

---

## Dependencies Updated

All dependencies restored and verified:
- zsync (async runtime)
- flash (CLI framework)
- flare (configuration)
- gcode (Unicode/grapheme handling)
- zigzag (event loop)
- zlog (logging)
- zqlite (persistence)
- ghostlang (scripting engine)
- phantom (TUI - fixed hash)

---

## Performance Notes

- History navigation: O(1) access by index
- Job tracking: Linear scan for PID lookups (acceptable for typical job counts)
- Prompt rendering: Fixed-cost per segment, no async overhead yet
- Memory: History unbounded (should add limit in future)

---

## Developer Notes

### Building
```bash
zig build
```

### Running
```bash
./zig-out/bin/gshell
```

### Testing Interactive Features
```bash
# Test job control
sleep 30 &
jobs
fg 1

# Test history
echo "first"
echo "second"
<Up arrow>  # Shows "echo second"
<Up arrow>  # Shows "echo first"
```

---

**End of Alpha Changelog**
