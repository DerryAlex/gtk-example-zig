const std = @import("std");
const meta = std.meta;
const assert = std.debug.assert;
const eql = std.mem.eql;

pub const gtk = @import("root").gtk;

// cast helper begin
pub fn isA(comptime T: type) meta.trait.TraitFn {
    return T.isAImpl;
}

pub fn upCast(comptime T: type, object: anytype) T {
    const U = @TypeOf(object);
    comptime assert(isA(GObject)(T) and isA(GObject)(U));
    comptime assert(isA(T)(U));
    return T{ .instance = @ptrCast(*T.cType(), @alignCast(@alignOf(*T.cType()), object.instance)) };
}

pub fn downCast(comptime T: type, object: anytype) ?T {
    const U = @TypeOf(object);
    comptime assert(isA(GObject)(T) and isA(GObject)(U));
    comptime assert(isA(U)(T));
    if (0 == gtk.g_type_check_instance_is_a(@ptrCast(*gtk.GTypeInstance, object.instance), T.gType())) return null;
    return T{ .instance = @ptrCast(*T.cType(), @alignCast(@alignOf(*T.cType()), object.instance)) };
}

pub fn dynamicCast(comptime T: type, object: anytype) ?T {
    const U = @TypeOf(object);
    comptime assert(isA(GObject)(T) and isA(GObject)(U));
    if (0 == gtk.g_type_check_instance_is_a(@ptrCast(*gtk.GTypeInstance, object.instance), T.gType())) return null;
    return T{ .instance = @ptrCast(*T.cType(), @alignCast(@alignOf(*T.cType()), object.instance)) };
}

pub fn unsafeCast(comptime T: type, object: anytype) T {
    const U = @TypeOf(object);
    comptime assert(isA(GObject)(T) and isA(GObject)(U));
    return T{ .instance = @ptrCast(*T.cType(), @alignCast(@alignOf(*T.cType()), object.instance)) };
}

pub fn fromPtr(comptime T: type, ptr: ?*T.cType()) ?T {
    return if (ptr) |some| T{ .instance = some } else null;
}

pub fn toPtr(comptime T: type, self: ?T) ?*T.cType() {
    return if (self) |some| some.instance else null;
}

pub fn unsafeCastPtr(comptime T: type, ptr: ?*anyopaque) ?T {
    return if (ptr) |some| T{ .instance = @ptrCast(*T.cType(), @alignCast(@alignOf(*T.cType()), some)) } else null;
}

pub fn unsafeCastPtrNonNull(comptime T: type, ptr: *anyopaque) T {
    return T{ .instance = @ptrCast(*T.cType(), @alignCast(@alignOf(*T.cType()), ptr)) };
}
// cast helper end

// closure helper begin
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

fn ZigClosure(comptime T: type, comptime U: type, comptime swapped: bool) type {
    comptime assert(meta.trait.isPtrTo(.Fn)(T));

    return struct {
        func: T,
        args: U,

        const Self = @This();

        pub usingnamespace if (swapped) struct {
            pub fn invoke(self: *Self, object: GObject) callconv(.C) void {
                _ = object;
                @call(.{}, self.func, self.args);
            }
        } else struct {
            const ObjectType = @typeInfo(meta.ArgsTuple(meta.Child(T))).Struct.fields[0].field_type;
            pub fn invoke(object: GObject, self: *Self) callconv(.C) void {
                @call(.{}, self.func, .{downCast(ObjectType, object).?} ++ self.args);
            }
        };

        pub fn deinit(self: *Self, closure: *GClosure) callconv(.C) void {
            _ = closure;
            const allocator = gpa.allocator();
            allocator.destroy(self);
        }
    };
}

fn createZigClosure(func: anytype, args: anytype, comptime swapped: bool) *ZigClosure(@TypeOf(func), @TypeOf(args), swapped) {
    const allocator = gpa.allocator();
    const Closure = ZigClosure(@TypeOf(func), @TypeOf(args), swapped);
    const closure = allocator.create(Closure) catch @panic("Out Of Memory");
    closure.func = func;
    closure.args = args;
    return closure;
}
// closure helper end

// custom widget
pub const onceInitEnter = gtk.g_once_init_enter;
pub const onceInitLeave = gtk.g_once_init_leave;
pub const registerType = gtk.g_type_register_static_simple;
pub const registerTypeStatic = gtk.g_type_register_static;
pub const registerTypeDynamic = gtk.g_gtype_register_dynamic;
pub const registerTypeFundamental = gtk.g_type_register_fundemantal;
pub const ClassInitFunc = gtk.GClassInitFunc;
pub const InstanceInitFunc = gtk.GInstanceInitFunc;
pub const newObject = gtk.g_object_new;
// custom widget

