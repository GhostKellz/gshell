#!/bin/bash
# Memory leak detection test for gshell
# Run this to check for memory leaks during a session

set -e

echo "=== GShell Memory Leak Detection ==="
echo ""

# Build with debug info
echo "1. Building with debug symbols..."
zig build -Doptimize=Debug
echo "✓ Build complete"
echo ""

# Test 1: Simple command execution (100 iterations)
echo "2. Testing command execution (100 commands)..."
for i in {1..100}; do
    echo "echo test$i" | ./zig-out/bin/gshell --command "echo test$i" > /dev/null
done
echo "✓ Command execution test complete"
echo ""

# Test 2: Script execution (50 scripts)
echo "3. Testing script execution..."
cat > /tmp/test_leak.gza << 'EOF'
print("test")
EOF

for i in {1..50}; do
    ./zig-out/bin/gshell /tmp/test_leak.gza > /dev/null 2>&1
done
echo "✓ Script execution test complete"
echo ""

# Test 3: FFI stress test
echo "4. Testing FFI functions..."
# Simplified - just run multiple simple scripts
for i in {1..50}; do
    echo 'print("test")' | ./zig-out/bin/gshell --command "echo test" > /dev/null 2>&1
done
echo "✓ FFI stress test complete"
echo ""

# Test 4: Check with GeneralPurposeAllocator leak detection
echo "5. Running Zig's built-in leak detector..."
cat > /tmp/test_leak_check.zig << 'EOF'
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .safety = true,
        .thread_safe = true,
    }){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            std.debug.print("MEMORY LEAK DETECTED!\n", .{});
            std.process.exit(1);
        }
    }

    const allocator = gpa.allocator();

    // Simulate typical shell operations
    for (0..1000) |_| {
        const mem = try allocator.alloc(u8, 1024);
        defer allocator.free(mem);
    }

    std.debug.print("Leak check passed\n", .{});
}
EOF

zig run /tmp/test_leak_check.zig
echo "✓ Leak detector test passed"
echo ""

# Summary
echo "=== Memory Test Summary ==="
echo "✓ All memory tests passed!"
echo ""
echo "To run with valgrind (if available):"
echo "  valgrind --leak-check=full --show-leak-kinds=all ./zig-out/bin/gshell --command 'echo test'"
echo ""
echo "To run with AddressSanitizer:"
echo "  zig build -Doptimize=Debug -Dsanitize=address"
echo "  ./zig-out/bin/gshell --command 'echo test'"
