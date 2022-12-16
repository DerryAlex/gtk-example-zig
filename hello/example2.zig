const std = @import("std");
pub const gtk = @cImport({
    @cInclude("gtk/gtk.h");
});
const wrapper = @import("wrapper.zig");

const Application = wrapper.Application;
const ApplicationWindow = wrapper.ApplicationWindow;
const Button = wrapper.Button;
const Grid = wrapper.Grid;
const upCast = wrapper.upCast;

pub fn printHello() void {
    std.log.info("Hello World", .{});
}

pub fn applicationWindowDestroy(window: ApplicationWindow) void {
    window.callMethod("destroy", .{});
}

pub fn activate(app: Application) void {
    var window = ApplicationWindow.new(app);
    window.callMethod("setTitle", .{"Window"});
    var grid = Grid.new();
    window.callMethod("setChild", .{grid});
    var button1 = Button.newWithLabel("Button 1");
    button1.callMethod("connect", .{ "clicked", &printHello, .{}, .{ .swapped = true } });
    grid.attach(button1, 0, 0, 1, 1);
    var button2 = Button.newWithLabel("Button 2");
    button2.callMethod("connect", .{ "clicked", &printHello, .{}, .{ .swapped = true } });
    grid.attach(button2, 1, 0, 1, 1);
    var quit = Button.newWithLabel("Quit");
    quit.callMethod("connect", .{ "clicked", &applicationWindowDestroy, .{window}, .{ .swapped = true } });
    grid.attach(quit, 0, 1, 2, 1);
    window.callMethod("show", .{});
}

pub fn main() void {
    var app = Application.new("org.gtk.example", .None);
    app.callMethod("connect", .{ "activate", &activate, .{}, .{} });
    app.callMethod("run", .{ @intCast(i32, std.os.argv.len), @ptrCast(?[*:null]?[*:0]u8, std.os.argv.ptr) });
    app.callMethod("unref", .{});
}
