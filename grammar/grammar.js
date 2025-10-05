// Tree-sitter grammar for GShell
// Simplified grammar to avoid conflicts

module.exports = grammar({
  name: 'gshell',

  extras: $ => [
    /\s/,
    $.comment,
  ],

  conflicts: $ => [
    [$.command],
  ],

  rules: {
    program: $ => repeat($._statement),

    _statement: $ => choice(
      $.pipeline,
      $.command,
      $.variable_assignment,
      $.comment,
    ),

    // Commands
    command: $ => prec.left(seq(
      field('name', $.command_name),
      repeat(field('argument', $._argument)),
      optional($.redirection),
    )),

    command_name: $ => choice(
      $.builtin_command,
      $.word,
    ),

    // GShell built-in commands
    builtin_command: $ => token(choice(
      // Core shell built-ins
      'cd',
      'echo',
      'alias',
      'exit',
      'export',
      'source',
      'set',
      'unset',
      'history',
      'type',

      // GShell networking built-ins
      'net-test',
      'net-resolve',
      'net-fetch',
      'net-scan',

      // GShell FFI functions
      'use_starship',
      'enable_plugin',
      'load_vivid_theme',
      'setenv',
      'getenv',
      'command_exists',
      'path_exists',
      'exec',
    )),

    // Arguments
    _argument: $ => choice(
      $.word,
      $.string,
      $.raw_string,
      $.expansion,
      $.command_substitution,
      $.flag,
    ),

    flag: $ => /--?[a-zA-Z0-9_-]+/,

    word: $ => /[a-zA-Z0-9_.\/-]+/,

    // Strings
    string: $ => seq(
      '"',
      repeat(choice(
        $.string_content,
        $.escape_sequence,
        $.expansion,
        $.command_substitution,
      )),
      '"',
    ),

    raw_string: $ => seq(
      "'",
      repeat($.raw_string_content),
      "'",
    ),

    string_content: $ => /[^"$\\]+/,
    raw_string_content: $ => /[^']+/,

    escape_sequence: $ => /\\./,

    // Variable expansion
    expansion: $ => choice(
      seq('$', $.variable_name),
      seq('${', $.variable_name, '}'),
      seq('$', /[0-9]+/),
      seq('$', choice('@', '*', '?', '$', '!', '-')),
    ),

    variable_name: $ => /[a-zA-Z_][a-zA-Z0-9_]*/,

    // Command substitution
    command_substitution: $ => choice(
      seq('$(', $.command, ')'),
      seq('`', $.command, '`'),
    ),

    // Variable assignment
    variable_assignment: $ => seq(
      field('name', $.variable_name),
      '=',
      field('value', choice(
        $.word,
        $.string,
        $.raw_string,
        $.expansion,
        $.command_substitution,
      )),
    ),

    // Pipelines
    pipeline: $ => prec.left(seq(
      $.command,
      repeat1(seq(
        field('operator', choice('|', '&&', '||')),
        $.command,
      )),
    )),

    // Redirection
    redirection: $ => repeat1(seq(
      field('operator', choice('>', '>>', '<', '2>', '2>>', '&>', '&>>')),
      field('target', choice(
        $.word,
        $.string,
        $.expansion,
      )),
    )),

    // Comments
    comment: $ => /#.*/,
  },
});
