const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;
const fmt = std.fmt;
const heap = std.heap;
const print = std.debug.print;

fn fopen(dir: fs.Dir, path: []const u8) !fs.File {
	const path_w = try os.windows.sliceToPrefixedFileW(null, path);
	
	return fs.File {
		.handle = try os.windows.OpenFile(path_w.span(), .{
			.dir = dir.fd,
			.access_mask = os.windows.SYNCHRONIZE | os.windows.GENERIC_READ,
			.creation = os.windows.FILE_OPEN,
			.io_mode = .blocking,
			.filter = .any,
		}),
		.capable_io_mode = io.default_mode,
		.intended_io_mode = .blocking,
	};
}

fn grid_print(grid: [9][9]u8) void {
    for (grid) |row| {
        for(row) |cell| {
            print("{d} |", .{cell});
        }
        print("\n", .{});
    }
}

pub fn main() !void {
	const path = "c:\\codebase\\ziglings\\sudo-in.txt";
    const file = try fopen(fs.cwd(), path); 
	defer file.close();
	
	const stat = try file.stat();
	if (stat.kind != .file) @panic("error: it's not a file");
	if (stat.size < 99) @panic("error: incorrect syntax");
	
    var gpa_alloc = heap.GeneralPurposeAllocator(.{}) {};
    defer _ = gpa_alloc.deinit();
	const gpa = gpa_alloc.allocator();
	
	var fb = try fs.cwd().readFileAlloc(gpa, path, stat.size);
	
	var grid: [9][9]u8 = undefined;
	var row_num: u8 = 0;
	var col_num: u8 = 0;
	
	for (fb) |byte| {
        if (byte == 13) continue;
        if (byte != 10) {
            grid[row_num][col_num] = try fmt.charToDigit(byte, 10);
            col_num += 1;
            if (col_num > 9) @panic("error: # columns > 9 in the grid");
        } else {
            col_num = 0;
            row_num += 1;
            if (row_num > 9) @panic("error: # rows > 9 in the grid");
        }
	}
    
    grid_print(grid);
}

