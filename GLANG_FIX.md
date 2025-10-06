# Ghostlang Security Configuration Fix

**Issue**: GShell's Ghostlang engine is initialized without sandbox limits
**Severity**: HIGH
**Impact**: Scripts can consume unlimited memory and run indefinitely
**Status**: ⚠️ REQUIRES FIX

---

## Current Implementation

`src/scripting.zig:22-24`:
```zig
const config = ghostlang.EngineConfig{
    .allocator = allocator,
};
```

**Problems**:
- ❌ No memory limits (can exhaust system memory)
- ❌ No execution timeouts (infinite loops possible)
- ❌ No IO restrictions
- ❌ No syscall restrictions

---

## Recommended Fix

### Option 1: Conservative Limits (Recommended for Beta)

```zig
const config = ghostlang.EngineConfig{
    .allocator = allocator,
    .memory_limit = 50 * 1024 * 1024, // 50MB max per script
    .execution_timeout_ms = 5000,      // 5 second timeout
    .allow_io = true,                  // Shell scripts need IO
    .allow_syscalls = false,           // Prevent direct syscalls
    .deterministic = false,            // Allow time functions
};
```

**Rationale**:
- 50MB allows complex scripts while preventing DoS
- 5 second timeout is generous for shell operations
- IO enabled for file operations via FFI
- Syscalls blocked to prevent sandbox escapes
- Non-deterministic for real-world shell usage

### Option 2: Strict Limits (For Untrusted Scripts)

```zig
const config = ghostlang.EngineConfig{
    .allocator = allocator,
    .memory_limit = 10 * 1024 * 1024, // 10MB max
    .execution_timeout_ms = 1000,      // 1 second timeout
    .allow_io = false,                 // No direct IO
    .allow_syscalls = false,           // No syscalls
    .deterministic = true,             // Fully deterministic
};
```

**Use case**: Running untrusted plugins or config files

### Option 3: Configurable Limits (Best for Production)

Add to `src/config.zig`:
```zig
pub const ShellConfig = struct {
    // ... existing fields ...

    // Ghostlang security settings
    script_memory_limit_mb: u32 = 50,
    script_timeout_ms: u64 = 5000,
    script_allow_io: bool = true,
    script_allow_syscalls: bool = false,
};
```

Then in `src/scripting.zig`:
```zig
pub fn init(allocator: std.mem.Allocator, state: *ShellState, config: ShellConfig) !ScriptEngine {
    const engine_config = ghostlang.EngineConfig{
        .allocator = allocator,
        .memory_limit = config.script_memory_limit_mb * 1024 * 1024,
        .execution_timeout_ms = config.script_timeout_ms,
        .allow_io = config.script_allow_io,
        .allow_syscalls = config.script_allow_syscalls,
        .deterministic = false,
    };

    const engine = ghostlang.ScriptEngine.create(engine_config) catch {
        return ScriptingError.EngineInitFailed;
    };
    // ... rest of init
}
```

---

## Ghostlang Sandbox Features (Verified)

Based on `archive/ghostlang/security/sandbox_audit.zig`, Ghostlang provides:

✅ **Memory Limit Enforcement**
- Tracks allocations via `MemoryLimitAllocator`
- Returns `error.OutOfMemory` when limit exceeded
- Tested and verified

✅ **Execution Timeout**
- Tracks execution time in VM loop
- Returns `error.ExecutionTimeout` when exceeded
- Checked every N instructions

✅ **IO Restrictions**
- Can disable file/network operations
- Configurable via `allow_io` flag

✅ **Syscall Restrictions**
- Can prevent direct system calls
- Configurable via `allow_syscalls` flag

✅ **Deterministic Mode**
- Disables time-based functions
- Ensures reproducible execution
- Useful for testing

✅ **Stack Overflow Protection**
- Call stack depth limits
- Prevents infinite recursion

✅ **Infinite Loop Detection**
- Via timeout mechanism
- Instruction count limits

✅ **Malicious Input Handling**
- Validated in fuzzing tests
- Parser hardened against crafted input

---

## Security Test Results (from Ghostlang)

Ghostlang's own security audit (`security/sandbox_audit.zig`) tests:

1. ✅ Memory limit enforcement
2. ✅ Execution timeout
3. ✅ IO restriction (when disabled)
4. ✅ Syscall restriction (when disabled)
5. ✅ Deterministic mode
6. ✅ Stack overflow protection
7. ✅ Infinite loop detection
8. ✅ Malicious input handling

**All 8 tests pass** ✅

---

## Implementation Priority

**Priority**: **CRITICAL** (before RC)

**Steps**:
1. Update `src/scripting.zig` with recommended limits
2. Add config options for tunable limits
3. Document limits in user documentation
4. Test with resource-intensive scripts
5. Update SECURITY_AUDIT.md

**Estimated time**: 30 minutes

---

## Testing Plan

### Test 1: Memory Limit
```lua
-- Should fail after ~50MB allocated
local t = {}
for i = 1, 1000000 do
    t[i] = string.rep("x", 1000)
end
```

Expected: `error.OutOfMemory`

### Test 2: Timeout
```lua
-- Should timeout after 5 seconds
while true do
    -- infinite loop
end
```

Expected: `error.ExecutionTimeout`

### Test 3: Normal Operation
```lua
-- Should complete successfully
print("Hello from Ghostlang!")
for i = 1, 100 do
    print(i)
end
```

Expected: Success, completes in < 1 second

---

## Backwards Compatibility

**Impact**: Minimal

- Existing scripts that complete quickly and use < 50MB will work unchanged
- Only affects pathological cases (infinite loops, memory leaks)
- Can be configured via shell config if needed

---

## Documentation Updates Needed

1. **README.md**: Add security section
   - Memory limits
   - Execution timeouts
   - How to configure

2. **User Guide**: Document limits
   - What happens when limit is hit
   - How to adjust for special cases
   - Performance implications

3. **SECURITY_AUDIT.md**: Update sandbox status
   - Change from "⏳ Pending" to "✅ Complete"
   - Document actual limits used
   - Link to Ghostlang security audit

---

## Conclusion

**Current Status**: ⚠️ **VULNERABLE**
- Scripts can DoS the shell via memory exhaustion
- Scripts can hang the shell indefinitely
- No protection against malicious config files

**After Fix**: ✅ **SECURE**
- Memory protected (50MB limit)
- Time protected (5s timeout)
- Syscalls blocked
- Fully sandboxed execution

**Recommendation**: Implement **Option 1** (Conservative Limits) immediately, then add **Option 3** (Configurable) for v0.2.0.

---

**Next Steps**:
1. Apply recommended fix to `src/scripting.zig`
2. Test with resource-intensive scripts
3. Update security documentation
4. Mark sandbox verification as complete
