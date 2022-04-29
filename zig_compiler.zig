// zig fmt: off
const     std           = @import("std");
pub const Zir           = @import("src/Zir.zig");
pub const ModuleShim    = struct {
    pub const SrcLoc      = @import("src/Module.zig").SrcLoc;
    pub const LazySrcLoc  = @import("src/Module.zig").LazySrcLoc;
    pub const File        = @import("src/Module.zig").File;

    const GenZirError = error{
        OutOfMemory,
        GenZirFail,
    } || std.fs.File.WriteError;

    pub fn genZir(
        tmp_arena_inst: *std.heap.ArenaAllocator,
        src_path: []const u8,
        src_text: [:0]const u8,
        tree: std.zig.Ast,
        fs_writer: std.fs.File.Writer,
        debug_dump: bool,
    ) GenZirError!ModuleShim.File {
        // zig fmt: off
        const AstGen      = @import("src/AstGen.zig");
        const Package     = @import("src/Package.zig");
        const Compilation = @import("src/Compilation.zig");
        const Module      = @import("src/Module.zig");
        const AllErrors   = Compilation.AllErrors;
        const print_zir   = @import("src/print_zir.zig");
        // zig fmt: on

        const tmp_arena = tmp_arena_inst.allocator();
        std.debug.assert(tree.errors.len == 0);
        const module_pkg = Package.create(tmp_arena, null, src_path) catch return error.GenZirFail;
        // errdefer module_pkg.destroy(tmp_arena);
        const module_zir = try AstGen.generate(tmp_arena, tree);
        // errdefer module_zir.deinit(tmp_arena);
        const file_stat = std.fs.cwd().statFile(src_path) catch return error.GenZirFail;

        var module_file = Module.File{
            // zig fmt: off
            .status        = .never_loaded,
            .source_loaded = true,
            .sub_file_path = src_path,
            .source        = src_text,
            .stat          = .{
                .size  = file_stat.size,
                .inode = file_stat.inode,
                .mtime = file_stat.mtime,
            },
            .tree        = tree,
            .tree_loaded = true,
            .zir         = module_zir,
            .zir_loaded  = true,
            .pkg         = module_pkg,
            .root_decl   = .none,
            // zig fmt: on
        };

        if (module_file.zir.hasCompileErrors()) {
            const ttyconf = std.debug.TTY.Config.windows_api; // std.debug.detectTTYConfig()
            var errors = std.ArrayList(AllErrors.Message).init(tmp_arena);
            try AllErrors.addZir(tmp_arena, &errors, &module_file);
            for (errors.items) |full_err_msg|
                full_err_msg.renderToStdErr(ttyconf);
            return error.GenZirFail;
        }
        module_file.status = .success_zir;

        if (debug_dump) try print_zir.renderAsTextToFile(tmp_arena, &module_file, fs_writer.context);

        return module_file;
    }

};
// zig fmt: on
