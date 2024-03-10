const std = @import("std");

pub fn usage() !void {
    var writer = std.io.getStdErr().writer();

    const options = "Options:\n";

    try writer.print("\nwalk [OPTIONS] [FILE] \n{s}\n", .{options});
}

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.skip();

    if (args.next()) |_| {
        try usage();
        return 0x7f;
    } else {
        var dir = try std.fs.cwd().openIterableDir("", .{});
        defer dir.close();

        var dir_iter = dir.iterate();
        var file_count: usize = 0;
        var dir_count: usize = 0;

        while (try dir_iter.next()) |entry| {
            switch (entry.kind) {
                .file => {
                    file_count += 1;

                    std.debug.print("{s:<20}\t[FILE]\n", .{entry.name});
                },
                .directory => {
                    dir_count += 1;
                    std.debug.print("{s:<20}\t[DIR]\n", .{entry.name});
                },
                else => {},
            }
        }
        std.debug.print("\nFound {} files and {} directories\n", .{ file_count, dir_count });
    }
    return 0;
}

test "simple test" {}