pub const GApplicationFlags = enum(c_uint) {
    None = gtk.G_APPLICATION_FLAGS_NONE,
    IsService = gtk.G_APPLICATION_IS_SERVICE,
    IsLauncher = gtk.G_APPLICATION_IS_LAUNCHER,
    HandlesOpen = gtk.G_APPLICATION_HANDLES_OPEN,
    HandlesCommandLine = gtk.G_APPLICATION_HANDLES_COMMAND_LINE,
    SendEnvironment = gtk.G_APPLICATION_SEND_ENVIRONMENT,
    NonUnique = gtk.G_APPLICATION_NON_UNIQUE,
    CanOverrideAppId = gtk.G_APPLICATION_CAN_OVERRIDE_APP_ID,
    AllowReplacement = gtk.G_APPLICATION_ALLOW_REPLACEMENT,
    Replace = gtk.G_APPLICATION_REPLACE,
    _,
};

pub const GConnectFlags = enum(c_uint) {
    Default = gtk.G_CONNECT_DEFAULT,
    After = gtk.G_CONNECT_AFTER,
    Swapped = gtk.G_CONNECT_SWAPPED,
    _,
};

pub const GTypeFlags = enum(c_uint) {
    None = gtk.G_TYPE_FLAG_NONE,
    Abstract = gtk.G_TYPE_FLAG_ABSTRACT,
    ValueAbstract = gtk.G_TYPE_FLAG_VALUE_ABSTRACT,
    Final = gtk.G_TYPE_FLAG_FINAL,
};

pub const Align = enum(c_uint) {
    Fill = gtk.GTK_ALIGN_FILL,
    Start = gtk.GTK_ALIGN_START,
    End = gtk.GTK_ALIGN_END,
    Center = gtk.GTK_ALIGN_CENTER,
    Baseline = gtk.GTK_ALIGN_BASELINE,
};

pub const Orientation = enum(c_uint) {
    Horizontal = gtk.GTK_ORIENTATION_HORIZONTAL,
    Vertical = gtk.GTK_ORIENTATION_VERTICAL,
};

pub const GCallback = *const fn () callconv(.C) void;
pub const GClosure = gtk.GClosure;
pub const GClosureNotify = *const fn (?*anyopaque, ?*GClosure) callconv(.C) void;
pub const GType = gtk.GType;

pub const GError = packed struct {
    instance: *gtk.GError,

    pub fn cType() type {
        return gtk.GError;
    }

    pub fn gType() GType {
        return gtk.g_error_get_type();
    }

    pub const deinit = free;

    pub fn free(self: GError) void {
        gtk.g_error_free(self.instance);
    }
};

pub const GFile = packed struct {
    instance: *gtk.GFile,

    pub fn cType() type {
        return gtk.GFile;
    }

    pub fn gType() GType {
        return gtk.g_file_get_type();
    }

    pub fn basename(self: GFile) [*:0]u8 {
        return gtk.g_file_get_basename(self.instance);
    }

    pub fn loadContents(self: GFile, cancellable: ?GCancellable) union(enum) {
        Ok: Ok,
        Err: Err,

        const Ok = struct {
            contents: []u8,
            etag: ?[*:0]u8,
        };

        const Err = GError;
    } {
        var contents: ?[*]u8 = null;
        var length: usize = 0;
        var etag: ?[*:0]u8 = null;
        var error_instance: ?*GError.cType() = null;
        return if (0 == gtk.g_file_load_contents(self.instance, toPtr(GCancellable, cancellable), &contents, &length, &etag, &error_instance)) .{ .Err = fromPtr(GError, error_instance).? } else .{ .Ok = .{ .contents = contents.?[0..length], .etag = etag } };
    }
};

pub const GList = packed struct {
    instance: *gtk.GList,

    pub fn cType() type {
        return gtk.GList;
    }

    pub fn gType() GType {
        return gtk.g_list_get_type();
    }

    pub fn data(self: GList) ?*anyopaque {
        return self.instance.data;
    }
};

