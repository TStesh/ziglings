// LostFilm torrents 
//
// zig build-exe search.zig -O ReleaseFast -fstrip -target x86_64-windows

const std = @import("std");
const heap = std.heap;
const mem = std.mem;
const sha = std.crypto.hash.Sha1;
const arr_list = std.ArrayList;
const http = std.http;
const uri = std.Uri;
const address = std.net.Address;
const print = std.debug.print;

const SHA_HASH_SIZE: usize = 20;
const PEER_SOC_BYTES: usize = 6;

const Info = struct {
	length: u32 = 0,
	piece_length: u32 = 0,
	infohash: []u8,
	announces: [][]u8,
	piece_hashes: [][]const u8,
	
	pub fn init(path: []const u8) !Info {
		const file = try std.fs.cwd().openFile(path, .{}); 
		defer file.close();
			
		const stat = try file.stat();
		if (stat.kind != .file) return error.NotFile;
		
		// memory initialize
		var gpa_alloc = heap.GeneralPurposeAllocator(.{}) {};
		defer std.debug.assert(gpa_alloc.deinit() == .ok);
		const gpa = gpa_alloc.allocator();
		
		var adigs: arr_list(u8) = undefined;
		var needle: []const u8 = undefined;
		var pos: usize = undefined;
		
		// get torrent file's content
		const content = try std.fs.cwd().readFileAlloc(gpa, path, stat.size);
		
		// get the inofhash
		needle = "4:info";
		pos = mem.indexOf(u8, content, needle) orelse return error.BadFileNoInfo;
		var out: [sha.digest_length]u8 = undefined;
		sha.hash(content[pos + needle.len..content.len - 1], &out, .{});
		const charset = "0123456789abcdef";
		var hash_out = arr_list(u8).init(gpa);
		var buf: [3]u8 = undefined;
		for(out) |c| {
			buf[0] = '%';
            buf[1] = charset[c >> 4];
			buf[2] = charset[c & 15];
            try hash_out.writer().writeAll(&buf);
		}
		
		// get the announce list
		needle = "13:announce-listl";
		pos = mem.indexOf(u8, content, needle) orelse return error.BadFileNoAnnounceList;
		var index = pos + needle.len;
		var alist = arr_list([]u8).init(gpa);
		var next_char = content[index];
		while(next_char != 'e') {
			// pattern: l<num>:<announce>e
			// do +1 because skip 'l'
			adigs = try getDigs(gpa, content, index + 1, ':');
			var anum: usize = @intCast(getNum(&adigs));
			// do +2 because skip the 'l' and ':'
			var start_idx = index + adigs.items.len + 2;
			var end_idx = start_idx + anum;
			try alist.append(content[start_idx..end_idx]);
			// do +1 because skip the 'e'
			index = end_idx + 1;
			next_char = content[index];
			adigs.deinit();
		}
		
		// get the piece hashes
		needle = "6:pieces";
		pos = mem.indexOf(u8, content, needle) orelse return error.BadFileNoPieces;
		adigs = try getDigs(gpa, content, pos + needle.len, ':');
		var pieces_size: usize = @intCast(getNum(&adigs));
		if (pieces_size % SHA_HASH_SIZE != 0) return error.BadFileInvalidPieces;
		var start_idx = pos + needle.len + adigs.items.len + 1;
		var pieces_str = content[start_idx..start_idx + pieces_size];
		var pieces = arr_list([]const u8).init(gpa);
		var i: usize = 0;
		while(i < pieces_size) : (i += SHA_HASH_SIZE) {
			try pieces.append(pieces_str[i..i + SHA_HASH_SIZE]);
		}
		std.debug.assert(pieces.items.len == pieces_size / SHA_HASH_SIZE);
		
		return Info {
			.infohash = hash_out.items,
			.piece_length = try getNumLiteral(gpa, content, "12:piece lengthi", 'e'),
			.length = try getNumLiteral(gpa, content, "6:lengthi", 'e'),
			.piece_hashes = pieces.items,
			.announces = alist.items,
		};
	}
};

