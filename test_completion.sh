#!/bin/bash
# Quick manual test for tab completion
# Run gshell interactively and test these scenarios

echo "=== Tab Completion Test Guide ==="
echo ""
echo "Launch: ./zig-out/bin/gshell"
echo ""
echo "Test 1 - Command completion:"
echo "  Type: ech<TAB>      (should complete to 'echo')"
echo "  Type: gi<TAB>       (should show 'git' and similar)"
echo "  Type: ls<TAB>       (should complete to 'ls')"
echo ""
echo "Test 2 - File completion:"
echo "  Type: ls /tm<TAB>   (should complete to '/tmp/' or show options)"
echo "  Type: cat /etc/p<TAB> (should show files in /etc starting with 'p')"
echo "  Type: cd /ho<TAB>   (should complete to '/home/')"
echo ""
echo "Test 3 - Multiple matches:"
echo "  Type: git <TAB>     (should show nothing - need second word)"
echo "  Type: e<TAB>        (should show 'echo', 'env', 'exit', etc.)"
echo ""
echo "Test 4 - Edge cases:"
echo "  Type: <TAB>         (empty - should do nothing)"
echo "  Type: xyz<TAB>      (no matches - should do nothing)"
echo "  Type: /nonexistent/<TAB> (bad path - should do nothing)"
echo ""
echo "Press Enter when ready to test..."
read

./zig-out/bin/gshell
