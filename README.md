# GTK4 Examples in Zig

This provides a wrapper around C API of GTK.

Examples `hello/example{0-3}.zig` are based on [GTK Docs/Getting Started](https://docs.gtk.org/gtk4/getting_started.html).

`application.zig` reinterpretes the offical example application 3. This shows how to define custom widget in Zig.

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
	pub fn methodA(self: ZigObject) void {
		// ...
	}
};
```

Each wrapped object is a packed struct consisting of only one non-zero-sized field, a pointer. Wrapped object has the same memory layout as `?*anyopaque`, which enables `fn cCallback(object: *gtk.cObject) callconv(.C) void` to become `fn cCallback(object: ZigObject) callconv(.C) void`.

`isAImpl`, `hasMethod`, `callMethod` are also required if the object inherits from GObject. These functions together with ancestor marks and interfaces marks make use of the gobject type system. User can use zero runtime overhead abstraction `object.callMethod("methodName", .{args})` to call inherited methods.

```zig
pub const ZigObject = pack struct {
	// required
	instance: *ZigObject.cType(),
	// mark ancestors, required
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
	pub fn hasMethod(method: []const u8) bool {
		// methods
		if (eql(u8, method, "methodA")) return true;
		if (eql(u8, method, "methodB")) return true;
		// ...
		// methods inherited from interface
		if (InterfaceA.hasMethod(method)) return true;
		if (InterfaceB.hasMethod(method)) return true;
		// ...
		// methods inherited from ancestor
		if (ParentClass.hasMethod(method)) return true;
		return false;
	}

	// required
	pub fn callMethod(self: ZigObject, comptime method: []const u8, args: anytype) void {
		if (comptime eql(u8, method, "methodA")) {
			comptime assert(args.len == 0);
			self.methodA();
		} else if (comptime eql(u8, method, "methodB")) {
			comptime assert(args.len == 1 or args.len == 2);
			var ret = self.methodB(args[0]);
			if (comptime args.len == 2) { // return value can be ignored
				args[1].* = ret;
			}
		} // ...
		else if (comptime InterfaceA.hasMethod(method)) {
			upCast(InterfaceA, self).callMethod(method, args);
		} else if (comptime InterfaceB.hasMethod(method)) {
			upCast(InterfaceB, self).callMethod(method, args);
		} // ...
		else if (comptime ParentClass.hasMethod(method)) {
			upCast(Parent, self).callMethod(method, args);
		} else {
			@compileError("No such method");
		}
	}

	// optional
	pub fn methodA(self: ZigObject) void {
		// ...
	}

	// optinal
	pub fn methodB(self: ZigObject, arg: u8) u8 {
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

`upCast` casts `object` to its ancestor class `T`. `downCast` casts `object` to its successor class `T`. `dynamicCast` casts `object` to class `T`. `unsafeCast` casts `object` to class `T`. `upCast` and `downCast` involve comptime check. `downCast` and `dynamicCast` involve runtime check.

When interacting with C API, the following cast functions will be helpful.

```zig
pub fn unsafeCastPtr(comptime T: type, ptr: ?*anyopaque) ?T {}
pub fn unsafeCastPtrNonNull(comptime T: type, ptr: *anyopaque) T {}
pub fn fromPtr(comptime T: type, ptr: ?*T.cType()) ?T {}
pub fn toPtr(comptime T: type, self: ?T) ?*T.cType() {}
```

`unsafeCastPtr` is the same with `unsafeCast` except that it accepts a pointer instead of a wrapped object. `unsafeCastPtrNonNull` assumes the pointer is non-nullable. `fromPtr` converts an optional pointer to an optinal object. `toPtr` converts an optional object to an optional pointer.

### Taking advantage of Zig

General `*gtk.GtkWidget` should be converted to corresponding type. For example, `ApplicationWindow.new` returns a `ApplicationWindow` instead of `Widget` or `?*Widget.cType()`. For another example, `Window.setChild` accepts an `anytype` which is upcasted to `Widget` internally, so manual cast is not required.

C style callback `fn (?*anyopaque) callconv(.C) void` should be replaced with common function like `fn (Window, Application) void`. There is an underlying closure mechanism to support this. Callback should not be a generic function. Callback should not be a varidic function until [#515](https://github.com/ziglang/zig/issues/515) is done. For example, `button.callMethod("connect", .{ "clicked", &Window.deinit, .{window}, .{ .swapped = true } })` enables user to connect `Window.deinit` to signal `clicked` without manually writing a C style callback wrapper. (`swapped` is set `true` because we don't need a `Button` argument)

C primitive types should not be exposed to user. For example, `c_int` may be casted to/from `i32`(`@intCast` should be used internally in case that `c_int` is actually `i16`), `bool` or `enum(c_uint)`(exhaustive enum if possible). For many item pointer, convert it to slice if possible. Otherwise, make it sentinel terminated if possible. Fox single item pointer, be optional if nullable.

## Custom Widget

Define `CustomWidgetClass`, `CustomWidgetImpl` first. `CustomWidgetImpl.getTypeOnce` should be called exactly once.

```zig
const CustomWidgetClass = extern struct {
	// required
	parent_class: ParentClass,
	// private fields
	// ...

	// required
	pub fn init(self: *CustomWidgetClass) callconv(.C) void {
		// ...
	}
};

const CustomWidgetImpl = extern struct {
	// required
	parent: Parent,
	// private fields
	// ...

	// required
	pub fn init(self: *CustomWidgetImpl) callconv(.C) {
		// ...
	}

	// recommended
	pub fn getTypeOnce() GType {
		return gtk.g_type_register_static_simple(
			Parent.gType(),
			"CustomWidget",
			@sizeOf(CustomWidgetClass), &CustomWidgetClass.init,
			@sizeOf(CustomWidgetImpl), &CustomWidgetImpl.init,
			0
		);
	}
};
```

Then create a wrapper `CustomWidget`. The following contents may be helpful.

```zig
const Static = struct {
	var type_id: GType = 0;
};

pub const CustomWidget = packed struct {
	instance: *CustomWidgetImpl,
	// ...

	pub fn gType() GType {
		// guarantee once init (initial value should be 0)
		if (0 != gtk.g_once_init_enter(&Static.type_id)) {
			var type_id = CustomWidgetImpl.getTypeOnce();
			gtk.g_once_init_leave(&Static.type_id, type_id);
		}
		return Static.type_id;
	}

	pub fn new() CustomWidget {
		const ptr = gtk.g_object_new(CustomWidget.gType(), "property name", property_value, @as(?*anyopaque, null));
		return unsafeCastPtr(CustomWidget, ptr.?);
	}
};
```
