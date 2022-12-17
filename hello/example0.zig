const std = @import("std");
pub const gtk = @cImport({
    @cInclude("gtk/gtk.h");
});
const wrapper = @import("wrapper.zig");

const Application = wrapper.Application;
const ApplicationWindow = wrapper.ApplicationWindow;

pub fn activate(app: Application) void {
    var window = ApplicationWindow.new(app);
    window.callMethod("setTitle", .{"Window"});
    window.callMethod("setDefaultSize", .{ 200, 200 });
    window.callMethod("show", .{});
}

pub fn main() void {
    var app = Application.new("org.gtk.example", .None);
    _ = app.callMethod("connect", .{ "activate", &activate, .{}, .{} });
    _ = app.callMethod("run", .{ @intCast(i32, std.os.argv.len), @ptrCast(?[*:null]?[*:0]u8, std.os.argv.ptr) });
    app.callMethod("unref", .{});
}
