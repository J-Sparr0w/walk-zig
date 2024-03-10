const std = @import("std");

pub fn usage() void {
    var writer = std.io.getStdOut();
    var bw = std.io.bufferedWriter(writer);
    var stdout = bw.writer();
    stdout.print("walk [OPTIONS] [FILE]", .{});
}

pub fn main() !void {}

test "simple test" {}
