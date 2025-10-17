# Editor Integration

GShell provides seamless integration with text editors for quick file editing and command editing from history.

## Commands

### `e <file>` - Edit File

Opens a file in your preferred editor.

```bash
e config.txt
e ~/.gshrc.gza
```

**Editor Selection:**
1. First checks if `grim` is available (preferred)
2. Falls back to `$EDITOR` environment variable
3. Falls back to `vi` if neither is set

### `e -` - Edit Last Command

Edit the last command from your history in the editor.

```bash
# Run a complex command
ls -la | grep test | sort

# Oops, made a mistake - edit it
e -
```

The command opens in your editor. After you save and exit, the shell displays the edited command for you to execute manually.

### `fc <N>` - Edit Command from History

Edit a specific command from history by its number.

```bash
# View history
history

# Edit command #42
fc 42
```

## Examples

### Quick File Edit
```bash
# Edit your shell config
e ~/.gshrc.gza

# Edit a project file
e src/main.zig
```

### Fix a Typo in History
```bash
# Run a command with a typo
git comit -m "fixed bug"

# Edit and fix it
e -
# Changes "comit" to "commit" in editor
# Save and exit, then run the corrected command
```

### Repeat and Modify a Previous Command
```bash
# You ran this earlier:
# 142: docker build -t myapp:v1.0 .

# Edit and change the version
fc 142
# Change v1.0 to v1.1 in editor
# Save and run the new command
```

## Configuration

Set your preferred editor:

```bash
export EDITOR=grim
# or
export EDITOR=vim
# or
export EDITOR=nano
```

Add to your `~/.gshrc.gza`:

```lua
setenv("EDITOR", "grim")
```

## Notes

- Commands are edited in a temporary file `/tmp/gsh_edit.sh`
- The editor must exit successfully for the edit to be accepted
- Currently, edited commands are displayed but not auto-executed (for safety)
- History integration requires interactive mode
