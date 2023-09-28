const std = @import("std");
const http = std.http;
const heap = std.heap;
const uri = std.Uri;
const mem = std.mem;
const json = std.json;
const debug = std.debug;
const print = debug.print;

const Value = struct { 
	results: [1](struct {
		id: u32,
		name: []const u8,
		latitude: f32,
		longitude: f32,
		elevation: f32,
		feature_code: []const u8,
		country_code: []const u8,
        admin1_id: u32,
        timezone: []const u8,
        population: u32,
        country_id: u32,
        country: []const u8,
        admin1: []const u8,
	}),
	generationtime_ms: f32,
};

const Place = struct { 
	latitude: f32, 
	longitude: f32 
};

fn getLatLong(malloc: mem.Allocator) anyerror!Place {
	const my_uri = uri.parse(
		"https://geocoding-api.open-meteo.com/v1/search?name=moscow&count=1&language=en&format=json"
	) catch unreachable;
    var client: http.Client = .{ .allocator = malloc };
    defer client.deinit();

    var req = try client.request(.GET, my_uri, .{ .allocator = malloc }, .{});
    defer req.deinit();
	
    try req.start();
    try req.wait();

    if (req.response.status == .ok) {
		var buf = try malloc.alloc(u8, 4 * 1024);
		var bytes = try req.read(buf);
		
		const loc = try json.parseFromSlice(Value, malloc, buf[0..bytes], .{});
		defer loc.deinit();
		
		return Place {
			.latitude = loc.value.results[0].latitude,
			.longitude = loc.value.results[0].longitude,
		};
	}
	
	print("status: {any}\n", .{req.response.status});
	print("reason: {any}\n", .{req.response.reason});
	
	return error.NoData;
} 

pub fn main() !void {
	// memory initialize
    var gpa_alloc = heap.GeneralPurposeAllocator(.{}) {};
    defer debug.assert(gpa_alloc.deinit() == .ok);
	const gpa = gpa_alloc.allocator();
	var arena_instance = heap.ArenaAllocator.init(gpa);
	defer arena_instance.deinit();
	const arena = arena_instance.allocator();
	
	const loc = try getLatLong(arena);
	
	print("{d:.5}\n", .{loc.latitude});
	print("{d:.5}\n", .{loc.longitude});
}