pub const GObject = packed struct {
    instance: *gtk.GObject,
    // ancestors and interfaces
    classGObject: void = {},

    pub fn isAImpl(comptime T: type) bool {
        return meta.trait.hasField("classGObject")(T);
    }

    pub fn cType() type {
        return gtk.GObject;
    }

    pub fn gType() GType {
        return gtk.g_object_get_type();
    }

    pub fn callMethodHelper(comptime method: []const u8) ?type {
        if (eql(u8, method, "connect")) return usize;
        if (eql(u8, method, "unref")) return void;
        return null;
    }

    pub fn callMethod(self: GObject, comptime method: []const u8, args: anytype) callMethodHelper(method).? {
        if (comptime eql(u8, method, "connect")) {
            comptime assert(args.len == 4);
            return self.connect(args[0], args[1], args[2], args[3]);
        } else if (comptime eql(u8, method, "unref")) {
            comptime assert(args.len == 0);
            self.unref();
        } else {
            @compileError("No such method");
        }
    }

    pub const deinit = unref;

    /// Connect a callback function to a signal for a particular object.
    /// `handler` should be a function pointer `*const fn(GObject, args...)`
    /// The first argument of `handler` is the object. To remove this, set `flags.swapped` to `true`.
    /// The type is allowed to be any class type inherited from GObject.
    /// If the handler should be called after the default handler, set `flags.after` to `true`
    pub fn connect(self: GObject, signal: [*:0]const u8, comptime handler: anytype, args: anytype, comptime flags: struct {
        after: bool = false,
        swapped: bool = false,
    }) usize {
        var closure = createZigClosure(handler, args, flags.swapped);
        const Closure = meta.Child(@TypeOf(closure));
        comptime var gflags = @enumToInt(GConnectFlags.Default);
        comptime {
            if (flags.after) {
                gflags |= @enumToInt(GConnectFlags.After);
            }
            if (flags.swapped) {
                gflags |= @enumToInt(GConnectFlags.Swapped);
            }
        }
        return self.signalConnectData(signal, @ptrCast(GCallback, &Closure.invoke), closure, @ptrCast(GClosureNotify, &Closure.deinit), @intToEnum(GConnectFlags, gflags));
    }

    fn signalConnectData(self: GObject, signal: [*:0]const u8, comptime c_handler: GCallback, data: ?*anyopaque, comptime destroy_data: ?GClosureNotify, flags: GConnectFlags) usize {
        return @intCast(usize, gtk.g_signal_connect_data(self.instance, signal, c_handler, data, destroy_data, @enumToInt(flags)));
    }

    pub fn unref(self: GObject) void {
        gtk.g_object_unref(self.instance);
    }
};

pub const GApplication = packed struct {
    instance: *gtk.GApplication,
    classGObject: void = {},
    classGApplication: void = {},
    interfaceGActionGroup: void = {},
    interfaceGActionMap: void = {},

    pub fn isAImpl(comptime T: type) bool {
        return meta.trait.hasField("classGApplication")(T);
    }

    pub fn cType() type {
        return gtk.GApplication;
    }

    pub fn gType() GType {
        return gtk.g_application_get_type();
    }

    pub fn callMethodHelper(comptime method: []const u8) ?type {
        if (eql(u8, method, "run")) return i32;
        if (GObject.callMethodHelper(method)) |some| return some;
        return null;
    }

    pub fn callMethod(self: GApplication, comptime method: []const u8, args: anytype) callMethodHelper(method).? {
        if (comptime eql(u8, method, "run")) {
            comptime assert(args.len == 2);
            return self.run(args[0], args[1]);
        } else if (comptime GObject.callMethodHelper(method)) |_| {
            return upCast(GObject, self).callMethod(method, args);
        } else {
            @compileError("No such method");
        }
    }

    pub fn run(self: GApplication, argc: i32, argv: ?[*:null]?[*:0]u8) i32 {
        return @intCast(i32, gtk.g_application_run(self.instance, @intCast(c_int, argc), @ptrCast([*c][*c]u8, argv)));
    }
};

pub const GCancellable = packed struct {
    instance: *gtk.GCancellable,
    classGObject: void = {},
    classGCancellable: void = {},

    pub fn isAImpl(comptime T: type) bool {
        return meta.trait.hasField("classGCancellable")(T);
    }

    pub fn cType() type {
        return gtk.GCancellable;
    }

    pub fn gType() GType {
        return gtk.g_cancellable_get_type();
    }

    pub fn callMethodHelper(comptime method: []const u8) ?type {
        if (GObject.callMethodHelper(method)) |some| return some;
        return null;
    }

    pub fn callMethod(self: GCancellable, comptime method: []const u8, args: anytype) callMethodHelper(method).? {
        if (comptime GObject.callMethodHelper(method)) |_| {
            return upCast(GObject, self).callMethod(method, args);
        } else {
            @compileError("No such method");
        }
    }
};

pub const GInitiallyUnowned = packed struct {
    instance: *gtk.GInitiallyUnowned,
    classGObject: void = {},
    classGInitiallyUnowned: void = {},

    pub fn isAImpl(comptime T: type) bool {
        return meta.trait.hasField("classGInitiallyUnowned")(T);
    }

    pub fn cType() type {
        return gtk.GInitiallyUnowned;
    }

    pub fn gType() GType {
        return gtk.g_initially_unowned_get_type();
    }

    pub fn callMethodHelper(comptime method: []const u8) ?type {
        if (GObject.callMethodHelper(method)) |some| return some;
        return null;
    }

    pub fn callMethod(self: GInitiallyUnowned, comptime method: []const u8, args: anytype) callMethodHelper(method).? {
        if (comptime GObject.callMethodHelper(method)) |_| {
            return upCast(GObject, self).callMethod(method, args);
        } else {
            @compileError("No such method");
        }
    }
};

