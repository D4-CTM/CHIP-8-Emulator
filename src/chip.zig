const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});

const WIDTH = 10;
const HEIGHT = 10;

fn getKey() ?u8 {
    return if (ray.IsKeyDown(ray.KEY_ONE)) 0x1 else if (ray.IsKeyDown(ray.KEY_TWO)) 0x2 else if (ray.IsKeyDown(ray.KEY_THREE)) 0x3 else if (ray.IsKeyDown(ray.KEY_FOUR)) 0xC else if (ray.IsKeyDown(ray.KEY_Q)) 0x4 else if (ray.IsKeyDown(ray.KEY_W)) 0x5 else if (ray.IsKeyDown(ray.KEY_E)) 0x6 else if (ray.IsKeyDown(ray.KEY_R)) 0xD else if (ray.IsKeyDown(ray.KEY_A)) 0x7 else if (ray.IsKeyDown(ray.KEY_S)) 0x8 else if (ray.IsKeyDown(ray.KEY_D)) 0x9 else if (ray.IsKeyDown(ray.KEY_F)) 0xE else if (ray.IsKeyDown(ray.KEY_Z)) 0xA else if (ray.IsKeyDown(ray.KEY_X)) 0x0 else if (ray.IsKeyDown(ray.KEY_C)) 0xB else if (ray.IsKeyDown(ray.KEY_V)) 0xF else null;
}

pub const FONTSET = [_]u8{
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0xE0, 0x90, 0x90, 0x90, 0xE0, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80, // F
};

// Function made with Gemini
fn createBeep(frequency: f32, duration: f32) ray.Sound {
    const sample_rate = 44100;
    const frame_count = @as(u32, @intFromFloat(sample_rate * duration));
    
    // Allocate memory for the audio samples
    // Using C allocator because raylib's UnloadWave will attempt to free this
    const samples = ray.MemAlloc(@as(c_uint, @intCast(frame_count * @sizeOf(f32))));
    const float_samples: [*]f32 = @ptrCast(@alignCast(samples));

    var i: u32 = 0;
    while (i < frame_count) : (i += 1) {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(sample_rate));
        var amplitude: f32 = 0.5; // Volume (0.0 to 1.0)

        // Simple Fade-out to prevent "clicking"
        const fade_threshold = 0.1; // last 10% of the sound
        const current_pos = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(frame_count));
        if (current_pos > (1.0 - fade_threshold)) {
            amplitude *= (1.0 - current_pos) / fade_threshold;
        }

        float_samples[i] = @sin(2.0 * std.math.pi * frequency * t) * amplitude;
    }

    const wave = ray.Wave{
        .frameCount = frame_count,
        .sampleRate = sample_rate,
        .sampleSize = 32, // 32-bit float
        .channels = 1,    // Mono
        .data = samples,
    };

    const sound = ray.LoadSoundFromWave(wave);
    
    // We can free the CPU-side wave immediately because 
    // LoadSoundFromWave copies the data to the audio system/RAM.
    ray.UnloadWave(wave); 
    
    return sound;
}

