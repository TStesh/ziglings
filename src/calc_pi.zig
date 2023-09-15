const std = @import("std");
const print = std.debug.print;

pub fn main() !void {
    
    var num: u32 = undefined;
    
    {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
        const allocator = gpa.allocator();

        const args = try std.process.argsAlloc(allocator);
        defer std.process.argsFree(allocator, args);
        
        num = switch (args.len) {
            1 => 1_000_000,
            2 => std.fmt.parseInt(u32, args[1], 10) catch blk: {
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
    }
    
      
    if (num > 0) {
        const fnum: f64 = @floatFromInt(num);        
        var prng = std.rand.DefaultPrng.init(blk: {
            var seed: u64 = undefined;
            try std.os.getrandom(std.mem.asBytes(&seed));
            break :blk seed;
        });
        const rand = prng.random();

        var total: u32 = 0;
        for (0..num) |_| {
            const x = rand.float(f64);
            const y = rand.float(f64);
            if (x * x + y * y <= 1.0) total += 1;  
        }
        var ftot: f64 = @floatFromInt(total);

        print("pi({})= {d:.8}\n", .{num, 4.0 * ftot / fnum});

    }
}

