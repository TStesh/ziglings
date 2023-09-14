const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;
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

pub fn main() !void {
	const path = "c:\\users\\alexa\\downloads\\sudo-in.txt";
    const file = try fopen(fs.cwd(), path); 
	defer file.close();
	
	const stat = try file.stat();
	if (stat.kind != .file) @panic("error: it's not a file");
	if (stat.size < 99) @panic("error: incorrect syntax");
	
    var gpa_alloc = heap.GeneralPurposeAllocator(.{}) {};
    defer _ = gpa_alloc.deinit();
	const gpa = gpa_alloc.allocator();
	
	var fb = try fs.cwd().readFileAlloc(gpa, path, stat.size);
	
	const grid: [9][9]u8 = undefined;
	const row_num: u8 = undefined;
	const col_num: u8 = undefined;
	
	for (fb) |byte, n| {
		print("{c}", .{byte});
			const x = @parseToInt(
			row_num = n / 9;
			col_num = n % 9;
			
			grid[row_num][col_num] = 
	}
	print("\n", .{});
}

