const std = @import("std");
const meta = std.meta;
const assert = std.debug.assert;
const eql = std.mem.eql;

const wrapper = @import("wrapper.zig");
const gtk = wrapper.gtk;
const GApplication = wrapper.GApplication;
const GFile = wrapper.GFile;
const GList = wrapper.GList;
const GType = wrapper.GType;
const Application = wrapper.Application;
const upCast = wrapper.upCast;
const downCast = wrapper.downCast;
const fromPtr = wrapper.fromPtr;
const unsafeCastPtrNonNull = wrapper.unsafeCastPtrNonNull;
const onceInitEnter = wrapper.onceInitEnter;
const onceInitLeave = wrapper.onceInitLeave;
const registerType = wrapper.registerType;
const ClassInitFunc = wrapper.ClassInitFunc;
const InstanceInitFunc = wrapper.InstanceInitFunc;
const GTypeFlags = wrapper.GTypeFlags;
const newObject = wrapper.newObject;

const ExampleAppWindow = @import("example_app_window.zig").ExampleAppWindow;

const Static = struct {
    var type_id: GType = 0;
};

const ExampleAppClass = extern struct {
    parent_class: gtk.GtkApplicationClass,

    pub fn init(self: *ExampleAppClass) callconv(.C) void {
        const ActivateFn = @TypeOf(@ptrCast(*gtk.GApplicationClass, self).activate);
        @ptrCast(*gtk.GApplicationClass, self).activate = @ptrCast(ActivateFn, &ExampleAppImpl.activate_override);
        const OpenFn = @TypeOf(@ptrCast(*gtk.GApplicationClass, self).open);
        @ptrCast(*gtk.GApplicationClass, self).open = @ptrCast(OpenFn, &ExampleAppImpl.open_override);
    }
};

const ExampleAppImpl = extern struct {
    parent: gtk.GtkApplication,

    pub fn activate_override(app: *ExampleApp.cType()) callconv(.C) void {
        activate(ExampleApp{ .instance = app });
    }

    pub fn activate(app: ExampleApp) void {
        var win = ExampleAppWindow.new(app);
        win.callMethod("present", .{});
    }

    pub fn open_override(app: *ExampleApp.cType(), files: [*]*GFile.cType(), n_files: c_int, hint: [*:0]const u8) callconv(.C) void {
        _ = hint;
        open(ExampleApp{ .instance = app }, @ptrCast([*]GFile, files)[0..@intCast(usize, n_files)]);
    }

    pub fn open(app: ExampleApp, files: []GFile) void {
        var windows = app.callMethod("windows", .{});
        var win: ExampleAppWindow = if (windows) |some| unsafeCastPtrNonNull(ExampleAppWindow, some.data().?) else ExampleAppWindow.new(app);
        for (files) |file| {
            win.open(file);
        }
        win.callMethod("present", .{});
    }

    pub fn init() callconv(.C) void {}

    pub fn new() ExampleApp {
        // zig fmt: off
        const ptr = newObject(
            ExampleAppImpl.gType(),
            "application-id", "org.gtk.exampleapp",
            "flags", gtk.G_APPLICATION_HANDLES_OPEN,
            @as(?*anyopaque, null)
        );
        // zig fmt: on
        return unsafeCastPtrNonNull(ExampleApp, ptr.?);
    }

    pub fn gType() GType {
        if (0 != onceInitEnter(&Static.type_id)) {
            // zig fmt: off
            var type_id = registerType(
                Application.gType(),
                "ExampleApp",
                @sizeOf(ExampleAppClass), @ptrCast(ClassInitFunc, &ExampleAppClass.init),
                @sizeOf(ExampleAppImpl), @ptrCast(InstanceInitFunc, &ExampleAppImpl.init),
                @enumToInt(GTypeFlags.None)
            );
            // zig fmt: on
            defer onceInitLeave(&Static.type_id, type_id);
        }
        return Static.type_id;
    }
};

pub const ExampleApp = packed struct {
    instance: *ExampleAppImpl,
    classGObject: void = {},
    classGApplication: void = {},
    classApplication: void = {},
    classExampleApp: void = {},
    interfaceGActionGroup: void = {},
    interfaceGActionMap: void = {},

    pub fn isAImpl(comptime T: type) bool {
        return meta.trait.hasField("classExampleApp")(T);
    }

    pub fn cType() type {
        return ExampleAppImpl;
    }

    pub fn gType() GType {
        return ExampleAppImpl.gType();
    }

    pub fn callMethodHelper(comptime method: []const u8) ?type {
        if (Application.callMethodHelper(method)) |some| return some;
        return null;
    }

    pub fn callMethod(self: ExampleApp, comptime method: []const u8, args: anytype) callMethodHelper(method).? {
        if (comptime Application.callMethodHelper(method)) |_| {
            return upCast(Application, self).callMethod(method, args);
        } else {
            @compileError("No such method");
        }
    }

    pub fn new() ExampleApp {
        return ExampleAppImpl.new();
    }
};
