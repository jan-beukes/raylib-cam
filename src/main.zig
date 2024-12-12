const std = @import("std");
const rl = @import("raylib");
const cam = @import("camera.zig");
const print = std.debug.print;

var window_width: i32 = 800;
var window_height: i32 = 600;

const FragShader = struct {
    shader: rl.Shader,
    name: [:0]const u8,
    alloc: ?std.mem.Allocator,

    pub fn init(allocator: ?std.mem.Allocator, path: ?[*:0]u8) FragShader {
        const file_name = rl.getFileName(path orelse "Default");
        const len = std.mem.len(file_name);
        var name: [:0]const u8 = @ptrCast(file_name[0..len]);
        if (allocator) |alloc| {
            // allocate name
            if (alloc.allocSentinel(u8, len, 0)) |alloc_name| {
                std.mem.copyForwards(u8, alloc_name, file_name[0..len]);
                name = alloc_name;
            } else |err| {
                print("Couldnt allocate for shader name: {}\n", .{err});
            }
        }
        return FragShader{
            .shader = rl.loadShader(null, path),
            .name = name,
            .alloc = allocator,
        };
    }
    pub fn deinit(self: FragShader) void {
        if (self.alloc) |alloc| alloc.free(self.name);
        rl.unloadShader(self.shader);
    }
};

fn loadShaderPrograms(alloc: std.mem.Allocator, dir_path: []const u8) ![]FragShader {
    const dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    var dir_itter = dir.iterate();

    var shaders = std.ArrayList(FragShader).init(alloc);
    const default_shader = FragShader.init(null, null);
    try shaders.append(default_shader);

    while (try dir_itter.next()) |file| {
        var path_buffer: [1024]u8 = undefined;
        const abs_path = try dir.realpath(file.name, &path_buffer);
        const abs_path_sent: [:0]u8 = try std.mem.concatWithSentinel(alloc, u8, &.{abs_path}, 0);
        defer alloc.free(abs_path_sent);

        const shader = FragShader.init(alloc, abs_path_sent);
        try shaders.append(shader);
    }

    return try shaders.toOwnedSlice();
}

pub fn main() !void {
    const alloc = std.heap.c_allocator;
    try cam.init(&window_height, window_width);
    defer cam.denit();

    rl.setTraceLogLevel(.log_warning);
    rl.initWindow(window_width, window_height, "EPIC CAMERA MAN");
    defer rl.closeWindow();

    // Shaders
    const shaders: []FragShader = try loadShaderPrograms(alloc, "shaders");
    var custom = true;
    var shader_index: usize = 0;
    defer {
        for (shaders) |s| s.deinit();
        alloc.free(shaders);
    }

    const custom_shader = rl.loadShader(null, "custom-shaders/edge.fs");
    const thresh_loc = rl.getShaderLocation(custom_shader, "thresh");

    var edge_thresh: f32 = 0.50;
    rl.setShaderValue(custom_shader, thresh_loc, &edge_thresh, .shader_uniform_float);

    var frame_texture: rl.Texture = std.mem.zeroes(rl.Texture);
    defer frame_texture.unload();
    var current_shader = shaders[shader_index].shader;
    while (!rl.windowShouldClose()) {
        cam.handleEvents();

        cam.updateFrameTexture(&frame_texture) catch |e| {
            print("Error updating frame texture {}\n", .{e});
        };

        if (rl.isKeyPressed(.key_space)) custom = !custom;
        if (custom) {
            const move = rl.getMouseWheelMove() * 0.01;
            edge_thresh = std.math.clamp(edge_thresh + move, 0, 1);
            rl.setShaderValue(custom_shader, thresh_loc, &edge_thresh, .shader_uniform_float);

            current_shader = custom_shader;
        } else {
            if (rl.isMouseButtonPressed(.mouse_button_left)) {
                shader_index = (shader_index + 1) % shaders.len;
            } else if (rl.isMouseButtonPressed(.mouse_button_right)) {
                shader_index = @mod((shader_index + shaders.len - 1), shaders.len);
            }
            current_shader = shaders[shader_index].shader;
        }

        rl.beginDrawing();
        rl.clearBackground(rl.Color.black);

        // Frame Texture
        current_shader.activate();
        const source = rl.Rectangle{ .x = 0, .y = 0, .width = @floatFromInt(frame_texture.width), .height = @floatFromInt(frame_texture.height) };
        const dest = rl.Rectangle{ .x = 0, .y = 0, .width = @floatFromInt(window_width), .height = @floatFromInt(window_height) };
        frame_texture.drawPro(source, dest, rl.Vector2.zero(), 0, rl.Color.white);
        current_shader.deactivate();

        // UI
        const text = if (custom) "Custom" else rl.textFormat("%ld %s", .{ shader_index, rl.getFileNameWithoutExt(shaders[shader_index].name) });
        rl.drawText(text, 10, 10, 32, rl.Color.blue);
        rl.drawText(rl.textFormat("Thresh: %.2f", .{edge_thresh}), 10, 50, 32, rl.Color.blue);

        rl.endDrawing();
    }
}
