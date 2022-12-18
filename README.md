# GTK4 Examples in Zig

This provides a wrapper around C API of GTK.

Examples `hello/example{0-3}.zig` are based on [GTK Docs/Getting Started](https://docs.gtk.org/gtk4/getting_started.html).

`application.zig` reinterpretes the offical example application 3. This shows how to define custom widget in Zig.

## Example

```zig
// hello/example1.zig
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
    _ = button.callMethod("connect", .{ "clicked", &printHello, .{}, .{ .swapped = true } });
    _ = button.callMethod("connect", .{ "clicked", &Window.destroy, .{upCast(Window, window)}, .{ .swapped = true } });
    box.append(button);
    window.callMethod("show", .{});
}

pub fn main() void {
    var app = Application.new("org.gtk.example", .None);
    _ = app.callMethod("connect", .{ "activate", &activate, .{}, .{} }); // ignore id
    _ = app.callMethod("run", .{ @intCast(i32, std.os.argv.len), @ptrCast(?[*:null]?[*:0]u8, std.os.argv.ptr) }); // ignore status
    app.callMethod("unref", .{});
}
```

## Wrapper Library

### Object

```zig
pub const ZigObject = pack struct {
    // required
    instance: *ZigObject.cType(),

    // required
    pub fn cType() type {
        return gtk.cObject;
    }

    // required
    pub fn gType() GType {
        return gtk.gtk_c_object_get_type();
    }

    // optional
    pub fn methodA(self: ZigObject, setting: bool) void {
        // ...
    }

    // optional
    pub fn methodB(self: ZigObject) bool {
        // ...
    }
};
```

Each wrapped object is a packed struct consisting of only one non-zero-sized field, a pointer. Wrapped object has the same memory layout as `?*anyopaque`, which enables `fn cCallback(object: *gtk.cObject) callconv(.C) void` to become `fn cCallback(object: ZigObject) callconv(.C) void`.

`isAImpl`, `callMethodHelper`, `callMethod` are also required if the object inherits from GObject. These functions together with ancestor marks and interfaces marks make use of the gobject type system. Zero runtime overhead abstraction `object.callMethod("methodName", .{args})` can be used to call inherited methods.

```zig
pub const ZigObject = pack struct {
    // required
    instance: *ZigObject.cType(),
    // mark (all) ancestors, required
    classA: void = {},
    classB: void = {},
    // ...
    // mark interfaces, required
    interfaceA: void = {},
    interfaceB: void = {},
    // ...

    // required
    pub fn isAImpl(comptime T: type) bool {
        return trait.hasField("classCObject")(T);
    }

    // required
    pub fn cType() type {
        return gtk.cObject;
    }

    // required
    pub fn gType() GType {
        return gtk.gtk_c_object_get_type();
    }

    // required
    pub fn callMethodHelper(comptime method: []const u8) ?type {
        // methods
        if (eql(u8, method, "methodA")) return void;
        if (eql(u8, method, "methodB")) return bool;
        // ...
        // methods inherited from interface
        if (InterfaceA.callMethodHelper(method)) |some| return some;
        if (InterfaceB.callMethodHelper(method)) |some| return some;
        // ...
        // methods inherited from ancestor
        if (Parent.callMethodHelper(method)) |some| return some;
        return null;
    }

    // required
    pub fn callMethod(self: ZigObject, comptime method: []const u8, args: anytype) callMethodHelper(method).? {
        if (comptime eql(u8, method, "methodA")) {
            comptime assert(args.len == 1);
            self.methodA(args[0]);
        } else if (comptime eql(u8, method, "methodB")) {
            comptime assert(args.len == 0);
            return self.methodB();
        } // ...
        else if (comptime InterfaceA.callMethodHelper(method)) |_| {
            return upCast(InterfaceA, self).callMethod(method, args);
        } else if (comptime InterfaceB.callMethodHelper(method)) |_| {
            return upCast(InterfaceB, self).callMethod(method, args);
        } // ...
        else if (comptime Parent.callMethodHelper(method)) |_| {
            return upCast(Parent, self).callMethod(method, args);
        } else {
            @compileError("No such method");
        }
    }

    // optional
    pub fn methodA(self: ZigObject, setting: bool) void {
        // ...
    }

    // optional
    pub fn methodB(self: ZigObject) bool {
        // ...
    }
};
```

### Cast

```zig
pub fn upCast(comptime T: type, object: anytype) T {}
pub fn downCast(comptime T: type, object: anytype) ?T {}
pub fn dynamicCast(comptime T: type, object: anytype) ?T {}
pub fn unsafeCast(comptime T: type, object: anytype) T {}
```

`upCast` casts `object` to its ancestor class `T` with comptime check. `downCast` casts `object` to its successor class `T` with comptime and runtime check. `dynamicCast` casts `object` to class `T` with runtime check. `unsafeCast` casts `object` to class `T` without check.

When interacting with C API, the following cast functions will be helpful.

```zig
pub fn unsafeCastPtr(comptime T: type, ptr: ?*anyopaque) ?T {}
pub fn unsafeCastPtrNonNull(comptime T: type, ptr: *anyopaque) T {}
pub fn fromPtr(comptime T: type, ptr: ?*T.cType()) ?T {}
pub fn toPtr(comptime T: type, self: ?T) ?*T.cType() {}
```

`unsafeCastPtr` is the same with `unsafeCast` except that it accepts a pointer instead of a wrapped object. `unsafeCastPtrNonNull` assumes the pointer is non-nullable. `fromPtr` converts an optional pointer to an optional object. `toPtr` converts an optional object to an optional pointer.

### Taking advantage of Zig

General `*gtk.GtkWidget` should be converted to corresponding type. For example, `ApplicationWindow.new` returns a `ApplicationWindow` instead of `Widget`. For another example, `Window.setChild` accepts an `anytype` and upcasts it to `Widget` internally.

C style callback `fn (?*anyopaque) callconv(.C) void` should be replaced with normal function like `fn (Window, Application) void`. There is an underlying closure mechanism to support this. Callback should not be a generic function. Callback should not be a varidic function until [#515](https://github.com/ziglang/zig/issues/515) is done. For example, `button.callMethod("connect", .{ "clicked", &Window.deinit, .{window}, .{ .swapped = true } })` connects `Window.deinit` to signal `clicked` without a manually written wrapper. (`swapped` is set `true` because we don't need a `Button` argument)

C primitive types should not be exposed. For example, `c_int` may be casted to/from `i32`(user should be aware that `c_int` can be actually `i16`), `bool` or `enum`(exhaustive one is preferred). Many item pointes should be converted to slices if possible.

Output parameters should be eliminated. Multiple values can be returned in tuple. If the function can fail, a tagged union `union(enum) { Ok: Ok, Err: Err, }` is returned. If `Ok` or `Err` is `void`, it can be reduced to `?Err` or `?Ok`.

Enjoy the world with out of bound detection, overflow detection, null detection, better error, better enum, better union, stronger type system and `comptime`.

## Custom Widget

Define `CustomWidgetClass` and `CustomWidgetImpl`. And create a wrapper `CustomWidget` then.

```zig
const Static = struct {
    var type_id: GType = 0;
};

// extern struct guarantees in-memory layout and compatitablility with C ABI
pub const CustomWidgetClass = extern struct {
    // required as the first field, this is how gobject type system works
    parent_class: ParentClass,
    // private fields
    // ...

    // required
    pub fn init(self: *CustomWidgetClass) callconv(.C) void {
        // ...
    }
};

const CustomWidgetImpl = extern struct {
    // required as the first field
    parent: Parent.cType(),
    // private fields
    // ...

    // required
    pub fn init(self: *CustomWidgetImpl) callconv(.C) {
        // ...
    }

    // required
    pub fn new() *CustomWidgetImpl {
        return newObject(
            CustomWidgetImpl.gType(),
            "property 1 name", property_1_value,
            "property 2 name", property_2_value,
            // ...
            "property n name", property_n_value,
            @as(?*anyopaque, null)
        );
    }

    // required
    pub fn gType() GType {
        if (0 != onceInitEnter(&Static.type_id)) {
            // call exactly once
            var type_id = registerType(
                Parent.gType(),
                "CustomWidget",
                @sizeOf(CustomWidgetClass), &CustomWidgetClass.init,
                @sizeOf(CustomWidgetImpl), &CustomWidgetImpl.init,
                GTypeFlags.None
            );
            defer onceInitLeave(&Static.type_id, type_id);
        }
        return Static.type_id;
    }
};
```

## LICENSE

GPL v3
