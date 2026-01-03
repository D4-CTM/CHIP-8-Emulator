//! Imports and unit tests
const std = @import("std");
pub const Chip = @import("chip.zig");

test "Fontset correctly set" {
    var Xoshiro = std.Random.Xoshiro256.init(@intCast(std.time.timestamp()));
    var rand = Xoshiro.random();
    _ = &rand;

    var chip = Chip.Chip8.init(rand, true);
    _ = &chip;
    try std.testing.expect(chip.running);
    try std.testing.expectEqualSlices(u8, Chip.FONTSET[0..80], chip.memory[0..80]);

    chip.deinit();
    try std.testing.expect(!chip.running);

    std.debug.print("Test #1 passed!\n", .{});
}

test "Bit operations" {
    var bit: u16 = 0x000;
    try std.testing.expectEqual(0x000, bit);
    bit += 0x002;
    try std.testing.expectEqual(0x002, bit);
    bit += 0x002;
    try std.testing.expectEqual(0x004, bit);
    bit += 0x002;
    try std.testing.expectEqual(0x006, bit);
    
    bit = 0x00F;
    bit += 0x002;
    try std.testing.expectEqual(0x011, bit);  

    bit = 0x10 << 8;
    bit = bit | 0xFF;
    try std.testing.expectEqual(0x10FF, bit);

    const x = 0x510A & 0xFFFF;
    try std.testing.expectEqual(0x510A, x);

    const x1 = 0x510A & 0xF000;
    try std.testing.expectEqual(0x5000, x1);

    const x2 = 0x510A & 0x0FFF;
    try std.testing.expectEqual(0x010A, x2);

    const x3 = (0x510B & 0xF000) >> 12;
    try std.testing.expectEqual(0x5, x3);

    std.debug.print("Test #2 passed!\n", .{});
}

test "Operations under/overflow" {
    {
        const x: u8 = 5;
        const y: u8 = 10;
        const rest = @subWithOverflow(x, y);

        try std.testing.expectEqual(251, rest[0]);
        try std.testing.expectEqual(1, rest[1]); 
    }
    
    {
        const x: u8 = 250;
        const y: u8 = 10;

        const sum = @addWithOverflow(x, y);
        try std.testing.expectEqual(4, sum[0]);
        try std.testing.expectEqual(1, sum[1]); 
    }

    std.debug.print("Test #3 passed!\n", .{});
}
