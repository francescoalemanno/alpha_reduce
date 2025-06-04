const std = @import("std");
const zigimg = @import("zigimg");
const print = std.debug.print;
const string = []const u8;
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    for (args[1..]) |file| {
        var image = try zigimg.Image.fromFilePath(allocator, file);
        defer image.deinit();

        try image.convert(.float32);
        print("{}\n", .{image.pixelFormat()});
        var v0: f32 = 0.0;
        var v1: f32 = 0.0;
        var v2: f32 = 0.0;
        for (0..image.pixels.float32.len) |i| {
            const c = &image.pixels.float32[i];
            const v = (c.r + c.g + c.b) / 3.0;
            c.r = v;
            c.g = v;
            c.b = v;
            if (v > 0.5) {
                v0 += 1;
                v1 += v;
                v2 += v * v;
            }
        }

        v2 /= v0;
        v1 /= v0;
        const dev = @sqrt(@max(v2 - v1 * v1, @as(f32, 0.0)));
        print("{d} {d}\n", .{ v1, dev });
        const threshold = v1 - 1.9 * dev;
        for (0..image.pixels.float32.len) |i| {
            const c = &image.pixels.float32[i];
            const v = @min(@max(c.r / threshold, @as(f32, 0)), @as(f32, 1));
            const vg = std.math.pow(f32, v, @as(f32, 6.0));
            c.r = vg;
            c.g = vg;
            c.b = vg;
            c.a = (1 - vg) * (1 - vg);
        }
        try image.convert(.rgba32);
        const sargs = [_]string{ file, "_t.png" };
        const all_args = try std.mem.concat(allocator, u8, &sargs);
        defer allocator.free(all_args);
        try image.writeToFilePath(all_args, .{ .png = .{} });
    }
}
