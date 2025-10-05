; Tree-sitter highlighting queries for GShell
; Maps syntax elements to highlight groups for editors

; Built-in commands (cyan/aquamarine)
(builtin_command) @function.builtin

; Command names (green)
(command_name
  (word) @function)

; GShell-specific networking commands (highlighted specially)
(builtin_command
  (#match? @function.builtin "^(net-test|net-resolve|net-fetch|net-scan)$")) @function.builtin.network

; GShell FFI functions (highlighted specially)
(builtin_command
  (#match? @function.builtin "^(use_starship|enable_plugin|load_vivid_theme|setenv|getenv|command_exists|path_exists)$")) @function.builtin.gshell

; Flags and options (yellow)
(flag) @parameter

; Strings (magenta/green)
(string) @string
(raw_string) @string
(string_content) @string
(raw_string_content) @string

; Escape sequences (orange)
(escape_sequence) @string.escape

; Variables (blue)
(expansion
  "$" @punctuation.special
  (variable_name) @variable)

(expansion
  "${" @punctuation.special
  (variable_name) @variable
  "}" @punctuation.special)

(variable_assignment
  name: (variable_name) @variable)

; Command substitution (teal)
(command_substitution
  ["$(" ")" "`"] @punctuation.special)

; Operators (orange/red)
(pipeline
  operator: ["&&" "||"] @operator)

(pipeline
  operator: "|" @operator.pipe)

(redirection
  operator: [">" ">>" "<" "2>" "2>>" "&>" "&>>"] @operator)

; Comments (gray)
(comment) @comment

; Punctuation
["=" ";"] @punctuation.delimiter

; Keywords (if we add control flow later)
; ["if" "then" "else" "elif" "fi" "while" "for" "do" "done" "case" "esac"] @keyword

; Error highlighting (for invalid syntax)
(ERROR) @error
