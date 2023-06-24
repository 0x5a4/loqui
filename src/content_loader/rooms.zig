const std = @import("std");
const tomlz = @import("tomlz");

const config = @import("../config.zig");
const components = @import("../components.zig");
const iables_loader = @import("interactables.zig");
const predicate_loader = @import("predicates.zig");
const action_loader = @import("actions.zig");

const Action = components.Action;
const ContentError = config.ContentError;
const Game = @import("../Game.zig");
const Room = components.Room;
const Table = tomlz.Table;

/// Loads all rooms contained within the table
pub fn load(game: *Game, table: *const Table) ContentError!void {
    var table_iter = table.table.iterator();
    while (table_iter.next()) |room_entry| {
        if (room_entry.value_ptr.* != .table) {
            std.log.err("room value was not a table: room.{s}", .{room_entry.key_ptr.*});
            return ContentError.InvalidRoom;
        }

        const room = try game.createRoom(room_entry.key_ptr.*);
        try loadRoom(game, room, @ptrCast(*const Table, room_entry.value_ptr));
    }
}

/// Loads the Room object from this table
fn loadRoom(game: *Game, room: *Room, table: *const Table) ContentError!void {
    if (table.getTable("interactables")) |iables_table| {
        try iables_loader.load(game, room, &iables_table);
    }

    if (table.getTable("iabl")) |iables_table| {
        try iables_loader.load(game, room, &iables_table);
    }

    if (table.getTable("doors")) |doors_table| {
        try loadDoors(game, room, &doors_table);
    }
}

fn loadDoors(game: *Game, room: *Room, table: *const Table) ContentError!void {
    var table_iter = table.table.iterator();
    while (table_iter.next()) |door_entry| {
        if (door_entry.value_ptr.* != .table) {
            std.log.err("room value was not a table: room.{s}.doors.{s}", .{ room.id, door_entry.key_ptr.* });
            return ContentError.InvalidRoom;
        }

        try loadDoor(
            game,
            room,
            door_entry.key_ptr.*,
            @ptrCast(*const Table, door_entry.value_ptr),
        );
    }
}

fn loadDoor(game: *Game, room: *Room, to: []const u8, table: *const Table) !void {
    if (room.interactables.contains(to)) {
        //TODO: warn user about implicitly named interactables like doors?
        std.log.warn("interactable {s}.{s} is being created multiple times. this is propably unintended behaviour!", .{ room.id, to });
    }

    const iabl = try game.createInteractable(room, to, "doors");

    const param = try game.createActionParam(to);
    iabl.on_interact = Action{ .move = param };

    // display-name
    if (table.getString("display-name")) |display_name| {
        iabl.display_name = try game.createText(display_name);
    }

    // text
    if (table.getString("text")) |text| {
        iabl.text = .{ .single = try game.createText(text) };
    } else if (table.getArray("text")) |text_array| {
        _ = text_array;
        std.debug.panic("TODO: implement randomized text", .{});
    }

    // text-locked
    if (table.getString("text-locked")) |text| {
        iabl.text_locked = .{ .single = try game.createText(text) };
    } else if (table.getArray("text-locked")) |text_array| {
        _ = text_array;
        std.debug.panic("TODO: implement randomized text", .{});
    } else {
        iabl.text_locked = .{ .single = try game.createText("Its locked!") };
    }

    // require
    if (table.getString("require")) |text| {
        iabl.require = try predicate_loader.load(game, text);
    }

    // on-interact-locked
    if (table.getString("on-interact-locked")) |text| {
        iabl.on_interact_locked = try action_loader.load(game, text);
    }

    // hidden
    if (table.getBool("hidden")) |value| {
        iabl.hidden = value;
    }

    // once
    if (table.getBool("once")) |value| {
        iabl.once = value;
    }
}
