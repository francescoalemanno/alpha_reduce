const std = @import("std");
const zigimg = @import("zigimg");
const print = std.debug.print;
const string = []const u8;

fn Value(c: *const zigimg.color.Colorf32) f64 {
    return (@as(f64, c.r) + @as(f64, c.g) + @as(f64, c.b)) / 3.0;
}
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var argi = try std.process.argsWithAllocator(allocator);
    defer argi.deinit();

    const pname = argi.next() orelse @panic("missing args");
    print("Usage: {s} [-g 4.0 #gamma] [-t 0.5 #threshold] <image files>\n", .{pname});

    var gamma: f64 = 4.0;
    while (argi.next()) |arg| {
        // parse basic CLI args
        var cmd_enabled: bool = true;
        inline for (.{&gamma}, .{"-g"}) |par, cmd| {
            if (cmd_enabled and std.mem.eql(u8, arg, cmd)) {
                const par_s = argi.next() orelse std.debug.panic("missing argument for parameter {s}.", .{cmd});
                par.* = std.fmt.parseFloat(f64, par_s) catch std.debug.panic("invalid float for parameter {s}.", .{cmd});
                cmd_enabled = false;
            }
        }
        if (!cmd_enabled) continue;
        // process image
        const file = arg;
        print("processing {s}\n", .{file});
        var image = try zigimg.Image.fromFilePath(allocator, file);
        defer image.deinit();

        try image.convert(.float32);

        // Calculate the average and standard deviation of the pixel brightness
        // values, ignoring pixels below a rough threshold.
        var best_threshold: f64 = 0.5;
        var best_variance: f64 = -1;
        for (0..256) |it| {
            const th = @as(f64, @floatFromInt(it)) / 255.0;
            var mu1: f64 = 0.0;
            var mu2: f64 = 0.0;
            var n1: f64 = 0.0;
            var n2: f64 = 0.0;
            for (image.pixels.float32) |*c| {
                const v = Value(c);
                if (v > th) {
                    mu2 += v;
                    n2 += 1;
                } else {
                    mu1 += v;
                    n1 += 1;
                }
            }
            if (n1 <= 0.5 or n2 <= 0.5) continue;
            const o1 = n1 / (n1 + n2);
            const o2 = n2 / (n1 + n2);
            mu1 /= n1;
            mu2 /= n2;
            const variance = o1 * o2 * (mu1 - mu2) * (mu1 - mu2);
            if (variance > best_variance) {
                print("improved variance {d}, th: {d}\n", .{ variance, th });
                best_threshold = th;
                best_variance = variance;
            }
        }

        const threshold = best_threshold;
        print("threshold: {d}\n", .{threshold});
        // Apply the threshold to the pixel brightness values
        // and convert to a grayscale image with alpha channel
        for (image.pixels.float32) |*c| {
            const bw = Value(c);
            const v = @min(@max(bw / threshold, @as(f64, 0)), @as(f64, 1));
            const vg = std.math.pow(f64, v, gamma);
            const alpha = @min(1, @max(1 - vg, 0));
            c.a = @floatCast(alpha);
            if (alpha > 0) {
                const destcol = @min(1, @max((vg - (1 - alpha)) / alpha, 0));
                c.r = @floatCast(destcol);
                c.g = @floatCast(destcol);
                c.b = @floatCast(destcol);
            }
        }

        try image.convert(.rgba32);
        const sargs = [_]string{ file, "_t.png" };
        const all_args = try std.mem.concat(allocator, u8, &sargs);
        defer allocator.free(all_args);
        try image.writeToFilePath(all_args, .{ .png = .{} });
    }
}
