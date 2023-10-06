const std = @import("std");
const process = std.process;
const fmt = std.fmt;
const rand = std.rand;
const mem = std.mem;
const heap = std.heap;
const os = std.os;
const debug = std.debug;
const print = debug.print;

pub fn main() !void {
    // memory initialize
    var gpa_alloc = heap.GeneralPurposeAllocator(.{}) {};
    defer debug.assert(gpa_alloc.deinit() == .ok);
	const gpa = gpa_alloc.allocator();
	var arena_instance = heap.ArenaAllocator.init(gpa);
	defer arena_instance.deinit();
	const arena = arena_instance.allocator();
	
	const args = try process.argsAlloc(arena);
    defer process.argsFree(arena, args);
	
	var num: u32 = undefined;
	
	num = switch (args.len) {
		1 => 1_000_000,
		2 => fmt.parseInt(u32, args[1], 10) catch blk: {
				print("{s} is not an integer\n", .{args[1]});
				print("will be used the TS parameter default value (1M)\n", .{});
				break :blk num;
			},
		else => ll: {
			print("usage: calc_pi [TS]\n", .{});
			print("TS is an integer parameter with default value 1M\n", .{});
			break :ll 0;
		}
	};
      
    if (num > 0) {
        const fnum: f64 = @floatFromInt(num);        
        var prng = rand.DefaultPrng.init(blk: {
            var seed: u64 = undefined;
            try os.getrandom(mem.asBytes(&seed));
            break :blk seed;
        });
        const rnd = prng.random();
        var total: u32 = 0;
        for (0..num) |_| {
            const x = rnd.float(f64);
            const y = rnd.float(f64);
            if (x * x + y * y <= 1.0) total += 1;  
        }
        var ftot: f64 = @floatFromInt(total);
        print("pi({})= {d:.5}\n", .{num, 4.0 * ftot / fnum});
    }
}

