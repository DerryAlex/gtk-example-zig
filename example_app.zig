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
const onceInitEnter = gtk.g_once_init_enter;
const onceInitLeave = gtk.g_once_init_leave;
const objectNew = gtk.g_object_new;
const ClassInitFunc = gtk.GClassInitFunc;
const InstanceInitFunc = gtk.GInstanceInitFunc;

const ExampleAppWindow = @import("example_app_window.zig").ExampleAppWindow;

const Static = struct {
    var type_id: GType = 0;
};

const ExampleAppClass = extern struct {
    parent_class: gtk.GtkApplicationClass,
    // signal begin
    // signal end

    // class init
    pub fn init(self: *ExampleAppClass) callconv(.C) void {
        const ActivateFn = @TypeOf(@ptrCast(*gtk.GApplicationClass, self).activate);
        @ptrCast(*gtk.GApplicationClass, self).activate = @ptrCast(ActivateFn, &ExampleAppImpl.activate);
        const OpenFn = @TypeOf(@ptrCast(*gtk.GApplicationClass, self).open);
        @ptrCast(*gtk.GApplicationClass, self).open = @ptrCast(OpenFn, &ExampleAppImpl.open);
    }
};

const ExampleAppImpl = extern struct {
    parent: gtk.GtkApplication,
    // private begin
    // private end

    // override
    pub fn activate(app: ExampleApp) callconv(.C) void {
        var win = ExampleAppWindow.new(app);
        win.callMethod("present", .{});
    }

    // override
    pub fn open(app: ExampleApp, files: [*]*GFile.cType(), n_files: c_int, hint: [*:0]const u8) callconv(.C) void {
        _ = hint;
        var windows = upCast(Application, app).windows();
        var win: ExampleAppWindow = if (windows) |some| unsafeCastPtrNonNull(ExampleAppWindow, @ptrCast(*anyopaque, some.data())) else ExampleAppWindow.new(app);
        var i: usize = 0;
        while (i < n_files) : (i += 1) {
            win.open(GFile{ .instance = files[i] });
        }
        win.callMethod("present", .{});
    }

    // instance init
    pub fn init() callconv(.C) void {}

    pub fn getTypeOnce() GType {
        return gtk.g_type_register_static_simple(Application.gType(), "ExampleApp", @sizeOf(ExampleAppClass), @ptrCast(ClassInitFunc, &ExampleAppClass.init), @sizeOf(ExampleAppImpl), @ptrCast(InstanceInitFunc, &ExampleAppImpl.init), 0);
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
        if (onceInitEnter(&Static.type_id) != 0) {
            var type_id = ExampleAppImpl.getTypeOnce();
            onceInitLeave(&Static.type_id, type_id);
        }
        return Static.type_id;
    }

    pub fn hasMethod(method: []const u8) bool {
        if (Application.hasMethod(method)) return true;
        return false;
    }

    pub fn callMethod(self: ExampleApp, comptime method: []const u8, args: anytype) void {
        if (comptime Application.hasMethod(method)) {
            upCast(Application, self).callMethod(method, args);
        } else {
            @compileError("No such method");
        }
    }

    pub fn new() ExampleApp {
        const ptr = objectNew(ExampleApp.gType(), "application-id", "org.gtk.exampleapp", "flags", gtk.G_APPLICATION_HANDLES_OPEN, @as(?*anyopaque, null));
        return unsafeCastPtrNonNull(ExampleApp, ptr.?);
    }
};