const PeersList = struct {
	peers: []address,
	
	pub fn init(info: *Info) !PeersList {
		// memory initialize
		var gpa_alloc = heap.GeneralPurposeAllocator(.{}) {};
		defer std.debug.assert(gpa_alloc.deinit() == .ok);
		const gpa = gpa_alloc.allocator();
			
		// get the peers list
		var get_url = try std.fmt.allocPrint(gpa, 
			"{s}?info_hash={s}&peer_id=277095c71c91c2301e450438f5e6f312bd17f982" ++
			"&left={d}&port=6881&uploaded=0&downloaded=0&compact=1", 
			.{info.announces[1], info.infohash, info.length}
		);

		var get_uri = try uri.parse(get_url);
		
		var client: http.Client = .{ .allocator = gpa };
		defer client.deinit();
		
		var req = try client.request(.GET, get_uri, .{ .allocator = gpa }, .{});
		defer req.deinit();
		
		try req.start();
		try req.wait();
		
		if (req.response.status != .ok) return error.FailureRequest;
			
		var buf = try gpa.alloc(u8, 1024);
		var bytes = try req.read(buf);
		var content = buf[0..bytes];
		
		// get the peers
		var needle = "5:peers";
		var pos = mem.indexOf(u8, content, needle) orelse return error.BadFileNoPieces;
		var adigs = try getDigs(gpa, content, pos + needle.len, ':');
		var peers_size: usize = @intCast(getNum(&adigs));
		if (peers_size % PEER_SOC_BYTES != 0) return error.BadPeersList;
		var start_idx = pos + needle.len + adigs.items.len + 1;
		var peers_str = content[start_idx..start_idx + peers_size];
		var peers_list = arr_list(address).init(gpa);
		var i: usize = 0;
		while(i < peers_size) : (i += PEER_SOC_BYTES) {
			var peers_byte = peers_str[i..i + PEER_SOC_BYTES];
			try peers_list.append(
				address.initIp4(
					// octet
					[4]u8{ 
						peers_byte[0], 
						peers_byte[1], 
						peers_byte[2], 
						peers_byte[3] 
					},
					// port
					(@as(u16, peers_byte[4]) << 8) + 
					@as(u16, peers_byte[5])
				)
			);
		}
		std.debug.assert(peers_list.items.len == peers_size / PEER_SOC_BYTES);
		gpa.free(buf);
		
		return .{
			.peers = peers_list.items,
		};
	}
};

fn getNumLiteral(
	malloc: mem.Allocator, 
	string: []u8, 
	literal: []const u8,
	term: u8
) !u32 {
	const p = mem.indexOf(u8, string, literal) orelse return error.BadFileNoLiteral;
	var digs = try getDigs(malloc, string, p + literal.len, term);
	var num = getNum(&digs);
	digs.deinit();
	return num;
}

fn getDigs(
	malloc: mem.Allocator, 
	string: []u8, 
	num_index: usize,
	term: u8
) !arr_list(u8) {
	var digs = arr_list(u8).init(malloc);
	var idx = num_index;
	var c = string[idx];
	while (c != term) {
		try digs.append(c - '0');
		idx += 1;
		c = string[idx];
	}
	return digs;
}

fn getNum(digits: *arr_list(u8)) u32 {
	var num: u32 = 0;
	var p10: u32 = 1;
	const size = digits.items.len; 
	for (0..size) |i| {
		num += p10 * digits.items[size - i - 1];
		p10 *= 10;
	}
	return num;
}

pub fn main() !void {
	// const path = "c:\\users\\alexa\\downloads\\example.txt";
	const path = "c:\\users\\alexa\\downloads\\";
	const file = "Star.Trek.Lower.Decks.S04E05.1080p.rus.LostFilm.TV.mkv.torrent";
	
	var info = try Info.init(path ++ file);
	var peers_list = try PeersList.init(&info);
	
	for(peers_list.peers, 1..) |peer, i| {
		print("{d}: {any}\n", .{i, peer});
	}
}
