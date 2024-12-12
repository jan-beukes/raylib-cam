const std = @import("std");
const rl = @import("raylib");
const SDL = @import("SDL3.zig");
const print = std.debug.print;

var window_width: i32 = 800;
var window_height: i32 = 600;

var camera: ?*SDL.Camera = undefined;
fn initCamera() !void {
    if (!SDL.Init(SDL.INIT_CAMERA)) {
        SDL.Log("WHATTATT %s", SDL.GetError());
        return error.InitFailed;
    }
    var devcount: i32 = 0;
    const devices = SDL.GetCameras(&devcount);
    if (devices == null) {
        SDL.Log("Couldnt enumerate devices: %s", SDL.GetError());
        return error.CamerasBro;
    } else if (devcount == 0) {
        SDL.Log("Couldnt find any devices! Please connect Camera brother");
        return error.What;
    }

    var format_count: c_int = 0;
    const formats = SDL.GetCameraSupportedFormats(devices[0], &format_count);
    defer SDL.free(@ptrCast(formats));

    var max_fps: c_int = 0;
    var best_format: [*c]SDL.CameraSpec = null;
    for (0..@intCast(format_count)) |i| {
        if (formats[i].*.framerate_numerator > max_fps) {
            max_fps = formats[i].*.framerate_numerator;
            best_format = formats[i];
        }
    }

    camera = SDL.OpenCamera(devices[0], best_format); //use first device

    SDL.free(devices);
    if (camera == null) {
        SDL.Log("Couldn't open camera: %s", SDL.GetError());
        return error.NoCameraBro;
    }

    // get spec
    var spec: SDL.CameraSpec = undefined;
    if (SDL.GetCameraFormat(camera, &spec)) {
        const fwindow_width: f32 = @floatFromInt(window_width);
        const fwidth: f32 = @floatFromInt(spec.width);
        const fheight: f32 = @floatFromInt(spec.height);
        window_height = @intFromFloat((fheight / fwidth) * fwindow_width);
    }
}

fn handleSdlEvents() void {
    var e: SDL.Event = undefined;
    while (SDL.PollEvent(&e)) {
        if (e.type == SDL.EVENT_CAMERA_DEVICE_APPROVED) {
            SDL.Log("Camera use approved!");
        } else if (e.type == SDL.EVENT_CAMERA_DEVICE_DENIED) {
            SDL.Log("Camera use denied!");
        }
    }
}

fn updateFrameTexture(texture: *rl.Texture) !void {
    var timestamp_ns: u64 = 0;
    const frame = SDL.AcquireCameraFrame(camera, &timestamp_ns);
    if (frame == null) return;

    const converted_frame = SDL.ConvertSurface(frame, SDL.PIXELFORMAT_ABGR8888);
    if (converted_frame == null) return error.ConversionError;
    defer SDL.DestroySurface(converted_frame);

    const f = converted_frame.*;
    const pixels = f.pixels orelse return error.NoPixels;
    if (texture.id == 0) {
        const img: rl.Image = .{
            .width = f.w,
            .height = f.h,
            .format = .pixelformat_uncompressed_r8g8b8a8,
            .data = pixels,
            .mipmaps = 1,
        };
        texture.* = rl.loadTextureFromImage(img);
    } else {
        rl.updateTexture(texture.*, pixels);
    }

    SDL.ReleaseCameraFrame(camera, frame);
}

fn loadShaderPrograms(alloc: std.mem.Allocator, dir_path: []const u8) ![]rl.Shader {
    const dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    var dir_itter = dir.iterate();

    var paths = std.ArrayList(rl.Shader).init(alloc);

    while (try dir_itter.next()) |file| {
        var path_buffer: [1024]u8 = undefined;
        const abs_path = try dir.realpath(file.name, &path_buffer);
        const abs_path_sent: [:0]u8 = try std.mem.concatWithSentinel(alloc, u8, &.{abs_path}, 0);
        defer alloc.free(abs_path_sent);

        const shader = rl.loadShader(null, abs_path_sent);
        try paths.append(shader);
    }

    return try paths.toOwnedSlice();
}

pub fn main() !void {
    const alloc = std.heap.c_allocator;
    try initCamera();
    defer SDL.Quit();
    defer SDL.CloseCamera(camera);

    rl.setTraceLogLevel(.log_warning);
    rl.initWindow(window_width, window_height, "EPIC CAMERA MAN");
    defer rl.closeWindow();

    // Shaders
    const shaders: []rl.Shader = try loadShaderPrograms(alloc, "shaders");
    defer alloc.free(shaders);

    var frame_texture: rl.Texture = std.mem.zeroes(rl.Texture);
    defer frame_texture.unload();
    while (!rl.windowShouldClose()) {
        handleSdlEvents();

        updateFrameTexture(&frame_texture) catch |e| {
            print("Error updating frame texture {}\n", .{e});
        };

        const time: usize = @intFromFloat(rl.getTime());
        const shader_index: usize = ((time / 5) % shaders.len);
        const rem = @rem(rl.getTime(), 5);

        rl.beginDrawing();
        rl.clearBackground(rl.Color.black);

        shaders[shader_index].activate();
        const source = rl.Rectangle{ .x = 0, .y = 0, .width = @floatFromInt(frame_texture.width), .height = @floatFromInt(frame_texture.height) };
        const dest = rl.Rectangle{ .x = 0, .y = 0, .width = @floatFromInt(window_width), .height = @floatFromInt(window_height) };
        frame_texture.drawPro(source, dest, rl.Vector2.zero(), 0, rl.Color.white);
        shaders[shader_index].deactivate();

        const radius = 40.0;
        const center = rl.Vector2{ .x = 10 + radius, .y = 50 + radius };
        rl.drawCircleSector(center, radius, 0, @as(f32, @floatCast(rem)) * 360 / 5, 30, rl.Color.blue);

        var buff: [128]u8 = undefined;
        rl.drawText(try std.fmt.bufPrintZ(&buff, "Shader: {}", .{shader_index}), 10, 10, 32, rl.Color.blue);

        rl.endDrawing();
    }
}
