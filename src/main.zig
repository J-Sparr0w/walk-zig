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
    // std.debug.print("\ncurrent dir iterating\n", .{});
    // var cwd = try std.fs.cwd();

    var print_buffer = std.io.bufferedWriter(std.io.getStdOut().writer());
    defer print_buffer.flush() catch {};
    var writer = print_buffer.writer();

    var dir = std.fs.cwd().openIterableDir(".", .{}) catch |err| {
        var stdErr = std.io.getStdErr().writer();
        try stdErr.print("\nERROR: current directory cannot be read [{s}]\n", .{@errorName(err)});
        // switch (err) {
        //     .FileNotFound => {
        //         stdErr.print("\nERROR: Unable to open Current Directory, [{}]\n", .{@errorName(err)});
        //     },
        //     .NotDir => {
        //         unreachable;
        //     },
        //     .AccessDenied => {
        //         stdErr.print("\nERROR: File Access Denied for current path\n", .{});
        //     },
        //     .NameTooLong => {
        //         stdErr.print("\nERROR: [{}]\n", .{@errorName(err)});
        //     },
        //     .InvalidUtf8 => {
        //         stdErr.print("\nERROR: [{}]\n", .{@errorName(err)});
        //     },

        //     else => {

        //     },
        // }
        return err;
    };
    defer dir.close();

    var dir_iter = dir.iterate();
    var file_count: usize = 0;
    var dir_count: usize = 0;

    while (dir_iter.next() catch |err| {
        std.log.err("Cannot continue directory traversal: {s}", .{@errorName(err)});
        return err;
    }) |entry| {
        switch (entry.kind) {
            .file => {
                file_count += 1;

                if (arg_options.stat) {
                    try printFileWithStat(writer, entry.name);
                } else {
                    try printFile(writer, entry.name);
                }
            },
            .directory => {
                dir_count += 1;

                if (arg_options.stat) {
                    try printDirWithStat(writer, entry.name);
                } else {
                    try printDir(writer, entry.name);
                }
            },
            else => { //other kinds of entries doesn't matter
            },
        }
    }
    try writer.print("\nFound {} files and {} directories\n", .{ file_count, dir_count });
}

fn walkDirWithOptions(path: []const u8, arg_options: ArgOptions) !void {
    var print_buffer = std.io.bufferedWriter(std.io.getStdOut().writer());
    defer print_buffer.flush() catch {};
    var writer = print_buffer.writer();

    var out_buffer: [std.fs.MAX_PATH_BYTES]u8 = .{};
    var absolute_path = std.fs.realpath(path, &out_buffer) catch |err| {
        std.log.err("[{s}]", .{@errorName(err)});
        return;
    };
    var absolute_path_ancestor = absolute_path[0 .. absolute_path.len - path.len];
    // std.debug.print("{s}", .{absolute_path});
    var dir = std.fs.openDirAbsolute(absolute_path_ancestor, .{}) catch |err| {
        std.log.err("Cannot open directory at path: {s} due to [{s}] error", .{ absolute_path, @errorName(err) });
        return err;
    };
    defer dir.close();
    var dir_iterable = dir.openIterableDir(path, .{}) catch |err| {
        std.log.err("Cannot open directory at path: {s} for iteration due to [{s}] error", .{ absolute_path, @errorName(err) });
        return err;
    };
    defer dir_iterable.close();

    var dir_iter = dir_iterable.iterate();
    var file_count: usize = 0;
    var dir_count: usize = 0;
    while (dir_iter.next() catch |err| {
        std.log.err("Cannot continue directory traversal: {s}", .{@errorName(err)});
        return err;
    }) |entry| {
        switch (entry.kind) {
            .file => {
                file_count += 1;
                if (arg_options.stat) {
                    var file = dir_iterable.dir.openFile(entry.name, .{}) catch |err| {
                        std.log.err(" ENTRY: {s} at DIR:{s} cannot be opened due to [{s}] error", .{ entry.name, absolute_path, @errorName(err) });
                        continue;
                    };
                    defer file.close();
                    var stat =
                        file.stat() catch {
                        try writer.print("{s:<25}\tFILE\tNA\n", .{entry.name});
                        continue;
                    };

                    try writer.print("{s:<25}\tFILE\t{}\n", .{ entry.name, std.fmt.fmtIntSizeDec(stat.size) });
                } else {
                    try printFile(writer, entry.name);
                }
            },
            .directory => {
                dir_count += 1;
                if (arg_options.stat) {
                    var dir_entry = dir_iterable.dir.openDir(entry.name, .{}) catch |err| {
                        std.log.err("{} ENTRY: {s}, DIR:{s}", .{ err, entry.name, absolute_path });
                        return;
                    };
                    defer dir_entry.close();
                    var stat =
                        dir_entry.stat() catch {
                        try writer.print("{s:<25}\tDIR\tNA\n", .{entry.name});
                        continue;
                    };
                    try writer.print("{s:<25}\tFILE\t{}\n", .{ entry.name, std.fmt.fmtIntSizeDec(stat.size) });
                } else {
                    try printDir(writer, entry.name);
                }
            },
            else => { //other kinds of entries doesn't matter
            },
        }
    }
    try writer.print("\nFound {} files and {} directories\n", .{ file_count, dir_count });
}

