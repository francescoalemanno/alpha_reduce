const std = @import("std");
const zigimg = @import("zigimg");
const print = std.debug.print;
const string = []const u8;
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const args = try std.process.argsAlloc(allocator);
    if (args.len < 2) {
        print("Usage: {s} <image files>\n", .{args[0]});
        return error.InvalidArguments;
    }
    defer std.process.argsFree(allocator, args);
    for (args[1..]) |file| {
        var image = try zigimg.Image.fromFilePath(allocator, file);
        defer image.deinit();
        print("processing {s}\n", .{file});

        try image.convert(.float32);
        var v0: f64 = 0.0;
        var v1: f64 = 0.0;
        var v2: f64 = 0.0;
        const rough_threshold = 0.5;
        // Calculate the average and standard deviation of the pixel brightness
        // values, ignoring pixels below a rough threshold.
        for (0..image.pixels.float32.len) |i| {
            const c = &image.pixels.float32[i];
            const v = (@as(f64, c.r) + @as(f64, c.g) + @as(f64, c.b)) / 3.0;
            if (v > rough_threshold) {
                v0 += 1;
                v1 += v;
                v2 += v * v;
            }
        }
        if (v0 <= 0.5) {
            print("No pixels above rough threshold {d}, skipping image.\n", .{rough_threshold});
            continue;
        }
        v2 /= v0;
        v1 /= v0;
        // dev is the standard deviation of the pixel brightness values
        // v1 is the average brightness value
        const dev = @sqrt(@max(v2 - v1 * v1, @as(f64, 0.0)));
        const threshold = @max(v1 - 1.9 * dev, rough_threshold);
        print("threshold: {d}\n", .{threshold});
        // Apply the threshold to the pixel brightness values
        // and convert to a grayscale image with alpha channel
        for (0..image.pixels.float32.len) |i| {
            const c = &image.pixels.float32[i];
            const bw = (@as(f64, c.r) + @as(f64, c.g) + @as(f64, c.b)) / 3.0;
            const v = @min(@max(bw / threshold, @as(f64, 0)), @as(f64, 1));
            const vg = std.math.pow(f64, v, @as(f64, 6.0));
            c.r = @floatCast(vg);
            c.g = @floatCast(vg);
            c.b = @floatCast(vg);
            c.a = @floatCast(std.math.pow(f64, @min(1, @max(1 - vg, 0)), 6.0));
        }

        try image.convert(.rgba32);
        const sargs = [_]string{ file, "_t.png" };
        const all_args = try std.mem.concat(allocator, u8, &sargs);
        defer allocator.free(all_args);
        try image.writeToFilePath(all_args, .{ .png = .{} });
    }
}
