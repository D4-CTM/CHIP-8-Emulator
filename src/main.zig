const std = @import("std");
const CHIP_8 = @import("CHIP_8");

pub fn main() !void {
    var Xoshiro = std.Random.Xoshiro256.init(@intCast(std.time.timestamp()));
    var rand = Xoshiro.random();
    _ = &rand;

    var chip = CHIP_8.Chip.Chip8.init(rand, true);
    defer chip.deinit();
    _ = &chip;

    try chip.LoadProgram("IBM Logo.ch8");
}

