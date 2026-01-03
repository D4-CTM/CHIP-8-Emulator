const std = @import("std");
const CHIP_8 = @import("CHIP_8");

pub fn main() !void {
    const args = std.os.argv;
    if (args.len == 1) {
        std.log.err("Expected arguments: chip8 <path to rom> [-s](if it's running a super chip8 rom) ", .{});
    }

    const path: []const u8 = std.mem.span(args[1]);
    const super: bool = (args.len == 3) and std.mem.eql(u8, @as([]const u8, std.mem.span(args[2])), "-s");

    var Xoshiro = std.Random.Xoshiro256.init(@intCast(std.time.timestamp()));
    var rand = Xoshiro.random();
    _ = &rand;

    var chip = CHIP_8.Chip.Chip8.init(rand, super);
    defer chip.deinit();
    _ = &chip;

    try chip.LoadProgram(path);
}

