const std = @import("std");
const meta = std.meta;
const assert = std.debug.assert;
const eql = std.mem.eql;

const wrapper = @import("wrapper.zig");
const gtk = wrapper.gtk;
const GType = wrapper.GType;
const GFile = wrapper.GFile;
const ApplicationWindow = wrapper.ApplicationWindow;
const Stack = wrapper.Stack;
const ScrolledWindow = wrapper.ScrolledWindow;
const TextView = wrapper.TextView;
const upCast = wrapper.upCast;
const unsafeCastPtrNonNull = wrapper.unsafeCastPtrNonNull;
const onceInitEnter = gtk.g_once_init_enter;
const onceInitLeave = gtk.g_once_init_leave;
const objectNew = gtk.g_object_new;
const ClassInitFunc = gtk.GClassInitFunc;
const InstanceInitFunc = gtk.GInstanceInitFunc;

const ExampleApp = @import("example_app.zig").ExampleApp;

const Static = struct {
    var type_id: GType = 0;
};

const ExampleAppWindowClass = extern struct {
    parent_class: gtk.GtkApplicationWindowClass,
    // signal begin
    // signal end

    // class init
    pub fn init(self: *ExampleAppWindowClass) callconv(.C) void {
        gtk.gtk_widget_class_set_template_from_resource(@ptrCast(*gtk.GtkWidgetClass, self), "/org/gtk/exampleapp/window.ui");
        gtk.gtk_widget_class_bind_template_child_full(@ptrCast(*gtk.GtkWidgetClass, self), "stack", @boolToInt(false), @offsetOf(ExampleAppWindowImpl, "stack"));
    }
};

const ExampleAppWindowImpl = extern struct {
    parent: gtk.GtkApplicationWindow,
    // private begin
    stack: Stack,
    // private end

    // instance init
    pub fn init(win: ExampleAppWindow) callconv(.C) void {
        win.callMethod("initTemplate", .{});
    }

    pub fn getTypeOnce() GType {
        return gtk.g_type_register_static_simple(ApplicationWindow.gType(), "ExampleAppWindow", @sizeOf(ExampleAppWindowClass), @ptrCast(ClassInitFunc, &ExampleAppWindowClass.init), @sizeOf(ExampleAppWindowImpl), @ptrCast(InstanceInitFunc, &ExampleAppWindowImpl.init), 0);
    }
};

pub const ExampleAppWindow = packed struct {
    instance: *ExampleAppWindowImpl,
    classGObject: void = {},
    classGInitiallUnowned: void = {},
    classWidget: void = {},
    classWindow: void = {},
    classApplicationWindow: void = {},
    classExampleAppWindow: void = {},

    pub fn isAImpl(comptime T: type) bool {
        return meta.trait.hasField("classExampleAppWindow")(T);
    }

    pub fn cType() type {
        return ExampleAppWindowImpl;
    }

    pub fn gType() GType {
        if (onceInitEnter(&Static.type_id) != 0) {
            var type_id = ExampleAppWindowImpl.getTypeOnce();
            onceInitLeave(&Static.type_id, type_id);
        }
        return Static.type_id;
    }

    pub fn hasMethod(method: []const u8) bool {
        if (eql(u8, method, "open")) return true;
        if (ApplicationWindow.hasMethod(method)) return true;
        return false;
    }

    pub fn callMethod(self: ExampleAppWindow, comptime method: []const u8, args: anytype) void {
        if (comptime eql(u8, method, "open")) {
            comptime assert(args.len == 1);
            self.open(args[0]);
        } else if (comptime ApplicationWindow.hasMethod(method)) {
            upCast(ApplicationWindow, self).callMethod(method, args);
        } else {
            @compileError("No such method");
        }
    }

    pub fn new(app: ExampleApp) ExampleAppWindow {
        const ptr = objectNew(ExampleAppWindow.gType(), "application", app, @as(?*anyopaque, null));
        return unsafeCastPtrNonNull(ExampleAppWindow, ptr.?);
    }

    pub fn open(self: ExampleAppWindow, file: GFile) void {
        var basename = file.basename();
        var scrolled = ScrolledWindow.new();
        scrolled.callMethod("setHexpand", .{true});
        scrolled.callMethod("setVexpand", .{true});
        var view = TextView.new();
        view.setEditable(false);
        view.setCursorVisible(false);
        scrolled.setChild(view);
        _ = self.instance.stack.addTitled(scrolled, basename, basename);
        var result = file.loadContents(null);
        switch (result) {
            .Ok => {
                var buffer = view.buffer();
                buffer.setText(result.Ok.contents.ptr, @intCast(i32, result.Ok.contents.len));
                gtk.g_free(result.Ok.contents.ptr);
            },
            .Error => {
                result.Error.deinit();
            },
        }
        gtk.g_free(basename);
    }
};
