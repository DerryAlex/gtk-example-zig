const std = @import("std");
pub const gtk = @cImport({
    @cInclude("gtk/gtk.h");
});
const wrapper = @import("wrapper.zig");

const Application = wrapper.Application;
const Builder = wrapper.Builder;
const Button = wrapper.Button;
const Window = wrapper.Window;
const unsafeCast = wrapper.unsafeCast;

pub fn printHello() void {
    std.log.info("Hello World", .{});
}

pub fn activate(app: Application) void {
    var builder = Builder.new();
    _ = builder.addFromFile("builder.ui");
    var window = unsafeCast(Window, builder.object("window").?);
    window.setApplication(app);
    var button1 = unsafeCast(Button, builder.object("button1").?);
    _ = button1.callMethod("connect", .{ "clicked", &printHello, .{}, .{ .swapped = true } });
    var button2 = unsafeCast(Button, builder.object("button2").?);
    _ = button2.callMethod("connect", .{ "clicked", &printHello, .{}, .{ .swapped = true } });
    var quit = unsafeCast(Button, builder.object("quit").?);
    _ = quit.callMethod("connect", .{ "clicked", &Window.deinit, .{window}, .{ .swapped = true } });
    window.callMethod("show", .{});
    builder.callMethod("unref", .{});
}

pub fn main() void {
    var app = Application.new("org.gtk.example", .None);
    _ = app.callMethod("connect", .{ "activate", &activate, .{}, .{} });
    _ = app.callMethod("run", .{ @intCast(i32, std.os.argv.len), @ptrCast(?[*:null]?[*:0]u8, std.os.argv.ptr) });
    app.callMethod("unref", .{});
}