pub const Application = packed struct {
    instance: *gtk.GtkApplication,
    classGObject: void = {},
    classGApplication: void = {},
    classApplication: void = {},
    interfaceGActionGroup: void = {},
    interfaceGActionMap: void = {},

    pub fn isAImpl(comptime T: type) bool {
        return meta.trait.hasField("classApplication")(T);
    }

    pub fn cType() type {
        return gtk.GtkApplication;
    }

    pub fn gType() GType {
        return gtk.gtk_application_get_type();
    }

    pub fn callMethodHelper(comptime method: []const u8) ?type {
        if (eql(u8, method, "windows")) return ?GList;
        if (GApplication.callMethodHelper(method)) |some| return some;
        return null;
    }

    pub fn callMethod(self: Application, comptime method: []const u8, args: anytype) callMethodHelper(method).? {
        if (comptime eql(u8, method, "windows")) {
            comptime assert(args.len == 0);
            return self.windows();
        } else if (comptime GApplication.callMethodHelper(method)) |_| {
            return upCast(GApplication, self).callMethod(method, args);
        } else {
            @compileError("No such method");
        }
    }

    pub fn new(application_id: ?[*:0]const u8, flags: GApplicationFlags) Application {
        return Application{ .instance = gtk.gtk_application_new(application_id, @enumToInt(flags)) };
    }

    pub fn windows(self: Application) ?GList {
        return fromPtr(GList, gtk.gtk_application_get_windows(self.instance));
    }
};

pub const ApplicationWindow = packed struct {
    instance: *gtk.GtkApplicationWindow,
    classGObject: void = {},
    classGInitiallyUnowned: void = {},
    classWidget: void = {},
    classWindow: void = {},
    classApplicationWindow: void = {},
    interfaceGActionGroup: void = {},
    interfaceGActionMap: void = {},
    interfaceAccessible: void = {},
    interfaceBuildable: void = {},
    interfaceConstraintTarget: void = {},
    interfaceNative: void = {},
    interfaceRoot: void = {},
    interfaceShortcutManager: void = {},

    pub fn isAImpl(comptime T: type) bool {
        return meta.trait.hasField("classApplicationWindow")(T);
    }

    pub fn cType() type {
        return gtk.GtkApplicationWindow;
    }

    pub fn gType() GType {
        return gtk.gtk_application_window_get_type();
    }

    pub fn callMethodHelper(comptime method: []const u8) ?type {
        if (Window.callMethodHelper(method)) |some| return some;
        return null;
    }

    pub fn callMethod(self: ApplicationWindow, comptime method: []const u8, args: anytype) callMethodHelper(method).? {
        if (comptime Window.callMethodHelper(method)) |_| {
            return upCast(Window, self).callMethod(method, args);
        } else {
            @compileError("No such method");
        }
    }

    pub fn new(application: Application) ApplicationWindow {
        return ApplicationWindow{ .instance = @ptrCast(*ApplicationWindow.cType(), gtk.gtk_application_window_new(application.instance)) };
    }
};

pub const Box = packed struct {
    instance: *gtk.GtkBox,
    classGObject: void = {},
    classGInitiallyUnowned: void = {},
    classWidget: void = {},
    classBox: void = {},
    interfaceAccessible: void = {},
    interfaceBuildable: void = {},
    interfaceConstrainTarget: void = {},
    interfaceOrientable: void = {},

    pub fn isAImpl(comptime T: type) bool {
        return meta.trait.hasField("classBox")(T);
    }

    pub fn cType() type {
        return gtk.GtkBox;
    }

    pub fn gType() GType {
        return gtk.gtk_box_get_type();
    }

    pub fn callMethodHelper(comptime method: []const u8) ?type {
        if (eql(u8, method, "append")) return void;
        if (Widget.callMethodHelper(method)) |some| return some;
        return null;
    }

    pub fn callMethod(self: Box, comptime method: []const u8, args: anytype) callMethodHelper(method).? {
        if (comptime eql(u8, method, "append")) {
            comptime assert(args.len == 1);
            self.append(args[0]);
        } else if (comptime Widget.callMethodHelper(method)) |_| {
            return upCast(Widget, self).callMethod(method, args);
        } else {
            @compileError("No such method");
        }
    }

    pub fn new(orientation: Orientation, spacing: i32) Box {
        return Box{ .instance = @ptrCast(*Box.cType(), gtk.gtk_box_new(@enumToInt(orientation), @bitCast(c_int, spacing))) };
    }

    pub fn append(self: Box, child: anytype) void {
        gtk.gtk_box_append(self.instance, upCast(Widget, child).instance);
    }
};

