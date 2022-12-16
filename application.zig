const std = @import("std");
pub const gtk = @cImport({
    @cInclude("gtk/gtk.h");
});
const example_app = @import("example_app.zig");
const ExampleApp = example_app.ExampleApp;

pub fn main() void {
    var app = ExampleApp.new();
    app.callMethod("run", .{ @intCast(i32, std.os.argv.len), @ptrCast(?[*:null]?[*:0]u8, std.os.argv.ptr) });
}
