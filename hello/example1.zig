const std = @import("std");
pub const gtk = @cImport({
    @cInclude("gtk/gtk.h");
});
const wrapper = @import("wrapper.zig");

const Application = wrapper.Application;
const ApplicationWindow = wrapper.ApplicationWindow;
const Box = wrapper.Box;
const Button = wrapper.Button;
const Window = wrapper.Window;
const upCast = wrapper.upCast;

pub fn printHello() void {
    std.log.info("Hello World", .{});
}

pub fn activate(app: Application) void {
    var window = ApplicationWindow.new(app);
    window.callMethod("setTitle", .{"Window"});
    window.callMethod("setDefaultSize", .{ 200, 200 });
    var box = Box.new(.Vertical, 0);
    box.callMethod("setHalign", .{.Center});
    box.callMethod("setValign", .{.Center});
    window.callMethod("setChild", .{box});
    var button = Button.newWithLabel("Hello World");
    button.callMethod("connect", .{ "clicked", &printHello, .{}, .{ .swapped = true } });
    button.callMethod("connect", .{ "clicked", &Window.deinit, .{upCast(Window, window)}, .{ .swapped = true } });
    box.append(button);
    window.callMethod("show", .{});
}

pub fn main() void {
    var app = Application.new("org.gtk.example", .None);
    app.callMethod("connect", .{ "activate", &activate, .{}, .{} });
    app.callMethod("run", .{ @intCast(i32, std.os.argv.len), @ptrCast(?[*:null]?[*:0]u8, std.os.argv.ptr) });
    app.callMethod("unref", .{});
}
