/// GShell Integration Test Suite
/// Comprehensive tests for shell functionality, pipelines, redirection, and scripting
const std = @import("std");
const testing = std.testing;

// Test configuration
const test_timeout_ms = 5000;

// Helper to run gshell command and capture output
fn runGShellCommand(allocator: std.mem.Allocator, args: []const []const u8) !struct {
    stdout: []const u8,
    stderr: []const u8,
    exit_code: u8,
} {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = args,
    });

    return .{
        .stdout = result.stdout,
        .stderr = result.stderr,
        .exit_code = switch (result.term) {
            .Exited => |code| code,
            else => 1,
        },
    };
}

// ======================
// Basic Command Tests
// ======================

test "basic echo command" {
    const allocator = testing.allocator;

    const result = try runGShellCommand(allocator, &.{
        "./zig-out/bin/gshell",
        "--command",
        "echo Hello World",
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    try testing.expect(std.mem.indexOf(u8, result.stdout, "Hello World") != null);
    try testing.expectEqual(@as(u8, 0), result.exit_code);
}

test "basic ls command" {
    const allocator = testing.allocator;

    const result = try runGShellCommand(allocator, &.{
        "./zig-out/bin/gshell",
        "--command",
        "ls /tmp",
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    try testing.expectEqual(@as(u8, 0), result.exit_code);
}

test "cd and pwd" {
    const allocator = testing.allocator;

    const result = try runGShellCommand(allocator, &.{
        "./zig-out/bin/gshell",
        "--command",
        "cd /tmp && pwd",
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    try testing.expect(std.mem.indexOf(u8, result.stdout, "/tmp") != null);
}

// ======================
// Pipeline Tests
// ======================

test "simple pipe" {
    const allocator = testing.allocator;

    const result = try runGShellCommand(allocator, &.{
        "./zig-out/bin/gshell",
        "--command",
        "echo hello | grep hello",
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    try testing.expect(std.mem.indexOf(u8, result.stdout, "hello") != null);
    try testing.expectEqual(@as(u8, 0), result.exit_code);
}

test "multi-stage pipe" {
    const allocator = testing.allocator;

    const result = try runGShellCommand(allocator, &.{
        "./zig-out/bin/gshell",
        "--command",
        "echo -e 'line1\\nline2\\nline3' | grep line | cat",
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    try testing.expect(std.mem.indexOf(u8, result.stdout, "line") != null);
}

// ======================
// Redirection Tests
// ======================

test "output redirection >" {
    const allocator = testing.allocator;
    const test_file = "/tmp/gshell_test_redirect.txt";

    // Clean up before test
    std.fs.cwd().deleteFile(test_file) catch {};

    const result = try runGShellCommand(allocator, &.{
        "./zig-out/bin/gshell",
        "--command",
        "echo 'test content' > /tmp/gshell_test_redirect.txt",
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    // Verify file was created
    const file = try std.fs.cwd().openFile(test_file, .{});
    defer file.close();
    const size = try file.getEndPos();
    var buffer = try allocator.alloc(u8, @intCast(size));
    defer allocator.free(buffer);
    const read_bytes = try file.readAll(buffer);
    const content = buffer[0..read_bytes];

    try testing.expect(std.mem.indexOf(u8, content, "test content") != null);

    // Clean up
    std.fs.cwd().deleteFile(test_file) catch {};
}

test "append redirection >>" {
    const allocator = testing.allocator;
    const test_file = "/tmp/gshell_test_append.txt";

    // Clean up before test
    std.fs.cwd().deleteFile(test_file) catch {};

    // First write
    _ = try runGShellCommand(allocator, &.{
        "./zig-out/bin/gshell",
        "--command",
        "echo 'line1' > /tmp/gshell_test_append.txt",
    });

    // Append
    const result = try runGShellCommand(allocator, &.{
        "./zig-out/bin/gshell",
        "--command",
        "echo 'line2' >> /tmp/gshell_test_append.txt",
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    // Verify both lines exist
    const file = try std.fs.cwd().openFile(test_file, .{});
    defer file.close();
    const size = try file.getEndPos();
    var buffer = try allocator.alloc(u8, @intCast(size));
    defer allocator.free(buffer);
    const read_bytes = try file.readAll(buffer);
    const content = buffer[0..read_bytes];

    try testing.expect(std.mem.indexOf(u8, content, "line1") != null);
    try testing.expect(std.mem.indexOf(u8, content, "line2") != null);

    // Clean up
    std.fs.cwd().deleteFile(test_file) catch {};
}

// ======================
// Ghostlang Script Tests
// ======================

test "ghostlang print" {
    const allocator = testing.allocator;
    const script_file = "/tmp/test_print.gza";

    // Create test script
    const script_content =
        \\print("Hello from Ghostlang")
    ;

    try std.fs.cwd().writeFile(.{ .sub_path = script_file, .data = script_content });
    defer std.fs.cwd().deleteFile(script_file) catch {};

    const result = try runGShellCommand(allocator, &.{
        "./zig-out/bin/gshell",
        script_file,
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    try testing.expect(std.mem.indexOf(u8, result.stdout, "Hello from Ghostlang") != null);
}

test "ghostlang environment variables" {
    const allocator = testing.allocator;
    const script_file = "/tmp/test_env.gza";

    const script_content =
        \\setenv("TEST_VAR", "test_value")
        \\print(getenv("TEST_VAR"))
    ;

    try std.fs.cwd().writeFile(.{ .sub_path = script_file, .data = script_content });
    defer std.fs.cwd().deleteFile(script_file) catch {};

    const result = try runGShellCommand(allocator, &.{
        "./zig-out/bin/gshell",
        script_file,
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    try testing.expect(std.mem.indexOf(u8, result.stdout, "test_value") != null);
}

test "ghostlang cd and pwd" {
    const allocator = testing.allocator;
    const script_file = "/tmp/test_cd.gza";

    const script_content =
        \\cd("/tmp")
        \\print(get_cwd())
    ;

    try std.fs.cwd().writeFile(.{ .sub_path = script_file, .data = script_content });
    defer std.fs.cwd().deleteFile(script_file) catch {};

    const result = try runGShellCommand(allocator, &.{
        "./zig-out/bin/gshell",
        script_file,
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    try testing.expect(std.mem.indexOf(u8, result.stdout, "/tmp") != null);
}

// ======================
// Error Handling Tests
// ======================

test "nonexistent command" {
    const allocator = testing.allocator;

    const result = try runGShellCommand(allocator, &.{
        "./zig-out/bin/gshell",
        "--command",
        "nonexistent_command_12345",
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    // Should fail
    try testing.expect(result.exit_code != 0);
}

test "invalid ghostlang syntax" {
    const allocator = testing.allocator;
    const script_file = "/tmp/test_invalid.gza";

    const script_content = "this is not valid ghostlang syntax !!!";

    try std.fs.cwd().writeFile(.{ .sub_path = script_file, .data = script_content });
    defer std.fs.cwd().deleteFile(script_file) catch {};

    const result = try runGShellCommand(allocator, &.{
        "./zig-out/bin/gshell",
        script_file,
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    // Should fail with error
    try testing.expect(result.exit_code != 0);
    try testing.expect(result.stderr.len > 0);
}

// ======================
// Performance Tests
// ======================

test "startup time" {
    const allocator = testing.allocator;

    const start = std.time.nanoTimestamp();

    const result = try runGShellCommand(allocator, &.{
        "./zig-out/bin/gshell",
        "--command",
        "echo test",
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const end = std.time.nanoTimestamp();
    const duration_ms = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;

    // Startup + simple command should be < 1000ms
    try testing.expect(duration_ms < 1000.0);
}
