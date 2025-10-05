const shell_mod = @import("shell.zig");
const parser_mod = @import("parser.zig");
const executor_mod = @import("executor.zig");
const builtins_mod = @import("builtins.zig");
const state_mod = @import("state.zig");
const config_mod = @import("config.zig");
const scripting_mod = @import("scripting.zig");
const completion_mod = @import("completion.zig");

pub const Shell = shell_mod.Shell;
pub const ShellConfig = config_mod.ShellConfig;
pub const ShellState = state_mod.ShellState;
pub const config = config_mod;

pub const parser = parser_mod;
pub const executor = executor_mod;
pub const builtins = builtins_mod;
pub const scripting = scripting_mod;
pub const completion = completion_mod;
