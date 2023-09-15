const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;
const mem = std.mem;
const fmt = std.fmt;
const heap = std.heap;
const ArrayList = std.ArrayList;
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
        for(row) |cell| print("{d} |", .{cell});
        print("\n", .{});
    }
	print("\n", .{});
}

fn vec_print(arr: [9]u8) void {
    for (arr) |cell| print("{d} |", .{cell});
    print("\n\n", .{});
	
}

fn grid_col(grid: [9][9]u8, col_index: usize) [9]u8 {
	var col: [9]u8 = undefined;
	for (0..9) |i| col[i] = grid[i][col_index];
	return col;
}

fn grid_blk(grid: [9][9]u8, blk_num: usize) [9]u8 {
	var blk: [9]u8 = undefined;
	// 0 = [0][0], 1 = [0][3], 2 = [0][6]
	// 3 = [3][0], 4 = [3][3], 5 = [3][6]
	// 6 = [6][0], 7 = [6][3], 8 = [6][6]
	// in general: r = blk_num - blk_num % 3, c = 3 * (blk_num % 3)
	const x = blk_num % 3;
	const sr = blk_num - x;
	const sc = 3 * x;
	var index: usize = 0;
	for(sr..sr + 3) |r| {
		for (sc..sc + 3) |c| {
			blk[index] = grid[r][c];
			index += 1;
		}
	}
	return blk;
}

const SudokuError = error { 
	InvalidGrid,
	RepeatDigit,
	NotFreeCells
};

fn liner(arr: [9]u8) SudokuError![10]u8 {
	var line: [10]u8 = undefined;
	for (0..11) |i| line[i] = 0;
	for (arr) |cell| {
		if (line[cell] == 0) {
			line[cell] = 1;
		} else {
			return SudokuError.RepeatDigit;
		}
	}
	return line;
}

fn free_cells(alloc: mem.Allocator, arr: [9]u8) !ArrayList(u8) {
	const grid_liner = try liner(arr);
	var v = ArrayList(u8).init(alloc);
	for (1..11) |i| {
		if (grid_liner[i] == 0) try v.append(@intCast(i));
	}
	if (v.items.len == 0) return SudokuError.NotFreeCells;
	return v;
}

fn get_init_grid(alloc: mem.Allocator, path: []const u8) ![9][9]u8 {
    const file = try fopen(fs.cwd(), path); 
	defer file.close();
	
	const stat = try file.stat();
	if (stat.kind != .file) @panic("error: it's not a file");
	if (stat.size < 99) @panic("error: incorrect syntax");

	var fb = try fs.cwd().readFileAlloc(alloc, path, stat.size);
	
	var grid: [9][9]u8 = undefined;
	var row_num: u8 = 0;
	var col_num: u8 = 0;
	
	for (fb) |byte| {
        if (byte == 13) continue;
        if (byte != 10) {
            grid[row_num][col_num] = fmt.charToDigit(byte, 10) 
				catch @panic("error: not an digit in the grid");
            col_num += 1;
        } else {
            col_num = 0;
            row_num += 1;
        }
	}
	
	return grid;
}

pub fn main() !void {
	// memory initialize
    var gpa_alloc = heap.GeneralPurposeAllocator(.{}) {};
    defer std.debug.assert(gpa_alloc.deinit() == .ok);
	const gpa = gpa_alloc.allocator();
	var arena_instance = heap.ArenaAllocator.init(gpa);
	defer arena_instance.deinit();
	const arena = arena_instance.allocator();

	var grid = try get_init_grid(arena, "c:\\ziglings\\src\\sudo-in.txt");	
    
    grid_print(grid);
	
	const v = try free_cells(arena, grid_blk(grid, 5));
	for (v) |item| print("{d} |", .{item});
	print("\n", .{});
}

