const std = @import("std");
const fs = std.fs;
const tomlz = @import("tomlz");

const Allocator = std.mem.Allocator;
const Dir = fs.Dir;
const File = fs.File;
const IterableDir = fs.IterableDir;
const Table = tomlz.Table;

const Game = @import("Game.zig");

const room_loader = @import("content_loader/rooms.zig");

pub const ContentError = error{
    InvalidGameSettings,
    InvalidRoom,
    InvalidInteractable,
    InvalidAction,
    InvalidPredicate,
} || Allocator.Error;

// zig fmt: off
pub const ConfigLoadError = ContentError 
    || File.OpenError 
    || fs.Dir.OpenError 
    || std.os.ReadError 
    || tomlz.parser.ParseError
    || Allocator.Error;
// zig fmt: on

// If your config file is 4GiBs in size, you have other problems
const MAX_FILE_SIZE = std.math.pow(usize, 1024, 4) * 4;

pub fn load(alloc: Allocator, dir: *const Dir, game: *Game) ConfigLoadError!void {
    // load game settings file
    var config_file = dir.openFile("game.toml", .{}) catch |err| {
        if (err == error.FileNotFound) {
            std.log.err("'game.toml' was not found", .{});
        }

        return err;
    };
    defer config_file.close();

    try parseConfigFile(alloc, config_file, game);

    // load content
    var content_dir = try dir.openIterableDir("content", .{});
    defer content_dir.close();

    var walker = try content_dir.walk(alloc);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;

        if (std.mem.endsWith(u8, entry.basename, ".toml")) {
            const file = try entry.dir.openFile(entry.basename, .{});

            parseContentFile(alloc, file, game) catch |err| {
                std.log.err("occured while loading 'content/{s}'", .{entry.path});
                return err;
            };
        }
    }
}

fn parseConfigFile(alloc: Allocator, file: File, game: *Game) ConfigLoadError!void {
    var config_contents = try file.readToEndAlloc(alloc, MAX_FILE_SIZE);
    defer alloc.free(config_contents);

    var table = try tomlz.parse(alloc, config_contents);
    defer table.deinit(alloc);

    if (table.getString("starting-room")) |starting_room| {
        game.config.starting_room = try alloc.dupe(u8, starting_room);
    } else {
        std.log.err("game config is missing required field 'starting-room'", .{});
        return ContentError.InvalidGameSettings;
    }

    if (table.getString("startup-text")) |startup_text| {
        game.config.startup_text = try game.createText(startup_text);
    }
}

fn parseContentFile(alloc: Allocator, file: File, game: *Game) ConfigLoadError!void {
    var contents = try file.readToEndAlloc(alloc, MAX_FILE_SIZE);
    defer alloc.free(contents);

    var config = try tomlz.parse(alloc, contents);
    defer config.deinit(alloc);

    // Load rooms
    if (config.getTable("rooms")) |rooms_table| {
        try room_loader.load(game, rooms_table);
    } else if (config.table.get("rooms")) |actual| {
        std.log.err("expected room to be of type 'table' but was '{s}'", .{@tagName(actual)});
        return error.InvalidRoom;
    } else if (config.contains("room")) {
        std.log.warn("no table 'rooms' found, but found one named 'room'. Did you misspell it? ", .{});
    }
}
