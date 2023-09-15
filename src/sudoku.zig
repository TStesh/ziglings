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

fn grid_col(grid: [9][9]u8, col_index: usize) [9]u8 {
	var col: [9]u8 = undefined;
	for (0..9) |i| {
		col[i] = grid[i][col_index];
	}
	return col;
}

fn grid_blk(grid: [9][9]u8, blk_num: usize) [9]u8 {
	var blk: [9]u8 = undefined;
	// 0 = [0][0], 1 = [0][3], 2 = [0][6]
	// 3 = [1][0], 4 = [1][3], 5 = [1][6]
	// 6 = [2][0], 7 = [2][3], 8 = [2][6]
	// in general: r = blk_num / 3, c = 3 * (blk_num % 3)
	const sr = blk_num / 3;
	const sc = 3 * (blk_num % 3);
	var index: usize = 0;
	for(sr..sr + 3) |r| {
		for (sc..sc + 3) |c| {
			blk[index] = grid[r][c];
			index += 1;
		}
	}
	return blk;
}

const LinerError = error { RepeatDigit };

fn liner(arr: [9]u8) LinerError![10]u8 {
	var line = [_]u8 {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
	for (arr) |cell| {
		if (line[cell] == 0) {
			line[cell] = 1;
		} else {
			return LinerError.RepeatDigit;
		}
	}
	return line;
}

fn row_free_cells(grid: [9][9]u8, row_num: usize) [10]u8 {
	var line: [_]u8 = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
	for (grid[row_num]) |cell| {
		if (line[cell] == 0) {
	}
}

pub fn main() !void {

	// memory initialize
    var gpa_alloc = heap.GeneralPurposeAllocator(.{}) {};
    defer std.debug.assert(gpa_alloc.deinit() == .ok);
	const gpa = gpa_alloc.allocator();
	var arena_instance = heap.ArenaAllocator.init(gpa);
	defer arena_instance.deinit();
	const arena = arena_instance.allocator();

	// grid initialize
	const path = "c:\\ziglings\\src\\sudo-in.txt";
    const file = try fopen(fs.cwd(), path); 
	defer file.close();
	
	const stat = try file.stat();
	if (stat.kind != .file) @panic("error: it's not a file");
	if (stat.size < 99) @panic("error: incorrect syntax");

	var fb = try fs.cwd().readFileAlloc(arena, path, stat.size);
	
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

