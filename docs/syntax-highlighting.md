# Syntax Highlighting

GShell features real-time syntax highlighting powered by Grove (tree-sitter) with command validation.

## Features

### Real-Time Highlighting

As you type, GShell highlights:
- **Commands** - Builtins and executables in distinct colors
- **Flags** - Command-line options (e.g., `-la`, `--verbose`)
- **Strings** - Quoted text in string color
- **Variables** - Shell variables with `$VAR` or `${VAR}`
- **Operators** - Pipes (`|`), redirects (`>`, `>>`, `<`), logic (`&&`, `||`)
- **Comments** - Lines starting with `#`

### Error Highlighting

Invalid commands are highlighted in **RED** as you type:

```bash
invalidcmd123  # Shows in RED - command not found
ls            # Shows normally - valid command
cd            # Shows normally - valid builtin
```

The validator checks:
1. Built-in commands (cd, echo, pwd, etc.)
2. Executables in your `$PATH`
3. Caches results for fast lookups

## Themes

GShell includes 4 color themes:

### 1. ghost-hacker-blue (Default)
Cyberpunk-inspired blue theme with neon accents

### 2. mint-fresh
Clean, modern green theme

### 3. dracula
Popular purple/pink dark theme

### 4. classic
Traditional terminal colors

## Technical Details

### Architecture

```
User Input → Parser (tree-sitter) → Highlighter → Validator → ANSI Output
```

1. **Parser**: Tree-sitter parses shell syntax in real-time
2. **Highlighter**: Grove applies theme colors to syntax nodes
3. **Validator**: Checks command validity against PATH and builtins
4. **Output**: Renders ANSI escape codes to terminal

### Performance

- Command validation is cached for O(1) lookups
- Tree-sitter provides incremental parsing
- Highlighting happens on every keystroke with no noticeable lag
- PATH cache is cleared when environment changes

### Grammar Support

Full support for shell constructs:
- Pipelines: `cmd1 | cmd2 | cmd3`
- Redirections: `cmd > file`, `cmd 2>&1`
- Command substitution: `$(cmd)`, `` `cmd` ``
- Variable expansion: `$VAR`, `${VAR}`
- String escapes: `\n`, `\t`, `\"`, etc.
- Logical operators: `&&`, `||`, `;`

## Implementation Files

- `src/highlight.zig` - Main highlighter logic
- `src/themes.zig` - Color theme definitions
- `src/command_validator.zig` - Command validation with PATH cache
- `src/shell.zig:877-900` - Integration with readline loop

## Disabling Highlighting

Highlighting is automatically disabled in non-interactive mode:
```bash
# Interactive mode - highlighting enabled
gsh

# Script mode - highlighting disabled
gsh script.sh
```

## Future Enhancements

Planned features:
- Semantic highlighting for aliases
- User-defined color themes
- Highlight matching quotes/brackets
- Syntax-aware autocomplete integration
