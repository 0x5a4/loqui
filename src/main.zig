const std = @import("std");
const builtin = @import("builtin");
const default_commands = @import("default_commands.zig");
const config = @import("config.zig");

const process = std.process;

const Game = @import("Game.zig");

pub const std_options = struct {
    pub const log_level = if (builtin.mode == std.builtin.OptimizeMode.Debug) .debug else .info;
};

pub fn main() !void {
    var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
    var gpa = gpa_instance.allocator();
    defer std.debug.assert(gpa_instance.deinit() == .ok);

    var game = Game.init(gpa);
    defer game.deinit();

    const args = try process.argsAlloc(gpa);
    defer process.argsFree(gpa, args);

    const cwd = std.fs.cwd();
    const game_dir = blk: {
        if (args.len < 2) {
            break :blk cwd;
        } else {
            break :blk try cwd.openDirZ(args[1], .{}, false);
        }
    };

    std.log.info("Loading content files...", .{});
    try config.load(gpa, &game_dir, &game);

    try game.createCommand("whereami", default_commands.whereami);
    try game.createCommand("tp", default_commands.teleport);
    try game.createCommand("look-around", default_commands.lookAround);
    try game.createCommand("touch", default_commands.touch);
    try game.createCommand("map", default_commands.map);
    try game.createCommand("goto", default_commands.goto);
    try game.createCommand("inv", default_commands.inv);
    try game.createCommand("help", default_commands.help);

    std.log.info("Starting the game...", .{});
    try game.run();
}
