// zig fmt: off
const     std           = @import("std");
pub const BuiltinFn     = @import("src/BuiltinFn.zig");
pub const Zir           = @import("src/Zir.zig");
pub const ModuleFile    = @import("src/Module.zig").File;
pub const ModuleSrcLoc  = @import("src/Module.zig").SrcLoc;
pub const LazySrcLoc    = @import("src/Module.zig").LazySrcLoc;
pub const print_zir     = @import("src/print_zir.zig").renderAsTextToFile;
// zig fmt: on

pub const GenZirError = error{
    OutOfMemory,
    MalformedAst,
    ZigIRFail,
};
pub fn genZir(
    gpa: std.mem.Allocator,
    tmp_arena: std.mem.Allocator,
    file_path: []const u8,
    file_text: [:0]const u8,
    tree: std.zig.Ast,
) GenZirError!Zir {
    // zig fmt: off
    const AstGen    = @import("src/AstGen.zig");
    const Package   = @import("src/Package.zig");
    const AllErrors = @import("src/Compilation.zig").AllErrors;
    const Module    = @import("src/Module.zig");
    // zig fmt: on

    if (tree.errors.len != 0)
        return error.MalformedAst;

    const file_stat = std.fs.cwd().statFile(file_path) catch return error.ZigIRFail;
    var file = Module.File{
        .status = .never_loaded,
        .source_loaded = true,
        .sub_file_path = file_path,
        .source = file_text,
        .stat = .{
            .size = file_stat.size,
            .inode = file_stat.inode,
            .mtime = file_stat.mtime,
        },
        .tree = undefined,
        .tree_loaded = false,
        .zir = undefined,
        .zir_loaded = false,
        .pkg = undefined,
        .root_decl = null,
    };

    file.pkg = Package.create(tmp_arena, null, file_path) catch return error.ZigIRFail;
    defer file.pkg.destroy(tmp_arena);

    file.tree = tree;
    file.tree_loaded = true;

    file.zir = try AstGen.generate(gpa, file.tree);
    file.zir_loaded = true;

    if (file.zir.hasCompileErrors()) {
        const ttyconf: std.debug.TTY.Config = std.debug.detectTTYConfig(); // .windows_api;
        var errors = std.ArrayList(AllErrors.Message).init(tmp_arena);
        try AllErrors.addZir(tmp_arena, &errors, &file);
        for (errors.items) |full_err_msg|
            full_err_msg.renderToStdErr(ttyconf);
        return error.ZigIRFail;
    }

    return file.zir;
}