fn printFileWithStat(writer: anytype, file_name: []const u8) !void {
    var file = try std.fs.cwd().openFile(file_name, .{});
    defer file.close();
    var stat =
        file.stat() catch {
        try writer.print("{s:<25}\tFILE\tNA\n", .{file_name});
        return;
    };
    var time_buf: [100]u8 = undefined;
    const mtime = try calculateTime(&time_buf, stat.mtime);
    try writer.print("{s:<25}\tFILE\t{:.2}\t{s}\n", .{ file_name, std.fmt.fmtIntSizeDec(stat.size), mtime });
}

fn printFile(writer: anytype, file_name: []const u8) !void {
    try writer.print("{s:<25}\tFILE\t\n", .{file_name});
}

fn printDirWithStat(writer: anytype, file_name: []const u8) !void {
    var dir_entry = try std.fs.cwd().openDir(file_name, .{});
    defer dir_entry.close();
    var stat =
        dir_entry.stat() catch {
        try writer.print("{s:<25}\tDIR\tNA\n", .{file_name});
        return;
    };
    // const epoch_day = es.getEpochDay();
    var time_buf: [100]u8 = undefined;
    const mtime = try calculateTime(&time_buf, stat.mtime);
    try writer.print("{s:<25}\tDIR\t{:.2}\t{s}\n", .{ file_name, std.fmt.fmtIntSizeDec(stat.size), mtime });
}
fn printDir(writer: anytype, file_name: []const u8) !void {
    try writer.print("{s:<25}\tDIR\n", .{file_name});
}
fn calculateTime(buf: []u8, ns_since_epoch: i128) ![]const u8 {
    const es = std.time.epoch.EpochSeconds{ .secs = @divTrunc(@as(u64, @intCast(ns_since_epoch)), std.time.ns_per_s) };
    const month = es.getEpochDay().calculateYearDay().calculateMonthDay().month;
    const date = es.getEpochDay().calculateYearDay().calculateMonthDay().day_index;
    const hours = es.getDaySeconds().getHoursIntoDay();
    const mins = es.getDaySeconds().getMinutesIntoHour();

    return try std.fmt.bufPrint(buf, "{:0>2} {s} {:0>2}:{:0>2}", .{ date, @tagName(month), hours, mins });
}

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.skip();

    var arg_options = ArgOptions{ .path = null };
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
        walkDirWithOptions(path, arg_options) catch {
            return 0x7f;
        };
    } else {
        walkCurrDirWithOptions(arg_options) catch {
            return 0x7f;
        };
    }
    return 0;
}

test "simple test" {}