pub const Chip8 = struct {
    running: bool = true,
    super: bool = false,
    opcode: u16 = 0,
    memory: [4096]u8 = undefined,
    /// Variables
    v: [16]u8 = undefined,
    /// Index register
    I: u16 = 0,
    /// Program Counter
    pc: u16 = 0x200,
    gfx: [64][32]bool = undefined,

    SOUND_TIMER: u8 = 0,
    DELAY_TIMER: u8 = 0,

    stack: [16]u16 = undefined,
    /// Stack pointer
    sp: u8 = 0,

    rand: std.Random,

    /// We pass the random struct instance and specify if we are talking about
    /// the super chip or not
    pub fn init(rand: std.Random, super: bool) Chip8 {
        var chip = Chip8{ .rand = rand, .super = super };
        _ = &chip;
        std.mem.copyForwards(u8, &chip.memory, &FONTSET);
        for (chip.gfx[0..]) |*gfx| {
            @memset(gfx, false);
        }
        @memset(&chip.stack, 0);
        @memset(&chip.v, 0);
        return chip;
    }

    pub fn deinit(this: *Chip8) void {
        this.running = false;
    }

    pub fn ExecuteOpcode(this: *Chip8, opcode: u16) !void {
        std.debug.print("opcode: 0x{x:0>4}\n", .{opcode});
        const x = (opcode & 0xF00) >> 8;
        const y = (opcode & 0xF0) >> 4;
        switch (opcode & 0xF000) {
            0x0000 => switch (opcode) {
                0xE0 => {
                    ray.ClearBackground(ray.BLACK);
                    this.gfx = undefined;
                },
                0xEE => {
                    this.pc = this.stack[this.sp];
                    if (this.sp > 0)
                        this.sp -= 1;
                },
                else => return error.UnkownOpcode,
            },
            0x1000 => this.pc = opcode & 0xFFF,
            0x2000 => {
                if (this.sp == this.stack.len - 1) return error.StackOverflow;
                this.stack[this.sp] = this.pc;
                this.sp += 1;

                this.pc = opcode & 0xFFF;
            },
            0x3000 => {
                const nn = opcode & 0xFF;

                if (this.v[x] == nn) this.pc += 2;
            },
            0x4000 => {
                const nn = opcode & 0xFF;

                if (this.v[x] != nn) this.pc += 2;
            },
            0x5000 => if (this.v[x] == this.v[y]) {
                this.pc += 2;
            },
            0x6000 => {
                const nn: u8 = @intCast(opcode & 0xFF);

                this.v[x] = nn;
            },
            0x7000 => {
                const nn: u8 = @intCast(opcode & 0xFF);

                this.v[x] = @min(this.v[x] + nn, 255);
            },
            0x8000 => switch (opcode & 0xF) {
                0x0 => this.v[x] = this.v[y],
                0x1 => this.v[x] |= this.v[y],
                0x2 => this.v[x] &= this.v[y],
                0x3 => this.v[x] ^= this.v[y],
                0x4 => {
                    const sum = @addWithOverflow(this.v[x], this.v[y]);
                    this.v[x] = sum[0];
                    this.v[0xF] = sum[1];
                },
                0x5 => {
                    const rest = @subWithOverflow(this.v[x], this.v[y]);

                    this.v[x] = rest[0];
                    this.v[0xF] = rest[1];
                },
                0x6 => {
                    if (!this.super) {
                        this.v[x] = this.v[y];
                    }

                    this.v[0xF] = this.v[x] & 0x1;
                    this.v[x] = this.v[x] >> 1;
                },
                0x7 => {
                    const rest = @subWithOverflow(this.v[y], this.v[x]);

                    this.v[x] = rest[0];
                    this.v[0xF] = rest[1];
                },
                0xE => {
                    if (!this.super) {
                        this.v[x] = this.v[y];
                    }

                    this.v[0xF] = @bitReverse(this.v[x]) & 0x1;
                    this.v[x] = this.v[x] << 1;
                },
                else => return error.UnkownOpcode,
            },
            0x9000 => if (this.v[x] != this.v[y]) {
                this.pc += 2;
            },
            0xA000 => this.I = @intCast(opcode & 0xFFF),
            0xB000 => {
                var offset = opcode & 0xFFF;
                if (this.super) {
                    offset += this.v[x];
                } else {
                    offset += this.v[0];
                }

                this.pc += offset;
            },
            0xC000 => {
                const nn: u8 = @intCast(opcode & 0xFF);

                this.v[x] = this.rand.int(u8) & nn;
            },
            0xD000 => {
                const n = (opcode & 0xF);

                const cx = this.v[x] % 64;
                var cy = this.v[y] % 32;
                this.v[0xF] = 0;

                for (0..n) |idx| {
                    const asset = this.memory[this.I + idx];
                    for (0..8) |pos| {
                        if (cx + pos >= 64) continue;
                        const bit = (std.math.shr(u8, asset, pos) & 1) == 1;

                        this.gfx[cx + (8 - pos)][cy] = bit;
                    }
                    cy += 1;
                    if (cy >= 32) return;
                }
            },
            0xE000 => switch (opcode & 0xFF) {
                0xA1 => if (getKey()) |key|
                    if (this.v[x] == key) {
                        this.pc += 2;
                    },
                0x9E => if (getKey()) |key|
                    if (this.v[x] != key) {
                        this.pc += 2;
                    },
                else => return error.UnkownOpcode,
            },
            0xF000 => switch (opcode & 0xFF) {
                0x07 => this.v[x] = this.DELAY_TIMER,
                0x0A => if (getKey()) |key| {
                    this.v[x] = key;
                } else {
                    this.pc -= 2;
                },
                0x15 => this.DELAY_TIMER = this.v[x],
                0x18 => this.SOUND_TIMER = this.v[x],
                0x29 => this.I = this.v[x],
                0x33 => {
                    var num = this.v[x];

                    const x3 = num % 10;

                    num /= 10;
                    const x2 = num % 10;

                    num /= 10;
                    const x1 = num % 10;

                    this.memory[this.I] = x3;
                    this.memory[this.I + 1] = x2;
                    this.memory[this.I + 2] = x1;
                },
                0x1E => {
                    const result = this.I + this.v[x];
                    if (result > 0xFFF) this.v[0xF] = 1;
                    this.I = result % 0xFFF;
                },
                0x55 => {
                    for (0..x + 1) |idx| {
                        this.memory[this.I + idx] = this.v[idx];
                    }
                    if (this.super) this.I += x + 1;
                },
                0x65 => {
                    for (0..x + 1) |idx| {
                        this.v[idx] = this.memory[this.I + idx];
                    }
                    if (this.super) this.I += x + 1;
                },
                else => return error.UnkownOpcode,
            },
            else => return error.UnkownOpcode,
        }
    }

    pub fn DrawGraphics(this: *Chip8) void {
        ray.BeginDrawing();
        defer ray.EndDrawing();

        for (this.gfx, 0..) |gfx, x| {
            for (gfx, 0..) |bit, y| {
                const color = if (bit) ray.WHITE else ray.BLACK;
                ray.DrawRectangle(@intCast(x * 10), @intCast(y * 10), WIDTH, HEIGHT, color);
            }
        }
    }

    pub fn LoadProgram(this: *Chip8, program: []const u8) !void {
        var file = try std.fs.cwd().openFile(program, .{ .mode = .read_only });
        defer file.close();

        _ = try file.readAll(this.memory[0x200..]);

        ray.InitWindow(640, 320, "Chip-8");
        defer ray.CloseWindow();

        ray.InitAudioDevice();
        defer ray.CloseAudioDevice();

        const beep = createBeep(440.0, 0.2);
        ray.UnloadSound(beep);

        ray.SetTargetFPS(60);
        var initTime = std.time.milliTimestamp();
        while (this.running & !ray.WindowShouldClose()) {
            const op1: u16 = std.math.shl(u16, this.memory[this.pc], 8);
            const op2 = this.memory[this.pc + 1];
            const opcode = op1 ^ op2;
            this.pc += 2;
            this.ExecuteOpcode(opcode) catch |err| {
                std.log.err("op1: 0x{x:0>2}", .{op1});
                std.log.err("op2: 0x{x:0>2}", .{op2});
                std.log.err("opcode: 0x{x:0>4}", .{opcode});
                std.log.info("Program Counter: {d}", .{this.pc});
                return err;
            };

            if ((std.time.milliTimestamp() - initTime) >= 1 / 60) {
                if (this.DELAY_TIMER > 0) this.DELAY_TIMER -= 1;
                if (this.SOUND_TIMER > 0) {
                    ray.PlaySound(beep);
                    this.SOUND_TIMER -= 0;
                }
                initTime = std.time.milliTimestamp();
                this.DrawGraphics();
            }
        }
    }
};
