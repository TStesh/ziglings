const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;
const mem = std.mem;
const fmt = std.fmt;
const heap = std.heap;
const prc = std.process;
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

fn get_empty_cells(
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

pub fn sudokuSolver(
    alloc: mem.Allocator, 
    start_grid: [9][9]u8
) ![9][9]u8 {
	var grid_set = ArrayList([9][9]u8).init(alloc);
	try grid_set.append(start_grid);
	
	while (grid_set.items.len > 0) {
		// print("{d}\n", .{grid_set.items.len});
		var grid_set_new = ArrayList([9][9]u8).init(alloc); 
		grid_loop: for(grid_set.items) |grid| {
			
            var fi: usize = undefined;
            var fj: usize = undefined;
            var min_suit_digits_len: usize = 10;
            var min_suit_digits: ArrayList(u8) = undefined;
            
            const empty_cells = try get_empty_cells(alloc, grid);
            const empty_cells_len = empty_cells.items.len;
            
            // ищем cell с минимальным кол-ом допустимых чисел
            for (empty_cells.items) |cell| {
                const i: usize = cell / 9;
                const j: usize = cell % 9;
                const suit_digits = try get_suit_digits(alloc, grid, i, j);
                const suit_digits_len = suit_digits.items.len;
                if (suit_digits_len == 0) continue :grid_loop;
                if (suit_digits_len == 1) {
                    if (empty_cells_len == 1) {
                        var grid_copy = grid;
                        grid_copy[i][j] = suit_digits.items[0];
                        return grid_copy;
                    } else {
                        fi = i; fj = j;
                        min_suit_digits = try suit_digits.clone();
                        break;
                    }
                }
                if (suit_digits_len < min_suit_digits_len) {
                    min_suit_digits_len = suit_digits_len;
                    min_suit_digits = try suit_digits.clone();
                    fi = i; fj = j;
                }
            }    
            for (min_suit_digits.items) |d| {
                var grid_copy = grid;
                grid_copy[fi][fj] = d;
                try grid_set_new.append(grid_copy);
            }
		}
		grid_set.deinit();
		grid_set = grid_set_new;
	}
	return error.SolveNotFound;
}

fn init_grid(
    alloc: mem.Allocator, 
    path: []const u8
) ![9][9]u8 {
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

    // parse args
    const args = try prc.argsAlloc(arena);
    var path: []const u8 = "";
    
    switch (args.len) {
        2 => { path = args[1]; },
        else => {
            const help =
                \\usage: sudoku [file]
                \\
                \\  file is a normal .txt with start sudoku grid
                \\
                \\  Example sudoku.txt:
                \\
                \\  009748000
                \\  700000000
                \\  020109000
                \\  007000240
                \\  064010590
                \\  098000300
                \\  000803020
                \\  000000006
                \\  000275900
            ;
            print("{s}\n", .{help});
        },
    }
    
    if (path.len > 0) {
        var start_grid = try init_grid(arena, path);	
        var fill_grid = try sudokuSolver(arena, start_grid);

        print("\nStart grid:\n", .{});
        print_grid(start_grid);
        
        print("\nFilled grid:\n", .{});
        print_grid(fill_grid);
    }
}
