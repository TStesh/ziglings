// Calc PI for the 10^9 monte-carlo steps
// One thread duration ~4,4 sec
// zig build-exe calc-pi-yard.zig -O ReleaseFast -fsingle-threaded -fstrip -target x86_64-windows

const std = @import("std");
const rand = std.rand;
const time = std.time;
const os = std.os;
const print = std.debug.print;

pub fn main() !void { 
    const num = 1_000_000_000;    
    
    var t = try std.time.Timer.start();
    
    var prng = rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rnd = prng.random();

    var total: u32 = 0;
    var x: f64 = undefined;
    var y: f64 = undefined;
    
    for (0..num) |_| {
        x = rnd.float(f64);
        y = rnd.float(f64);
        if (x*x + y*y <= 1.0) total += 1;  
    }
    
    const a: f64 = @floatFromInt(total);
    const b: f64 = @floatFromInt(num);
    var pi = 4.0 * a / b;
    
    const dur = std.fmt.fmtDuration(t.read());

    print("pi = {d:.8}\n", .{pi});
    print("duration: {d}", .{dur});
}

