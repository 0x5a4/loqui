const std = @import("std");
const tomlz = @import("tomlz");

const components = @import("../components.zig");
const predicate_config = @import("predicates.zig");
const action_config = @import("actions.zig");

const Table = tomlz.Table;
const Game = @import("../Game.zig");
const Interactable = components.Interactable;
const Room = components.Room;

/// Loads all Interactables contained within the table
pub fn load(game: *Game, room: *Room, table: *const Table) !void {
    var table_iter = table.table.iterator();
    while (table_iter.next()) |iabl_entry| {
        if (iabl_entry.value_ptr.* != .table) {
            std.log.err("interactable value was not a table: room.{s}.{s}", .{ room.id, iabl_entry.key_ptr.* });
            return error.InvalidInteractable;
        }

        try loadInteractable(
            game,
            room,
            iabl_entry.key_ptr.*,
            @ptrCast(*const Table, iabl_entry.value_ptr),
        );
    }
}

/// Loads the Interactable object from this table
fn loadInteractable(game: *Game, room: *Room, id: []const u8, table: *const Table) !void {
    if (room.interactables.contains(id)) {
        //TODO: warn user about implicitly named interactables like doors?
        std.log.warn("interactable {s}.{s} is being created multiple times. this is propably unintended behaviour!", .{room.id, id});
    }
    
    const iabl = try game.createInteractable(room, id, table.getString("group"));

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
    }

    // require
    if (table.getString("require")) |text| {
        iabl.require = try predicate_config.load(game, text);
    }

    // on-interact
    if (table.getString("on-interact")) |text| {
        iabl.on_interact = try action_config.load(game, text);
    }

    // on-interact-locked
    if (table.getString("on-interact-locked")) |text| {
        iabl.on_interact_locked = try action_config.load(game, text);
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