pub const Builder = packed struct {
    instance: *gtk.GtkBuilder,
    classGObject: void = {},
    classBuilder: void = {},

    pub fn isAImpl(comptime T: type) bool {
        return meta.trait.hasField("classBuilder")(T);
    }

    pub fn cType() type {
        return gtk.GtkBuilder;
    }

    pub fn gType() GType {
        return gtk.gtk_builder_get_type();
    }

    pub fn callMethodHelper(comptime method: []const u8) ?type {
        if (eql(u8, method, "addFromFile")) return ?GError;
        if (eql(u8, method, "object")) return ?GObject;
        if (GObject.callMethodHelper(method)) |some| return some;
        return null;
    }

    pub fn callMethod(self: Builder, comptime method: []const u8, args: anytype) callMethodHelper(method).? {
        if (comptime eql(u8, method, "addFromFile")) {
            comptime assert(args.len == 1);
            return self.addFromFile(args[0]);
        } else if (comptime eql(u8, method, "object")) {
            comptime assert(args.len == 2);
            return self.object(args[0], args[1]);
        } else if (comptime GObject.callMethodHelper(method)) |_| {
            return upCast(GObject, self).callMethod(method, args);
        } else {
            @compileError("No such method");
        }
    }

    pub fn new() Builder {
        return Builder{ .instance = gtk.gtk_builder_new().? };
    }

    pub fn addFromFile(self: Builder, filename: [*:0]const u8) ?GError {
        var error_instance: ?*GError.cType() = null;
        return if (0 == gtk.gtk_builder_add_from_file(self.instance, filename, &error_instance)) fromPtr(GError, error_instance).? else null;
    }

    pub fn object(self: Builder, name: [*:0]const u8) ?GObject {
        return fromPtr(GObject, gtk.gtk_builder_get_object(self.instance, name));
    }
};

pub const Button = packed struct {
    instance: *gtk.GtkButton,
    classGObject: void = {},
    classGInitiallyUnowned: void = {},
    classWidget: void = {},
    classButton: void = {},
    interfaceAccessible: void = {},
    interfaceActionable: void = {},
    interfaceBuildable: void = {},
    interfaceConstrainTarget: void = {},

    pub fn isAImpl(comptime T: type) bool {
        return meta.trait.hasField("classButton")(T);
    }

    pub fn cType() type {
        return gtk.GtkButton;
    }

    pub fn gType() GType {
        return gtk.gtk_button_get_type();
    }

    pub fn callMethodHelper(comptime method: []const u8) ?type {
        if (Widget.callMethodHelper(method)) |some| return some;
        return null;
    }

    pub fn callMethod(self: Button, comptime method: []const u8, args: anytype) callMethodHelper(method).? {
        if (comptime Widget.callMethodHelper(method)) |_| {
            return upCast(Widget, self).callMethod(method, args);
        } else {
            @compileError("No such method");
        }
    }

    pub fn newWithLabel(label: [*:0]const u8) Button {
        return Button{ .instance = @ptrCast(*Button.cType(), gtk.gtk_button_new_with_label(label)) };
    }
};

pub const Grid = packed struct {
    instance: *gtk.GtkGrid,
    classGObject: void = {},
    classGInitiallyUnowned: void = {},
    classWidget: void = {},
    classGrid: void = {},
    interfaceAccessible: void = {},
    interfaceBuildable: void = {},
    interfaceConstrainTarget: void = {},
    interfaceOrientable: void = {},

    pub fn isAImpl(comptime T: type) bool {
        return meta.trait.hasField("classGrid")(T);
    }

    pub fn cType() type {
        return gtk.GtkGrid;
    }

    pub fn gType() GType {
        return gtk.gtk_grid_get_type();
    }

    pub fn callMethodHelper(comptime method: []const u8) ?type {
        if (eql(u8, method, "attach")) return void;
        if (Widget.callMethodHelper(method)) |some| return some;
        return null;
    }

    pub fn callMethod(self: Grid, comptime method: []const u8, args: anytype) callMethodHelper(method).? {
        if (comptime eql(u8, method, "attach")) {
            comptime assert(args.len == 5);
            self.attach(args[0], args[1], args[2], args[3], args[4]);
        } else if (comptime Widget.callMethodHelper(method)) |_| {
            upCast(Widget, self).callMethod(method, args);
        } else {
            @compileError("No such method");
        }
    }

    pub fn new() Grid {
        return Grid{ .instance = @ptrCast(*Grid.cType(), gtk.gtk_grid_new()) };
    }

    pub fn attach(self: Grid, child: anytype, column: i32, row: i32, width: i32, height: i32) void {
        gtk.gtk_grid_attach(self.instance, upCast(Widget, child).instance, @intCast(c_int, column), @intCast(c_int, row), @intCast(c_int, width), @intCast(c_int, height));
    }
};

