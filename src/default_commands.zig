const std = @import("std");
const Game = @import("Game.zig");

pub fn whereami(_: []const u8, _: [][]const u8, game: *Game) !void {
    const room_index = game.player.room_index;

    const room = game.rooms.items[room_index];
    game.print("Your are currently in {s}\n", .{room.id});
}

pub fn teleport(_: []const u8, args: [][]const u8, game: *Game) !void {
    if (args.len == 0) {
        game.print("no room given\n", .{});
        return;
    }

    if (game.room_map.get(args[0])) |room_index| {
        game.player.room_index = room_index;
    } else {
        game.print("no such room\n", .{});
    }
}

pub fn lookAround(_: []const u8, _: [][]const u8, game: *Game) !void {
    const room_index = game.player.room_index;
    const room = game.rooms.items[room_index];

    game.print("You take a look around!\n", .{});

    var iabl_iter = room.interactables.valueIterator();
    while (iabl_iter.next()) |iabl_index| {
        const iabl = game.interactables.items[iabl_index.*];
        if (iabl.group != null or iabl.hidden) continue;
        game.print(" {s}\n", .{iabl.id});
    }
}

pub fn inv(_: []const u8, _: [][]const u8, game: *Game) !void {
    game.print("Your inventory contains the following items:\n", .{});

    var inv_iter = game.player.inventory.keyIterator();
    while (inv_iter.next()) |item| {
        game.print(" {s}\n", .{item.*});
    }
}

pub fn map(_: []const u8, _: [][]const u8, game: *Game) !void {
    const room_index = game.player.room_index;
    const room = game.rooms.items[room_index];

    const group = room.groups.get("doors") orelse {
        game.print("No doors within this room", .{});
        return;
    };

    game.print("You take a look around. The doors seem to lead to these places:\n", .{});

    var i: usize = 0;
    while (i < group.items.len) : (i += 1) {
        const iabl_index = group.items[i];
        const iabl = game.interactables.items[iabl_index];

        game.print(" {s}\n", .{iabl.id});
    }
}

pub fn goto(_: []const u8, args: [][]const u8, game: *Game) !void {
    if (args.len == 0) {
        game.print("You must specify where to go to\n", .{});
        return;
    }

    const room_index = game.player.room_index;
    const room = game.rooms.items[room_index];

    const group = room.groups.get("doors") orelse {
        game.print("No doors within this room", .{});
        return;
    };

    var i: usize = 0;
    while (i < group.items.len) : (i += 1) {
        const iabl_index = group.items[i];
        const iabl = game.interactables.items[iabl_index];

        if (std.mem.eql(u8, args[0], iabl.id)) {
            try game.interactWith(iabl_index); 
        }
    }
}

pub fn touch(_: []const u8, args: [][]const u8, game: *Game) !void {
    if (args.len == 0) {
        game.print("no object given\n", .{});
        return;
    }

    const room_index = game.player.room_index;
    const room = game.rooms.items[room_index];

    if (room.interactables.get(args[0])) |iabl_index| {
        try game.interactWith(iabl_index);
    }
}

pub fn help(_: []const u8, _: [][]const u8, game: *Game) !void {
    game.print("You can do these things:\n", .{});
    var command_names = game.commands.keyIterator();
    while (command_names.next()) |name| {
        game.print(" {s}\n", .{name.*});
    }
    game.print(" quit\n", .{});
}
