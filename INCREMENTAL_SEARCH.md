# Incremental Search (Ctrl+R) - Testing Guide

## Feature Overview
Reverse incremental search allows you to search through command history interactively.

## How to Use

### Enter Search Mode
1. Press **Ctrl+R**
2. You'll see: `(reverse-i-search)\`': `
3. Start typing your search query

### Search Behavior
- As you type, it finds the most recent matching command
- Matches are case-insensitive
- Substring matching (finds "echo" in "echo hello world")

### Navigation
- **Ctrl+R again** - Find previous match (search backwards)
- **Enter** - Accept current match and execute
- **Ctrl+C** - Cancel search, return to empty prompt
- **Backspace** - Remove character from search query

### Example Session

```bash
# Build up some history first
$ echo "hello world"
hello world

$ echo "goodbye"
goodbye

$ ls /tmp
[files listed]

$ echo "hello again"
hello again

# Now test search:
# Press Ctrl+R
(reverse-i-search)`': 

# Type 'ec'
(reverse-i-search)`ec': echo "hello again"

# Press Ctrl+R again to find previous
(reverse-i-search)`ec': echo "goodbye"

# Press Ctrl+R again
(reverse-i-search)`ec': echo "hello world"

# Press Enter to accept
$ echo "hello world"
hello world
```

## Visual Indicators

### Successful Match
```
(reverse-i-search)`test': echo "test command"
```

### Failed Search
```
(failed reverse-i-search)`xyz': 
```

## Keyboard Reference

| Key | Action |
|-----|--------|
| `Ctrl+R` | Enter search mode / Find previous match |
| `Ctrl+C` | Cancel search |
| `Enter` | Accept match |
| `Backspace` | Delete search character |
| `A-Z, 0-9` | Add to search query |

## Implementation Details

### Search Algorithm
- Reverse chronological search (most recent first)
- Case-insensitive substring matching
- Starts from end of history

### State Management
- Search mode flag
- Search query buffer
- Current match index
- Preserved original input

### Rendering
- Clears current line with `\r\x1b[K`
- Shows search prompt with query and match
- Updates on every keystroke

## Testing Checklist

- [ ] Enter search mode with Ctrl+R
- [ ] Type query and see matches
- [ ] Navigate with repeated Ctrl+R
- [ ] Accept match with Enter
- [ ] Cancel with Ctrl+C
- [ ] Backspace removes characters
- [ ] Case-insensitive matching works
- [ ] Empty query shows latest command
- [ ] Failed search shows "(failed)" indicator

## Known Limitations

1. **Single direction**: Only searches backwards (not forward yet)
2. **No regex**: Simple substring matching only
3. **No fuzzy matching**: Exact substring required
4. **Linear search**: Not optimized for huge histories (10k+ commands)

## Future Enhancements

- [ ] Forward search (Ctrl+S or keep pressing Ctrl+R to wrap)
- [ ] Regex support
- [ ] Fuzzy matching (like fzf)
- [ ] Search result highlighting
- [ ] Multi-line command support
- [ ] Search history persistence

## Comparison with Other Shells

### Bash
- ✅ Same keybinding (Ctrl+R)
- ✅ Similar prompt format
- ✅ Reverse search
- ❌ No forward search (we match bash)

### Zsh
- ✅ Compatible behavior
- ✅ Case-insensitive by default
- ❌ No fuzzy matching yet (zsh has this with plugins)

### Fish
- ❌ Fish uses different approach (auto-suggestions)
- ✅ We offer traditional search for Bash/Zsh users

## Integration with Other Features

### History Navigation
- Ctrl+R search is separate from Up/Down arrow history
- Both can be used interchangeably
- Search doesn't affect history position

### Job Control
- Search works with backgrounded commands
- Can find and re-run job control commands

### Aliases
- Searches expanded aliases (what was actually run)
- Not the alias name itself

## Demo Script

```bash
#!/bin/bash
# Run this to build up test history

echo "Building test history..."

echo "first test command"
ls -la /tmp
echo "second test command"
git status
echo "third test command"
cd /data
echo "fourth test command"
pwd

echo ""
echo "History built! Now try:"
echo "1. Press Ctrl+R"
echo "2. Type 'test' to find test commands"
echo "3. Press Ctrl+R again to cycle through matches"
echo "4. Press Enter to accept or Ctrl+C to cancel"
```

## Success Criteria

✅ **Implemented**:
- Ctrl+R enters search mode
- Typing updates search
- Repeated Ctrl+R finds previous matches
- Enter accepts match
- Ctrl+C cancels
- Backspace works
- Case-insensitive matching
- Visual feedback with search prompt

🎯 **Alpha Complete**: Incremental search is a critical daily-driver feature and is now fully functional!