pub const Stack = packed struct {
    instance: *gtk.GtkStack,
    classGObject: void = {},
    classGInitiallyUnowned: void = {},
    classWidget: void = {},
    classStack: void = {},
    interfaceAccessible: void = {},
    interfaceBuildable: void = {},
    interfaceConstraintTarget: void = {},

    pub fn isAImpl(comptime T: type) bool {
        return meta.trait.hasField("classStack")(T);
    }

    pub fn cType() type {
        return gtk.GtkStack;
    }

    pub fn gType() GType {
        return gtk.gtk_stack_get_type();
    }

    pub fn callMethodHelper(comptime method: []const u8) ?type {
        if (eql(u8, method, "addTitled")) return StackPage;
        if (Widget.callMethodHelper(method)) |some| return some;
        return null;
    }

    pub fn callMethod(self: Stack, comptime method: []const u8, args: anytype) callMethodHelper(method).? {
        if (comptime eql(u8, method, "addTitlde")) {
            comptime assert(args.len == 3);
            return self.addTitled(args[0], args[1], args[2]);
        } else if (comptime Widget.callMethodHelper(method, args)) |_| {
            return upCast(Widget, self).callMethod(method);
        } else {
            @compileError("No such method");
        }
    }

    pub fn addTitled(self: Stack, child: anytype, name: ?[*:0]const u8, title: [*:0]const u8) StackPage {
        return StackPage{ .instance = gtk.gtk_stack_add_titled(self.instance, upCast(Widget, child).instance, name, title).? };
    }
};

pub const StackPage = packed struct {
    instance: *gtk.GtkStackPage,
    classGObject: void = {},
    classStackPage: void = {},
    interfaceAccessible: void = {},

    pub fn isAImpl(comptime T: type) bool {
        return meta.trait.hasField("classStackPage")(T);
    }

    pub fn cType() type {
        return gtk.GtkStackPage;
    }

    pub fn gType() GType {
        return gtk.gtk_stack_page_get_type();
    }

    pub fn callMethodHelper(comptime method: []const u8) ?type {
        if (GObject.callMethodHelper(method)) |some| return some;
        return null;
    }

    pub fn callMethod(self: StackPage, comptime method: []const u8, args: anytype) callMethodHelper(method).? {
        if (comptime GObject.callMethodHelper(method)) |_| {
            return upCast(GObject, self).callMethod(method, args);
        } else {
            @compileError("No such method");
        }
    }
};

pub const ScrolledWindow = packed struct {
    instance: *gtk.GtkScrolledWindow,
    classGObject: void = {},
    classGInitiallyUnowned: void = {},
    classWidget: void = {},
    classScrolledWindow: void = {},
    interfaceAccessible: void = {},
    interfaceBuildable: void = {},
    interfaceConstraintTarget: void = {},

    pub fn isAImpl(comptime T: type) bool {
        return meta.trait.hasField("classScrolledWindow")(T);
    }

    pub fn cType() type {
        return gtk.GtkScrolledWindow;
    }

    pub fn gType() GType {
        return gtk.gtk_scrolled_window_get_type();
    }

    pub fn callMethodHelper(comptime method: []const u8) ?type {
        if (eql(u8, method, "setChild")) return void;
        if (Widget.callMethodHelper(method)) |some| return some;
        return null;
    }

    pub fn callMethod(self: ScrolledWindow, comptime method: []const u8, args: anytype) callMethodHelper(method).? {
        if (comptime eql(u8, method, "setChild")) {
            comptime assert(args.len == 1);
            self.setChild(args[0]);
        } else if (comptime Widget.callMethodHelper(method)) |_| {
            return upCast(Widget, self).callMethod(method, args);
        } else {
            @compileError("No such method");
        }
    }

    pub fn new() ScrolledWindow {
        return ScrolledWindow{ .instance = @ptrCast(*ScrolledWindow.cType(), gtk.gtk_scrolled_window_new()) };
    }

    pub fn setChild(self: ScrolledWindow, child: anytype) void {
        gtk.gtk_scrolled_window_set_child(self.instance, upCast(Widget, child).instance);
    }
};

