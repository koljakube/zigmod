const std = @import("std");
const gpa = std.heap.c_allocator;
const fs = std.fs;

const u = @import("./util/index.zig");

//
//

pub const CollectOptions = struct {
    log: bool,
    update: bool,
};

pub fn collect_deps(dir: []const u8, mpath: []const u8, comptime options: CollectOptions) anyerror!u.Module {
    const m = try u.ModFile.init(gpa, mpath);
    const moduledeps = &std.ArrayList(u.Module).init(gpa);
    const tempdir = try fs.path.join(gpa, &.{dir, "temp"});
    var moddir: []const u8 = undefined;
    for (m.deps) |d| {
        const p = try fs.path.join(gpa, &.{dir, try d.clean_path()});
        const pv = try fs.path.join(gpa, &.{dir, try d.clean_path_v()});
        if (options.log) { u.print("fetch: {s}: {s}: {s}", .{m.name, @tagName(d.type), d.path}); }
        moddir = p;
        switch (d.type) {
            .system_lib => {
                // no op
            },
            .git => blk: {
                if (d.version.len > 0) {
                    const vers = u.parse_split(u.GitVersionType, "-").do(d.version) catch |e| switch (e) {
                        error.IterEmpty => unreachable,
                        error.NoMemberFound => {
                            const vtype = d.version[0..std.mem.indexOf(u8, d.version, "-").?];
                            u.assert(false, "fetch: git: version type '{s}' is invalid.", .{vtype});
                            unreachable;
                        },
                    };
                    if (try u.does_folder_exist(pv)) {
                        if (vers.id == .branch) {
                            if (options.update) { try d.type.update(pv, d.path); }
                        }
                        moddir = pv;
                        break :blk;
                    }
                    try d.type.pull(d.path, tempdir);
                    if ((try u.run_cmd(tempdir, &.{"git", "checkout", vers.string})) > 0) {
                        u.assert(false, "fetch: git: {s}: {s} {s} does not exist", .{d.path, @tagName(vers.id), vers.string});
                    }
                    const td_fd = try fs.cwd().openDir(dir, .{});
                    try u.mkdir_all(pv);
                    try td_fd.rename("temp", try d.clean_path_v());
                    if (vers.id != .branch) {
                        const pvd = try std.fs.cwd().openDir(pv, .{});
                        try pvd.deleteTree(".git");
                    }
                    moddir = pv;
                    break :blk;
                }
                if (!try u.does_folder_exist(p)) {
                    try d.type.pull(d.path, p);
                }
                else {
                    if (options.update) { try d.type.update(p, d.path); }
                }
            },
            .hg => {
                if (!try u.does_folder_exist(p)) {
                    try d.type.pull(d.path, p);
                }
                else {
                    if (options.update) { try d.type.update(p, d.path); }
                }
            },
            .http => blk: {
                if (try u.does_folder_exist(pv)) {
                    moddir = pv;
                    break :blk;
                }
                const file_name = try u.last(try u.split(d.path, "/"));
                if (d.version.len > 0) {
                    if (try u.does_folder_exist(pv)) {
                        moddir = pv;
                        break :blk;
                    }
                    const file_path = try std.fs.path.join(gpa, &.{pv, file_name});
                    try d.type.pull(d.path, pv);
                    if (try u.validate_hash(d.version, file_path)) {
                        try std.fs.cwd().deleteFile(file_path);
                        moddir = pv;
                        break :blk;
                    }
                    try u.rm_recv(pv);
                    u.assert(false, "{s} does not match hash {s}", .{d.path, d.version});
                    break :blk;
                }
                if (try u.does_folder_exist(p)) {
                    try u.rm_recv(p);
                }
                const file_path = try std.fs.path.join(gpa, &.{p, file_name});
                try d.type.pull(d.path, p);
                try std.fs.deleteFileAbsolute(file_path);
            },
        }
        switch (d.type) {
            .system_lib => {
                if (d.is_for_this()) try moduledeps.append(u.Module{
                    .is_sys_lib = true,
                    .id = "",
                    .name = d.path,
                    .only_os = d.only_os,
                    .except_os = d.except_os,
                    .main = "",
                    .c_include_dirs = &.{},
                    .c_source_flags = &.{},
                    .c_source_files = &.{},
                    .deps = &[_]u.Module{},
                    .clean_path = d.path,
                    .yaml = null,
                });
            },
            else => blk: {
                var dd = try collect_deps(dir, try u.concat(&.{moddir, "/zig.mod"}), options) catch |e| switch (e) {
                    error.FileNotFound => {
                        if (d.main.len > 0 or d.c_include_dirs.len > 0 or d.c_source_files.len > 0) {
                            var mod_from = try u.Module.from(d);
                            if (mod_from.id.len == 0) mod_from.id = try u.random_string(48);
                            mod_from.clean_path = u.trim_prefix(moddir, dir)[1..];
                            if (mod_from.is_for_this()) try moduledeps.append(mod_from);
                        }
                        break :blk;
                    },
                    else => e,
                };
                dd.clean_path = u.trim_prefix(moddir, dir)[1..];

                if (dd.id.len == 0) dd.id = try u.random_string(48);
                if (d.name.len > 0) dd.name = d.name;
                if (d.main.len > 0) dd.main = d.main;
                if (d.c_include_dirs.len > 0) dd.c_include_dirs = d.c_include_dirs;
                if (d.c_source_flags.len > 0) dd.c_source_flags = d.c_source_flags;
                if (d.c_source_files.len > 0) dd.c_source_files = d.c_source_files;
                if (d.only_os.len > 0) dd.only_os = d.only_os;
                if (d.except_os.len > 0) dd.except_os = d.except_os;

                if (dd.is_for_this()) try moduledeps.append(dd);
            },
        }
    }
    return u.Module{
        .is_sys_lib = false,
        .id = m.id,
        .name = m.name,
        .main = m.main,
        .c_include_dirs = m.c_include_dirs,
        .c_source_flags = m.c_source_flags,
        .c_source_files = m.c_source_files,
        .deps = moduledeps.items,
        .clean_path = "",
        .only_os = &.{},
        .except_os = &.{},
        .yaml = m.yaml,
    };
}

pub fn collect_pkgs(mod: u.Module, list: *std.ArrayList(u.Module)) anyerror!void {
    if (u.list_contains_gen(u.Module, list, mod)) {
        return;
    }
    try list.append(mod);
    for (mod.deps) |d| {
        try collect_pkgs(d, list);
    }
}
