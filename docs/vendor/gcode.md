# gcode Library

**Unicode and emoji support for Zig terminals**

[gcode](https://github.com/GhostKellz/gcode) is a Zig library providing Unicode/emoji handling and terminal semantics. It powers GShell's string processing and terminal output.

## Overview

gcode provides:
- **Unicode grapheme cluster handling** - Proper character boundaries
- **Emoji support** - Full emoji rendering (including ZWJ sequences)
- **String width calculation** - Account for double-width characters
- **Terminal-aware truncation** - Smart string truncation for display
- **UTF-8 validation** - Ensure valid Unicode strings

## Integration in GShell

gcode is integrated as a Zig dependency in `build.zig.zon`:

```zig
.dependencies = .{
    .gcode = .{
        .url = "https://github.com/GhostKellz/gcode/archive/<commit>.tar.gz",
        .hash = "<hash>",
    },
},
```

## Usage in GShell Core

### Importing gcode

```zig
const gcode = @import("gcode");
```

### String Width Calculation

gcode properly calculates display width accounting for:
- Single-width characters (a, b, 1, 2) - 1 cell
- Double-width characters (中, 日, 한, 글) - 2 cells
- Zero-width characters (combining marks) - 0 cells
- Emoji (🚀, 👨‍👩‍👧‍👦) - 2 cells

```zig
const width = try gcode.displayWidth("Hello 世界");
// width = 9 (5 ASCII + 2×2 CJK)

const emoji_width = try gcode.displayWidth("🚀 GShell");
// emoji_width = 9 (2 emoji + 1 space + 6 ASCII)
```

### Terminal Truncation

Truncate strings to fit terminal width without breaking characters:

```zig
const original = "~/very/long/path/to/project/directory";
const truncated = try gcode.truncate(allocator, original, 20);
defer allocator.free(truncated);
// truncated = "~/…/project/directory" (fits in 20 chars)
```

### Grapheme Cluster Iteration

Iterate over user-perceived characters (graphemes):

```zig
var iter = gcode.GraphemeIterator.init("Hello 👨‍👩‍👧‍👦!");

while (iter.next()) |grapheme| {
    std.debug.print("Grapheme: {s}\n", .{grapheme});
}
// Output:
// H
// e
// l
// l
// o
//
// 👨‍👩‍👧‍👦 (entire family emoji as one grapheme)
// !
```

### UTF-8 Validation

```zig
if (gcode.isValidUtf8("Hello World")) {
    std.debug.print("Valid UTF-8\n", .{});
}

if (!gcode.isValidUtf8("\xFF\xFE")) {
    std.debug.print("Invalid UTF-8\n", .{});
}
```

## GShell Integration Points

### 1. Prompt Rendering

**File:** `src/prompt.zig`

Uses gcode to truncate directory paths:

```zig
const gcode = @import("gcode");

fn truncatePath(allocator: std.mem.Allocator, path: []const u8, max_width: usize) ![]const u8 {
    const current_width = try gcode.displayWidth(path);

    if (current_width <= max_width) {
        return try allocator.dupe(u8, path);
    }

    // Truncate intelligently
    return try gcode.truncate(allocator, path, max_width);
}
```

### 2. String Display

**File:** `src/repl.zig`

Uses gcode to calculate cursor position accounting for double-width characters:

```zig
const gcode = @import("gcode");

fn getCursorPosition(line: []const u8, byte_offset: usize) !usize {
    const prefix = line[0..byte_offset];
    return try gcode.displayWidth(prefix);
}
```

### 3. History Display

**File:** `src/history.zig`

Uses gcode to truncate history entries for display:

```zig
const gcode = @import("gcode");

fn formatHistoryEntry(allocator: std.mem.Allocator, entry: []const u8, max_width: usize) ![]const u8 {
    if (try gcode.displayWidth(entry) <= max_width) {
        return try allocator.dupe(u8, entry);
    }

    return try gcode.truncate(allocator, entry, max_width);
}
```

## API Reference

### Core Functions

#### `displayWidth(str: []const u8) !usize`
Calculates display width of a UTF-8 string.

```zig
const width = try gcode.displayWidth("Hello 世界 🚀");
// width = 11 (5 ASCII + 2×2 CJK + 1 space + 2 emoji)
```

**Parameters:**
- `str` - UTF-8 encoded string

**Returns:** Display width in terminal cells

**Errors:** `error.InvalidUtf8`

---

#### `truncate(allocator: Allocator, str: []const u8, max_width: usize) ![]const u8`
Truncates string to fit within max display width.

```zig
const allocator = std.heap.page_allocator;
const truncated = try gcode.truncate(allocator, "Very long string", 10);
defer allocator.free(truncated);
// truncated = "Very lo..."
```

**Parameters:**
- `allocator` - Memory allocator
- `str` - UTF-8 encoded string
- `max_width` - Maximum display width

**Returns:** Allocated truncated string

**Errors:** `error.OutOfMemory`, `error.InvalidUtf8`

---

#### `isValidUtf8(str: []const u8) bool`
Validates UTF-8 encoding.

```zig
if (gcode.isValidUtf8("Hello 世界")) {
    std.debug.print("Valid\n", .{});
}
```

**Parameters:**
- `str` - Byte string to validate

**Returns:** `true` if valid UTF-8, `false` otherwise

---

### Types

#### `GraphemeIterator`
Iterates over grapheme clusters.

```zig
pub const GraphemeIterator = struct {
    pub fn init(str: []const u8) GraphemeIterator;
    pub fn next(self: *GraphemeIterator) ?[]const u8;
};
```

**Example:**
```zig
var iter = gcode.GraphemeIterator.init("Hello 👍");
while (iter.next()) |grapheme| {
    std.debug.print("{s}\n", .{grapheme});
}
```

---

#### `CodepointIterator`
Iterates over Unicode codepoints.

```zig
pub const CodepointIterator = struct {
    pub fn init(str: []const u8) CodepointIterator;
    pub fn next(self: *CodepointIterator) ?u32;
};
```

**Example:**
```zig
var iter = gcode.CodepointIterator.init("Hello");
while (iter.next()) |codepoint| {
    std.debug.print("U+{X:0>4}\n", .{codepoint});
}
// U+0048 (H)
// U+0065 (e)
// U+006C (l)
// U+006C (l)
// U+006F (o)
```

---

## Character Width Rules

gcode follows Unicode Standard Annex #11 (East Asian Width) and Unicode Standard Annex #29 (Grapheme Clusters).

### Width Categories

| Category            | Width | Examples                  |
|---------------------|-------|---------------------------|
| ASCII               | 1     | `a`, `1`, `!`             |
| Latin-1 Supplement  | 1     | `é`, `ñ`, `ü`             |
| CJK Characters      | 2     | `中`, `日`, `한`, `글`    |
| Emoji               | 2     | `🚀`, `😀`, `👍`          |
| Emoji ZWJ Sequences | 2     | `👨‍👩‍👧‍👦` (family)        |
| Combining Marks     | 0     | `◌́` (combining acute)    |
| Zero-Width Joiner   | 0     | U+200D (ZWJ)              |

### Examples

```zig
// ASCII - 1 cell each
try std.testing.expectEqual(5, try gcode.displayWidth("Hello"));

// CJK - 2 cells each
try std.testing.expectEqual(4, try gcode.displayWidth("日本"));

// Emoji - 2 cells
try std.testing.expectEqual(2, try gcode.displayWidth("🚀"));

// Emoji ZWJ sequence - 2 cells (treated as one grapheme)
try std.testing.expectEqual(2, try gcode.displayWidth("👨‍👩‍👧‍👦"));

// Mixed
try std.testing.expectEqual(11, try gcode.displayWidth("Hello 世界 🚀"));
//                                5    + 1 + 4  + 1 + 2 = 11
```

## Truncation Strategies

gcode provides intelligent truncation:

### 1. End Truncation (Default)
```zig
const result = try gcode.truncate(allocator, "This is a very long string", 15);
// result = "This is a ve..."
```

### 2. Middle Truncation
```zig
const result = try gcode.truncateMiddle(allocator, "~/projects/gshell/src/main.zig", 25);
// result = "~/projects/…/src/main.zig"
```

### 3. Smart Path Truncation
```zig
const result = try gcode.truncatePath(allocator, "/home/user/projects/gshell/src/prompts/ghostkellz.zig", 30);
// result = "/home/…/prompts/ghostkellz.zig"
```

## Unicode Normalization

gcode handles different Unicode normalization forms:

```zig
// NFD (decomposed): é = e + ◌́
const nfd = "e\u{0301}";

// NFC (composed): é
const nfc = "é";

// Both display as é
try std.testing.expectEqual(1, try gcode.displayWidth(nfd));
try std.testing.expectEqual(1, try gcode.displayWidth(nfc));
```

## Emoji Handling

### Basic Emoji
```zig
const emoji = "🚀";
try std.testing.expectEqual(2, try gcode.displayWidth(emoji));
```

### Emoji with Skin Tone
```zig
const emoji = "👋🏽";  // Waving hand + medium skin tone
try std.testing.expectEqual(2, try gcode.displayWidth(emoji));
```

### Emoji ZWJ Sequences
```zig
const family = "👨‍👩‍👧‍👦";  // Family (man + ZWJ + woman + ZWJ + girl + ZWJ + boy)
try std.testing.expectEqual(2, try gcode.displayWidth(family));
```

### Flag Emoji
```zig
const flag = "🇺🇸";  // US flag (Regional Indicator U + Regional Indicator S)
try std.testing.expectEqual(2, try gcode.displayWidth(flag));
```

## Building with gcode

gcode is automatically built as part of GShell's build process:

```bash
# Build GShell (includes gcode)
zig build

# Build with optimizations
zig build -Doptimize=ReleaseFast
```

## Testing gcode Integration

```bash
# Test Unicode handling in GShell
gshell -c 'print("Hello 世界 🚀")'

# Test path truncation in prompt
gshell
# (observe directory truncation in GPPrompt)
```

## Performance Considerations

1. **Caching** - Calculate width once, cache result if used multiple times
2. **Iterator Reuse** - Reuse iterators when possible
3. **Allocation** - Truncate functions allocate; free when done
4. **Validation** - Validate UTF-8 early to avoid errors later

## Common Patterns

### Pattern 1: Safe Width Calculation

```zig
fn getWidth(str: []const u8) usize {
    return gcode.displayWidth(str) catch {
        // Fallback to byte length on error
        return str.len;
    };
}
```

### Pattern 2: Truncate with Ellipsis

```zig
fn truncateWithEllipsis(allocator: std.mem.Allocator, str: []const u8, max_width: usize) ![]const u8 {
    const current_width = try gcode.displayWidth(str);

    if (current_width <= max_width) {
        return try allocator.dupe(u8, str);
    }

    const ellipsis = "…";
    const available_width = max_width - 1;

    var buf = std.ArrayList(u8).init(allocator);
    var iter = gcode.GraphemeIterator.init(str);
    var width: usize = 0;

    while (iter.next()) |grapheme| {
        const grapheme_width = try gcode.displayWidth(grapheme);
        if (width + grapheme_width > available_width) break;
        try buf.appendSlice(grapheme);
        width += grapheme_width;
    }

    try buf.appendSlice(ellipsis);
    return buf.toOwnedSlice();
}
```

### Pattern 3: Count Graphemes

```zig
fn countGraphemes(str: []const u8) usize {
    var count: usize = 0;
    var iter = gcode.GraphemeIterator.init(str);
    while (iter.next()) |_| {
        count += 1;
    }
    return count;
}
```

## Troubleshooting

### Emoji appearing broken

**Problem:** Emoji display as multiple characters or boxes

**Solution:** Ensure terminal supports emoji:

```bash
# Test emoji support
echo "🚀 🌍 👨‍👩‍👧‍👦"

# If broken, update terminal or use a modern terminal:
# - Alacritty
# - Kitty
# - WezTerm
# - iTerm2 (macOS)
# - Windows Terminal (Windows)
```

### Width calculation incorrect

**Problem:** Cursor position misaligned

**Solution:** Check terminal's character width rendering:

```zig
const width = try gcode.displayWidth("世界");
std.debug.print("Width: {d} (expected: 4)\n", .{width});
```

If mismatch, terminal may not follow Unicode width standards.

### Invalid UTF-8 errors

**Problem:** `error.InvalidUtf8` thrown

**Solution:** Validate input before processing:

```zig
if (!gcode.isValidUtf8(input)) {
    std.debug.print("Invalid UTF-8 detected\n", .{});
    return error.InvalidUtf8;
}

const width = try gcode.displayWidth(input);
```

## Contributing to gcode

gcode is a separate project. To contribute:

1. Fork [GhostKellz/gcode](https://github.com/GhostKellz/gcode)
2. Add new Unicode handling features
3. Include tests
4. Submit PR

## See Also

- [gcode GitHub Repository](https://github.com/GhostKellz/gcode)
- [GPPrompt Documentation](../gprompt/README.md)
- [Unicode Standard Annex #11 (East Asian Width)](https://www.unicode.org/reports/tr11/)
- [Unicode Standard Annex #29 (Grapheme Clusters)](https://www.unicode.org/reports/tr29/)
- [Emoji ZWJ Sequences](https://unicode.org/emoji/charts/emoji-zwj-sequences.html)
- [UTF-8 Everywhere Manifesto](https://utf8everywhere.org/)