pub const TextBuffer = packed struct {
    instance: *gtk.GtkTextBuffer,
    classGObject: void = {},
    classTextBuffer: void = {},

    pub fn isAImpl(comptime T: type) bool {
        return meta.trait.hasField("classTextBuffer")(T);
    }

    pub fn cType() type {
        return gtk.GtkTextBuffer;
    }

    pub fn gType() GType {
        return gtk.gtk_text_buffer_get_type();
    }

    pub fn callMethodHelper(comptime method: []const u8) ?type {
        if (eql(u8, method, "setText")) return void;
        if (GObject.callMethodHelper(method)) |some| return some;
        return null;
    }

    pub fn callMethod(self: TextBuffer, comptime method: []const u8, args: anytype) callMethodHelper(method).? {
        if (comptime eql(u8, method, "setText")) {
            comptime assert(args.len == 2);
            self.setText(args[0], args[1]);
        } else if (comptime GObject.callMethodHelper(method)) |_| {
            return upCast(GObject, self).callMethod(method, args);
        } else {
            @compileError("No such method");
        }
    }

    /// If len is -1, text must be nul-terminated
    pub fn setText(self: TextBuffer, text: [*]const u8, len: i32) void {
        gtk.gtk_text_buffer_set_text(self.instance, text, @intCast(c_int, len));
    }
};

pub const TextView = packed struct {
    instance: *gtk.GtkTextView,
    classGObject: void = {},
    classGInitiallyUnowned: void = {},
    classWidget: void = {},
    classTextView: void = {},
    interfaceAccessible: void = {},
    interfaceBuildable: void = {},
    interfaceConstraintTarget: void = {},
    interfaceScrollable: void = {},

    pub fn isAImpl(comptime T: type) bool {
        return meta.trait.hasField("classTextView")(T);
    }

    pub fn cType() type {
        return gtk.GtkTextView;
    }

    pub fn gType() GType {
        return gtk.gtk_text_view_get_type();
    }

    pub fn callMethodHelper(comptime method: []const u8) ?type {
        if (eql(u8, method, "setCursorVisible")) return void;
        if (eql(u8, method, "setEditable")) return void;
        if (Widget.callMethodHelper(method)) |some| return some;
        return null;
    }

    pub fn callMethod(self: TextView, comptime method: []const u8, args: anytype) callMethodHelper(method).? {
        if (comptime eql(u8, method, "setCursorVisible")) {
            comptime assert(args.len == 1);
            self.setCursorVisible(args[0]);
        } else if (comptime eql(u8, method, "setEditable")) {
            comptime assert(args.len == 1);
            self.setEditable(args[0]);
        } else if (comptime Widget.callMethodHelper(method)) |_| {
            return upCast(Widget, self).callMethod(method, args);
        } else {
            @compileError("No such method");
        }
    }

    pub fn new() TextView {
        return TextView{ .instance = @ptrCast(*TextView.cType(), gtk.gtk_text_view_new()) };
    }

    pub fn buffer(self: TextView) TextBuffer {
        return TextBuffer{ .instance = gtk.gtk_text_view_get_buffer(self.instance) };
    }

    pub fn setCursorVisible(self: TextView, setting: bool) void {
        gtk.gtk_text_view_set_cursor_visible(self.instance, @boolToInt(setting));
    }

    pub fn setEditable(self: TextView, setting: bool) void {
        gtk.gtk_text_view_set_editable(self.instance, @boolToInt(setting));
    }
};

