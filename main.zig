const std = @import("std");
const rl = @import("raylib");
const SDL = @import("SDL3.zig");
const print = std.debug.print;

var window_width: i32 = 640;
var window_height: i32 = 480;

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
    print("{}\n", .{best_format.*});
    camera = SDL.OpenCamera(devices[0], best_format); //use first device
    SDL.free(devices);
    if (camera == null) {
        SDL.Log("Couldn't open camera: %s", SDL.GetError());
        return error.NoCameraBro;
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

pub fn main() !void {
    try initCamera();
    defer SDL.Quit();
    defer SDL.CloseCamera(camera);

    var spec: SDL.CameraSpec = undefined;
    if (SDL.GetCameraFormat(camera, &spec)) {
        window_width = spec.width;
        window_height = spec.height;
    } else {
        print("FUCK: Couldnt Get Spec\n", .{});
    }

    rl.initWindow(window_width, window_height, "EPIC CAMERA MAN");
    defer rl.closeWindow();

    print("Format: {}\n", .{spec.format});
    print("FPS: {}\n", .{spec.framerate_numerator});
    var frame_texture: rl.Texture = std.mem.zeroes(rl.Texture);
    defer frame_texture.unload();
    while (!rl.windowShouldClose()) {
        handleSdlEvents();

        updateFrameTexture(&frame_texture) catch |e| {
            print("Error updating frame texture {}\n", .{e});
        };

        rl.beginDrawing();
        rl.clearBackground(rl.Color.black);

        rl.drawTexture(frame_texture, 0, 0, rl.Color.white);

        rl.endDrawing();
    }
}
