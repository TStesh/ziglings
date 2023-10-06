const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;
const mem = std.mem;
const fmt = std.fmt;
const heap = std.heap;
const prc = std.process;
const ArrayList = std.ArrayList;
const Sha1 = std.crypto.hash.Sha1;
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

const TorInfo = struct {
	//announce: []const u8,
	//length: u32,
	//name: []const u8,
	//piece_length: u32,
	//pieces: []const u8
	
	infoJson: []const u8, 
	
	pub fn getInfoJson(malloc: mem.Allocator, path: []const u8) !void {
		const file = try fopen(fs.cwd(), path); 
		defer file.close();
		
		const stat = try file.stat();
		
		if (stat.kind != .file) return error.NotFile;
		if (stat.size < 99) return error.BadFile;
		
		// read the file
		var fb = try fs.cwd().readFileAlloc(malloc, path, stat.size);
		
		// process:
		const state = enum { DICT, DICT?, LIST, LIST?, NUM, NUM?, STR, STR? };
		var stack = std.ArrayList(state).init(malloc);
		defer stack.deinit();
		
		var in = try malloc.alloc(u8, stat.size);
		var out = try malloc.alloc(u8, stat.size);
		var cur_in_index: usize = 0;
		var cur_out_index: usize = 0;
		
		// info := d<num>:<dict>e
		// <dict> := <key><value>{<key><value>}
		// <key> := <num-key>|<str-key>|<list-key>
		// <num-key> := i<num>e
		// <str-key> := <num>:<string>
		// <list-key> := l
		for (fb) |c| {
			switch (state) {
				state.EMPTY => {
					switch (c) {
						'd' => cur_state = state.DICT?,
						'l' => cur_state = state.LIST?,
						else => return error.BadStructure
					},
				},
			}
			out[i] = c;
		}
		
		print("{any}\n", .{out});
	}
};

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
    defer prc.argsFree(arena, args);
	
	var path: []const u8 = undefined;
    path = switch (args.len) {
        2 => args[1],
        else => blk: {
			print("\nusage: torinfo [torrent-file]\n", .{});
			break :blk "";
		}
    };
    
    if (path.len > 0) {
         try TorInfo.getInfoJson(arena, path);
    }
		
	// SHA1 hash:
	// const input = "hello";
    // var output: [Sha1.digest_length]u8 = undefined;
	// Sha1.hash(input, &output, .{});
    // std.debug.print("{s}\n", .{std.fmt.fmtSliceHexLower(&output)});
}