pub const Widget = packed struct {
    instance: *gtk.GtkWidget,
    classGObject: void = {},
    classGInitiallyUnowned: void = {},
    classWidget: void = {},
    interfaceAccessible: void = {},
    interfaceBuildable: void = {},
    interfaceConstraintTarget: void = {},

    pub fn isAImpl(comptime T: type) bool {
        return meta.trait.hasField("classWidget")(T);
    }

    pub fn cType() type {
        return gtk.GtkWidget;
    }

    pub fn gType() GType {
        return gtk.gtk_widget_get_type();
    }

    pub fn callMethodHelper(comptime method: []const u8) ?type {
        if (eql(u8, method, "initTemplate")) return void;
        if (eql(u8, method, "setHalign")) return void;
        if (eql(u8, method, "setHexpand")) return void;
        if (eql(u8, method, "setValign")) return void;
        if (eql(u8, method, "setVexpand")) return void;
        if (eql(u8, method, "show")) return void;
        if (GInitiallyUnowned.callMethodHelper(method)) |some| return some;
        return null;
    }

    pub fn callMethod(self: Widget, comptime method: []const u8, args: anytype) callMethodHelper(method).? {
        if (comptime eql(u8, method, "initTemplate")) {
            comptime assert(args.len == 0);
            self.initTemplate();
        } else if (comptime eql(u8, method, "setHalign")) {
            comptime assert(args.len == 1);
            self.setHalign(args[0]);
        } else if (comptime eql(u8, method, "setHexpand")) {
            comptime assert(args.len == 1);
            self.setHexpand(args[0]);
        } else if (comptime eql(u8, method, "setValign")) {
            comptime assert(args.len == 1);
            self.setValign(args[0]);
        } else if (comptime eql(u8, method, "setVexpand")) {
            comptime assert(args.len == 1);
            self.setVexpand(args[0]);
        } else if (comptime eql(u8, method, "show")) {
            comptime assert(args.len == 0);
            self.show();
        } else if (comptime GInitiallyUnowned.callMethodHelper(method)) |_| {
            return upCast(GInitiallyUnowned, self).callMethod(method, args);
        } else {
            @compileError("No such method");
        }
    }

    pub fn initTemplate(self: Widget) void {
        gtk.gtk_widget_init_template(self.instance);
    }

    pub fn setHalign(self: Widget, @"align": Align) void {
        gtk.gtk_widget_set_halign(self.instance, @enumToInt(@"align"));
    }

    pub fn setHexpand(self: Widget, expand: bool) void {
        gtk.gtk_widget_set_hexpand(self.instance, @boolToInt(expand));
    }

    pub fn setValign(self: Widget, @"align": Align) void {
        gtk.gtk_widget_set_valign(self.instance, @enumToInt(@"align"));
    }

    pub fn setVexpand(self: Widget, expand: bool) void {
        gtk.gtk_widget_set_vexpand(self.instance, @boolToInt(expand));
    }

    pub fn show(self: Widget) void {
        gtk.gtk_widget_show(self.instance);
    }
};

pub const Window = packed struct {
    instance: *gtk.GtkWindow,
    classGObject: void = {},
    classGInitiallyUnowned: void = {},
    classWidget: void = {},
    classWindow: void = {},
    interfaceAccessible: void = {},
    interfaceBuildable: void = {},
    interfaceConstraintTarget: void = {},
    interfaceNative: void = {},
    interfaceRoot: void = {},
    interfaceShortcutManager: void = {},

    pub fn isAImpl(comptime T: type) bool {
        return meta.trait.hasField("classWindow")(T);
    }

    pub fn cType() type {
        return gtk.GtkWindow;
    }

    pub fn gType() GType {
        return gtk.gtk_window_get_type();
    }

    pub fn callMethodHelper(comptime method: []const u8) ?type {
        if (eql(u8, method, "destroy")) return void;
        if (eql(u8, method, "present")) return void;
        if (eql(u8, method, "setApplication")) return void;
        if (eql(u8, method, "setChild")) return void;
        if (eql(u8, method, "setDefaultSize")) return void;
        if (eql(u8, method, "setTitle")) return void;
        if (Widget.callMethodHelper(method)) |some| return some;
        return null;
    }

    pub fn callMethod(self: Window, comptime method: []const u8, args: anytype) callMethodHelper(method).? {
        if (comptime eql(u8, method, "destroy")) {
            comptime assert(args.len == 0);
            self.destroy();
        } else if (comptime eql(u8, method, "present")) {
            comptime assert(args.len == 0);
            self.present();
        } else if (comptime eql(u8, method, "setApplication")) {
            comptime assert(args.len == 1);
            self.setApplication(args[0]);
        } else if (comptime eql(u8, method, "setChild")) {
            comptime assert(args.len == 1);
            self.setChild(args[0]);
        } else if (comptime eql(u8, method, "setDefaultSize")) {
            comptime assert(args.len == 2);
            self.setDefaultSize(args[0], args[1]);
        } else if (comptime eql(u8, method, "setTitle")) {
            comptime assert(args.len == 1);
            self.setTitle(args[0]);
        } else if (comptime Widget.callMethodHelper(method)) |_| {
            return upCast(Widget, self).callMethod(method, args);
        } else {
            @compileError("No such method");
        }
    }

    pub const deinit = destroy;

    pub fn destroy(self: Window) void {
        gtk.gtk_window_destroy(self.instance);
    }

    pub fn present(self: Window) void {
        gtk.gtk_window_present(self.instance);
    }

    pub fn setApplication(self: Window, application: Application) void {
        gtk.gtk_window_set_application(self.instance, application.instance);
    }

    pub fn setChild(self: Window, child: anytype) void {
        gtk.gtk_window_set_child(self.instance, upCast(Widget, child).instance);
    }

    pub fn setDefaultSize(self: Window, width: i32, height: i32) void {
        gtk.gtk_window_set_default_size(self.instance, @intCast(c_int, width), @intCast(c_int, height));
    }

    pub fn setTitle(self: Window, title: ?[*:0]const u8) void {
        gtk.gtk_window_set_title(self.instance, title);
    }
};
