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

fn print_grid(grid: [9][9]u8) void {
    for (grid) |row| {
        for(row) |cell| print("{d} |", .{cell});
        print("\n", .{});
    }
	print("\n", .{});
}

fn get_col(grid: [9][9]u8, col_index: usize) [9]u8 {
	var col: [9]u8 = undefined;
	for (0..9) |i| col[i] = grid[i][col_index];
	return col;
}

fn get_blk(grid: [9][9]u8, row: usize, col: usize) [9]u8 {
	var blk: [9]u8 = undefined;
	const sr = row - row % 3;
	const sc = col - col % 3;
	var index: usize = 0;
	for(sr..sr + 3) |r| {
		for (sc..sc + 3) |c| {
			blk[index] = grid[r][c];
			index += 1;
		}
	}
	return blk;
}

fn inv(arr: [27]u8) [10]u8 {
	var iarr = [_]u8 {0} ** 10;
	for (arr) |item| {
		if (item > 0 and iarr[item] == 0) 
			iarr[item] = 1;
	}
	return iarr;
}

fn get_suit_digits(
	alloc: mem.Allocator, 
	grid: [9][9]u8, 
	row: usize, 
	col: usize
) !ArrayList(u8) {
	var v = ArrayList(u8).init(alloc);
	const arr = inv(grid[row] ++ get_col(grid, col) ++ get_blk(grid, row, col));
	for (1..10) |i| {
		if (arr[i] == 0) 
			try v.append(@intCast(i));
	}
	return v;
}

fn get_null_cells(
	alloc: mem.Allocator, 
	grid: [9][9]u8
) !ArrayList(u8) {
	var v = ArrayList(u8).init(alloc);
	for (grid, 0..) |row, i| {
        for(row, 0..) |cell, j| {
			if (cell == 0) 
				try v.append(@intCast(9 * i + j));
		}
	}
	return v;
}



fn init_grid(alloc: mem.Allocator, path: []const u8) ![9][9]u8 {
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

	var grid = try init_grid(arena, "c:\\ziglings\\src\\sudo-in.txt");	
    print_grid(grid);
	const x = try get_suit_digits(arena, grid, 5, 7);
	print("{any}\n\n", .{x.items});
	const y = try get_null_cells(arena, grid);
	print("{any}\n\n", .{y.items});
}

