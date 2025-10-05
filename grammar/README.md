# Tree-sitter Grammar for GShell

Tree-sitter syntax grammar for GShell scripting language, compatible with [grove](https://github.com/ghostkellz/grove).

## Overview

This grammar provides syntax highlighting and parsing for:
- **GShell script files**: `.gsh`, `.gshell`
- **Shell commands**: Bash-compatible syntax
- **GShell built-ins**: `net-test`, `net-resolve`, `net-fetch`, `net-scan`
- **FFI functions**: `use_starship`, `enable_plugin`, `load_vivid_theme`, etc.

## File Extensions

- `.gsh` - GShell scripts
- `.gshell` - GShell scripts
- `.gshrc` - Use Ghostlang grammar instead (config files use Ghostlang)

## Syntax Features

### Supported Constructs

```bash
# Comments
echo "Hello, world"          # Strings
ls -la /home                 # Flags and paths
export VAR=value             # Variable assignments
echo $VAR ${VAR}             # Variable expansion
ls | grep test               # Pipelines
cat file.txt > output.txt    # Redirection
command1 && command2         # Logical operators
result=$(command)            # Command substitution
```

### GShell-Specific Commands

```bash
# Networking built-ins
net-test google.com 443
net-resolve example.com
net-fetch https://api.github.com
net-scan 192.168.1.0/24

# FFI functions (when used in scripts)
use_starship true
enable_plugin "git" "network"
load_vivid_theme "ghost-hacker-blue"
```

## Integration with grove

### Option 1: Git Submodule (Recommended)

In the `grove` repository:

```bash
cd vendor/grammars
git submodule add https://github.com/ghostkellz/gshell gshell
git submodule update --init --recursive
```

Then register in grove's language list:

```zig
// In grove/src/languages.zig or similar
pub const gshell = struct {
    pub fn get() !Language {
        const parser_c = @embedFile("../vendor/grammars/gshell/grammar/src/parser.c");
        const highlights = @embedFile("../vendor/grammars/gshell/grammar/queries/highlights.scm");

        return Language{
            .name = "gshell",
            .extensions = &.{ "gsh", "gshell" },
            .parser = parser_c,
            .highlights = highlights,
        };
    }
};
```

### Option 2: Direct Copy

Copy only the grammar files:

```bash
# From gshell repo
mkdir -p grove/vendor/grammars/gshell
cp gshell/grammar/src/parser.c grove/vendor/grammars/gshell/
cp -r gshell/grammar/queries grove/vendor/grammars/gshell/
```

### Option 3: Sparse Checkout (Advanced)

Clone only the grammar directory:

```bash
git clone --filter=blob:none --sparse https://github.com/ghostkellz/gshell
cd gshell
git sparse-checkout set grammar
```

## Building the Parser

To generate `src/parser.c` from `grammar.js`:

```bash
cd grammar
npm install
npx tree-sitter generate
```

**Note**: The generated `parser.c` should be committed to the repo so grove doesn't need Node.js/tree-sitter-cli.

## Usage in Editors

### grim

File type detection:

```lua
-- In ~/.config/grim/init.gza or init.lua
vim.filetype.add({
    extension = {
        gsh = "gshell",
        gshell = "gshell",
    },
})
```

### Neovim (with nvim-treesitter)

```lua
-- In ~/.config/nvim/init.lua
require'nvim-treesitter.parsers'.get_parser_configs().gshell = {
    install_info = {
        url = "https://github.com/ghostkellz/gshell",
        files = {"grammar/src/parser.c"},
        branch = "main",
        location = "grammar",
    },
    filetype = "gshell",
}

vim.filetype.add({
    extension = {
        gsh = "gshell",
        gshell = "gshell",
    },
})
```

## Highlight Groups

The grammar defines these highlight groups:

| Syntax Element | Highlight Group | Example |
|---------------|-----------------|---------|
| Built-in commands | `@function.builtin` | `cd`, `echo`, `alias` |
| Network commands | `@function.builtin.network` | `net-test`, `net-resolve` |
| GShell FFI | `@function.builtin.gshell` | `use_starship`, `enable_plugin` |
| External commands | `@function` | `git`, `ls`, `curl` |
| Flags | `@parameter` | `-la`, `--help` |
| Strings | `@string` | `"hello"`, `'world'` |
| Variables | `@variable` | `$HOME`, `${VAR}` |
| Operators | `@operator` | `\|`, `&&`, `>` |
| Comments | `@comment` | `# comment` |

## Color Scheme Integration

Recommended colors (from ghost-hacker-blue.yml):

```lua
-- In your editor theme
highlight('@function.builtin', { fg = '#7FFFD4' })        -- Aquamarine
highlight('@function.builtin.network', { fg = '#4fd6be' }) -- Teal
highlight('@function', { fg = '#98ff98' })                 -- Mint green
highlight('@parameter', { fg = '#ffc777' })                -- Yellow
highlight('@string', { fg = '#c3e88d' })                   -- Light green
highlight('@variable', { fg = '#89ddff' })                 -- Blue
highlight('@operator', { fg = '#ff966c' })                 -- Orange
highlight('@comment', { fg = '#636da6' })                  -- Gray
```

## Testing

```bash
cd grammar
npx tree-sitter test
```

Example test files in `test/`:

```bash
# test/corpus/commands.txt
================
Basic command
================

echo "Hello"

---

(program
  (command
    (builtin_command)
    (string)))
```

## Development

### Grammar Structure

- `grammar.js` - Syntax rules definition
- `src/parser.c` - Generated parser (committed)
- `queries/highlights.scm` - Syntax highlighting queries

### Adding New Syntax

1. Edit `grammar.js`
2. Run `npx tree-sitter generate`
3. Test with `npx tree-sitter test`
4. Update `queries/highlights.scm` for new elements
5. Commit both `grammar.js` and `src/parser.c`

## Differences from Bash

GShell is Bash-compatible but adds:
- Custom built-in commands (`net-*`)
- FFI functions for shell configuration
- Future: Control flow extensions, async commands

GShell does NOT support:
- Process substitution (`<(command)`)
- Array syntax (`arr=(1 2 3)`)
- Advanced parameter expansion (`${var//pattern/replacement}`)

These may be added in future versions.

## License

MIT

## See Also

- [grove](https://github.com/ghostkellz/grove) - Syntax highlighting library
- [grim](https://github.com/ghostkellz/grim) - Text editor using grove
- [tree-sitter](https://tree-sitter.github.io/) - Parser generator tool
