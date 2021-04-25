const std = @import("std");
const gpa = std.heap.c_allocator;
const builtin = @import("builtin");

const u = @import("index.zig");
const yaml = @import("./yaml.zig");

//
//

pub const Module = struct {
    is_sys_lib: bool,
    is_framework: bool,
    id: []const u8,
    name: []const u8,
    main: []const u8,
    c_include_dirs: [][]const u8,
    c_source_flags: [][]const u8,
    c_source_files: [][]const u8,
    only_os: [][]const u8,
    except_os: [][]const u8,
    yaml: ?yaml.Mapping,

    deps: []Module,
    clean_path: []const u8,

    pub fn from(dep: u.Dep) !Module {
        return Module{
            .is_sys_lib = false,
            .is_framework = false,
            .id = dep.id,
            .name = dep.name,
            .main = dep.main,
            .c_include_dirs = dep.c_include_dirs,
            .c_source_flags = dep.c_source_flags,
            .c_source_files = dep.c_source_files,
            .deps = &[_]Module{},
            .clean_path = try dep.clean_path(),
            .only_os = dep.only_os,
            .except_os = dep.except_os,
            .yaml = dep.yaml,
        };
    }

    pub fn eql(self: Module, another: Module) bool {
        return std.mem.eql(u8, self.id, another.id) or std.mem.eql(u8, self.clean_path, another.clean_path);
    }

    pub fn get_hash(self: Module, cdpath: []const u8) ![]const u8 {
        const file_list_1 = &std.ArrayList([]const u8).init(gpa);
        try u.file_list(try u.concat(&.{ cdpath, "/", self.clean_path }), file_list_1);

        const file_list_2 = &std.ArrayList([]const u8).init(gpa);
        for (file_list_1.items) |item| {
            const _a = u.trim_prefix(item, cdpath)[1..];
            const _b = u.trim_prefix(_a, self.clean_path)[1..];
            if (_b[0] == '.') continue;
            try file_list_2.append(_b);
        }

        std.sort.sort([]const u8, file_list_2.items, void{}, struct {
            pub fn lt(context: void, lhs: []const u8, rhs: []const u8) bool {
                return std.mem.lessThan(u8, lhs, rhs);
            }
        }.lt);

        const h = &std.crypto.hash.Blake3.init(.{});
        for (file_list_2.items) |item| {
            const abs_path = try u.concat(&.{ cdpath, "/", self.clean_path, "/", item });
            const file = try std.fs.cwd().openFile(abs_path, .{});
            defer file.close();
            const input = try file.reader().readAllAlloc(gpa, u.mb * 100);
            h.update(input);
        }
        var out: [32]u8 = undefined;
        h.final(&out);
        const hex = try std.fmt.allocPrint(gpa, "blake3-{x}", .{std.fmt.fmtSliceHexLower(out[0..])});
        return hex;
    }

    pub fn is_for_this(self: Module) bool {
        const os = @tagName(builtin.os.tag);
        if (self.only_os.len > 0) {
            return u.list_contains(self.only_os, os);
        }
        if (self.except_os.len > 0) {
            return !u.list_contains(self.except_os, os);
        }
        return true;
    }

    pub fn has_no_zig_deps(self: Module) bool {
        for (self.deps) |d| {
            if (d.main.len > 0) {
                return false;
            }
        }
        return true;
    }
};
