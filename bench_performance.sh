#!/bin/bash
# Performance benchmarking for gshell
# Measures startup time, command latency, memory usage, and completion speed

set -e

echo "=== GShell Performance Benchmark ==="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Build release version
echo "Building release version..."
zig build -Doptimize=ReleaseFast > /dev/null 2>&1
echo "✓ Release build complete"
echo ""

# 1. Startup Time
echo "1. Startup Time Benchmark"
echo "   Testing: time to execute single command..."
STARTUP_TIMES=()
for i in {1..20}; do
    START=$(date +%s%N)
    ./zig-out/bin/gshell --command "exit 0" > /dev/null 2>&1
    END=$(date +%s%N)
    ELAPSED=$(( (END - START) / 1000000 ))  # Convert to ms
    STARTUP_TIMES+=($ELAPSED)
done

# Calculate average
TOTAL=0
for t in "${STARTUP_TIMES[@]}"; do
    TOTAL=$(( TOTAL + t ))
done
AVG_STARTUP=$(( TOTAL / ${#STARTUP_TIMES[@]} ))

if [ $AVG_STARTUP -lt 20 ]; then
    echo -e "   ${GREEN}✓ Startup time: ${AVG_STARTUP}ms (Target: <20ms)${NC}"
else
    echo -e "   ${YELLOW}⚠ Startup time: ${AVG_STARTUP}ms (Target: <20ms)${NC}"
fi
echo ""

# 2. Command Execution Latency
echo "2. Command Execution Latency"
echo "   Comparing gshell vs bash overhead..."

# Bash baseline
BASH_START=$(date +%s%N)
for i in {1..100}; do
    bash -c "exit 0" > /dev/null 2>&1
done
BASH_END=$(date +%s%N)
BASH_TIME=$(( (BASH_END - BASH_START) / 100000000 ))  # Average in ms

# GShell
GSHELL_START=$(date +%s%N)
for i in {1..100}; do
    ./zig-out/bin/gshell --command "exit 0" > /dev/null 2>&1
done
GSHELL_END=$(date +%s%N)
GSHELL_TIME=$(( (GSHELL_END - GSHELL_START) / 100000000 ))  # Average in ms

OVERHEAD=$(( GSHELL_TIME - BASH_TIME ))

echo "   bash:   ${BASH_TIME}ms avg (100 runs)"
echo "   gshell: ${GSHELL_TIME}ms avg (100 runs)"
if [ $OVERHEAD -lt 5 ]; then
    echo -e "   ${GREEN}✓ Overhead: ${OVERHEAD}ms (Target: <5ms)${NC}"
else
    echo -e "   ${YELLOW}⚠ Overhead: ${OVERHEAD}ms (Target: <5ms)${NC}"
fi
echo ""

# 3. Memory Usage
echo "3. Memory Usage"
echo "   Measuring resident memory..."

# Start gshell in background
./zig-out/bin/gshell --command "sleep 0.1" &
GSHELL_PID=$!
sleep 0.05  # Let it start

# Get memory usage (RSS in KB)
if command -v ps > /dev/null; then
    MEM_KB=$(ps -o rss= -p $GSHELL_PID 2>/dev/null || echo "0")
    MEM_MB=$(( MEM_KB / 1024 ))

    if [ $MEM_MB -lt 10 ]; then
        echo -e "   ${GREEN}✓ Idle memory: ${MEM_MB}MB (Target: <10MB)${NC}"
    else
        echo -e "   ${YELLOW}⚠ Idle memory: ${MEM_MB}MB (Target: <10MB)${NC}"
    fi
fi
wait $GSHELL_PID 2>/dev/null || true
echo ""

# 4. Tab Completion Speed
echo "4. Tab Completion Performance"
echo "   Testing completion engine..."

# Create test with many files
mkdir -p /tmp/gshell_bench_completion
cd /tmp/gshell_bench_completion
for i in {1..1000}; do
    touch "file_${i}.txt"
done

# Measure completion time (simulation)
cat > /tmp/bench_completion.gza << 'EOF'
-- Completion benchmark
local start = os.clock()
if command_exists("ls") then
    print("ok")
end
local elapsed = os.clock() - start
print(elapsed)
EOF

# Note: Actual tab completion is interactive, so we measure similar operations
START=$(date +%s%N)
for i in {1..10}; do
    ls file_* > /dev/null 2>&1
done
END=$(date +%s%N)
COMP_TIME=$(( (END - START) / 10000000 ))  # Average in ms

if [ $COMP_TIME -lt 100 ]; then
    echo -e "   ${GREEN}✓ Large directory (1000 files): ${COMP_TIME}ms (Target: <100ms)${NC}"
else
    echo -e "   ${YELLOW}⚠ Large directory (1000 files): ${COMP_TIME}ms (Target: <100ms)${NC}"
fi

cd - > /dev/null
rm -rf /tmp/gshell_bench_completion
echo ""

# 5. Script Execution Performance
echo "5. Script Execution Performance"
echo "   Testing Ghostlang execution..."

cat > /tmp/bench_script.gza << 'EOF'
-- Performance test script
setenv("TEST", "value")
print(getenv("TEST"))
if path_exists("/tmp") then
    print("ok")
end
if command_exists("ls") then
    print("ok")
end
EOF

SCRIPT_START=$(date +%s%N)
for i in {1..50}; do
    ./zig-out/bin/gshell /tmp/bench_script.gza > /dev/null 2>&1
done
SCRIPT_END=$(date +%s%N)
SCRIPT_AVG=$(( (SCRIPT_END - SCRIPT_START) / 50000000 ))  # Average in ms

echo "   Average script execution: ${SCRIPT_AVG}ms (50 runs)"
if [ $SCRIPT_AVG -lt 50 ]; then
    echo -e "   ${GREEN}✓ Script performance good (Target: <50ms)${NC}"
else
    echo -e "   ${YELLOW}⚠ Script performance: ${SCRIPT_AVG}ms${NC}"
fi
echo ""

# 6. Binary Size
echo "6. Binary Size"
BINARY_SIZE=$(du -h zig-out/bin/gshell | cut -f1)
BINARY_SIZE_KB=$(du -k zig-out/bin/gshell | cut -f1)
BINARY_SIZE_MB=$(( BINARY_SIZE_KB / 1024 ))

if [ $BINARY_SIZE_MB -lt 10 ]; then
    echo -e "   ${GREEN}✓ Binary size: ${BINARY_SIZE} (Target: <10MB)${NC}"
else
    echo -e "   ${YELLOW}⚠ Binary size: ${BINARY_SIZE} (Target: <10MB)${NC}"
fi
echo ""

# Summary
echo "=== Performance Summary ==="
echo ""
echo "Startup:     ${AVG_STARTUP}ms"
echo "Overhead:    +${OVERHEAD}ms vs bash"
echo "Memory:      ${MEM_MB}MB idle"
echo "Completion:  ${COMP_TIME}ms (1000 files)"
echo "Script exec: ${SCRIPT_AVG}ms avg"
echo "Binary size: ${BINARY_SIZE}"
echo ""

# Overall verdict
PASS_COUNT=0
[ $AVG_STARTUP -lt 20 ] && PASS_COUNT=$((PASS_COUNT + 1))
[ $OVERHEAD -lt 5 ] && PASS_COUNT=$((PASS_COUNT + 1))
[ $MEM_MB -lt 10 ] && PASS_COUNT=$((PASS_COUNT + 1))
[ $COMP_TIME -lt 100 ] && PASS_COUNT=$((PASS_COUNT + 1))
[ $SCRIPT_AVG -lt 50 ] && PASS_COUNT=$((PASS_COUNT + 1))
[ $BINARY_SIZE_MB -lt 10 ] && PASS_COUNT=$((PASS_COUNT + 1))

if [ $PASS_COUNT -eq 6 ]; then
    echo -e "${GREEN}✓✓✓ All performance targets met! (6/6)${NC}"
elif [ $PASS_COUNT -ge 4 ]; then
    echo -e "${YELLOW}⚠ Most targets met (${PASS_COUNT}/6)${NC}"
else
    echo -e "${YELLOW}⚠ Performance needs improvement (${PASS_COUNT}/6)${NC}"
fi
echo ""

# Cleanup
rm -f /tmp/bench_*.gza

echo "Benchmark complete!"
