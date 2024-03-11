const std = @import("std");

pub fn usage() !void {
    var writer = std.io.getStdErr().writer();

    const options =
        \\Options:
        \\-h,--help: show this page
        \\-r,--recursive
        \\-s,--stat: detailed stat for each file
    ;

    try writer.print("\nwalk [OPTIONS] [FILE] \n{s}\n", .{options});
}

const ArgOptions = struct {
    path: ?[]const u8 = undefined,
    recursive: bool = false,
    stat: bool = false,

    fn setPath(self: *ArgOptions, path: []const u8) void {
        self.*.path = path;
    }
    fn setRecursiveFlag(self: *ArgOptions, is_rec: bool) void {
        self.*.recursive = is_rec;
    }
    fn setStatFlag(self: *ArgOptions, show_stat: bool) void {
        self.*.stat = show_stat;
    }
};

fn walkCurrDirWithOptions(arg_options: ArgOptions) !void {
    var dir = try std.fs.cwd().openIterableDir("", .{});

    defer dir.close();

    var dir_iter = dir.iterate();
    var file_count: usize = 0;
    var dir_count: usize = 0;

    while (try dir_iter.next()) |entry| {
        switch (entry.kind) {
            .file => {
                file_count += 1;

                if (arg_options.stat) {
                    try printFileWithStat(entry.name);
                } else {
                    try printFile(entry.name);
                }
            },
            .directory => {
                dir_count += 1;

                if (arg_options.stat) {
                    try printDirWithStat(entry.name);
                } else {
                    try printDir(entry.name);
                }
            },
            else => { //other kinds of entries doesn't matter
            },
        }
    }
    std.debug.print("\nFound {} files and {} directories\n", .{ file_count, dir_count });
}

fn walkDirWithOptions(path: []const u8, arg_options: ArgOptions) !void {
    var out_buffer: [std.fs.MAX_PATH_BYTES]u8 = .{};
    var absolute_path = try std.fs.realpath(path, &out_buffer);
    var absolute_path_ancestor = absolute_path[0 .. absolute_path.len - path.len];
    // std.debug.print("{s}", .{absolute_path});
    var dir = try std.fs.openDirAbsolute(absolute_path_ancestor, .{});
    defer dir.close();
    var dir_iterable = try dir.openIterableDir(path, .{});
    defer dir_iterable.close();

    var dir_iter = dir_iterable.iterate();
    var file_count: usize = 0;
    var dir_count: usize = 0;
    while (try dir_iter.next()) |entry| {
        switch (entry.kind) {
            .file => {
                file_count += 1;
                if (arg_options.stat) {
                    var file = dir_iterable.dir.openFile(entry.name, .{}) catch |err| {
                        std.debug.print("{} ENTRY: {s}, DIR:{s}", .{ err, entry.name, absolute_path });
                        return;
                    };
                    defer file.close();
                    var stat = try file.stat();

                    try std.io.getStdOut().writer().print("{s:<15}\tFILE\t{}\n", .{ entry.name, std.fmt.fmtIntSizeDec(stat.size) });
                } else {
                    try printFile(entry.name);
                }
            },
            .directory => {
                dir_count += 1;
                if (arg_options.stat) {
                    var dir_entry = dir_iterable.dir.openDir(entry.name, .{}) catch |err| {
                        std.debug.print("{} ENTRY: {s}, DIR:{s}", .{ err, entry.name, absolute_path });
                        return;
                    };
                    defer dir_entry.close();
                    var stat = try dir_entry.stat();

                    try std.io.getStdOut().writer().print("{s:<15}\tFILE\t{}\n", .{ entry.name, std.fmt.fmtIntSizeDec(stat.size) });
                } else {
                    try printDir(entry.name);
                }
            },
            else => { //other kinds of entries doesn't matter
            },
        }
    }
}

fn printFileWithStat(file_name: []const u8) !void {
    var file = try std.fs.cwd().openFile(file_name, .{});
    defer file.close();
    var stat = try file.stat();

    try std.io.getStdOut().writer().print("{s:<15}\tFILE\t{}\n", .{ file_name, std.fmt.fmtIntSizeDec(stat.size) });
}

fn printFile(file_name: []const u8) !void {
    try std.io.getStdOut().writer().print("{s:<15}\tFILE\t\n", .{file_name});
}

fn printDirWithStat(file_name: []const u8) !void {
    var dir_entry = try std.fs.cwd().openDir(file_name, .{});
    defer dir_entry.close();
    var stat = try dir_entry.stat();

    try std.io.getStdOut().writer().print("{s:<15}\tDIR\t{}\n", .{ file_name, std.fmt.fmtIntSizeDec(stat.size) });
}

fn printDir(file_name: []const u8) !void {
    try std.io.getStdOut().writer().print("{s:<15}\tDIR\n", .{file_name});
}

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.skip();

    var arg_options = ArgOptions{};
    while (args.next()) |arg| {
        if (std.mem.startsWith(u8, arg, "-")) {
            //read which flag it is
            switch (arg[1]) {
                'r' => {
                    arg_options.setRecursiveFlag(true);
                },
                's' => {
                    arg_options.setStatFlag(true);
                },
                'h' => {
                    try usage();
                    return 0x7f;
                },
                '-' => {
                    //these are double dash flags
                    //eg: --stat
                    if (std.mem.eql(u8, "stat", arg[2..])) {
                        arg_options.setStatFlag(true);
                    } else if (std.mem.eql(u8, "recursive", arg[2..])) {
                        arg_options.setRecursiveFlag(true);
                    }
                },
                else => {
                    try std.io.getStdErr().writer().print("\nIncorrect command\n", .{});
                    try usage();
                    return 0x7f;
                },
            }
        } else {
            arg_options.setPath(arg);
        }
    }
    if (arg_options.path) |path| {
        try walkDirWithOptions(path, arg_options);
    } else {
        try walkCurrDirWithOptions(arg_options);
    }
    return 0;
}

test "simple test" {}
