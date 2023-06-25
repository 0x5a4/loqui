const std = @import("std");
const tomlz = @import("tomlz");

const components = @import("../components.zig");
const predicate_config = @import("predicates.zig");
const action_config = @import("actions.zig");
const config = @import("../config.zig");

const ContentError = config.ContentError;
const Table = tomlz.Table;
const Game = @import("../Game.zig");
const Interactable = components.Interactable;
const Room = components.Room;

/// Loads all Interactables contained within the table
pub fn load(game: *Game, room: *Room, table: Table) ContentError!void {
    var table_iter = table.table.iterator();
    while (table_iter.next()) |iabl_entry| {
        if (iabl_entry.value_ptr.* != .table) {
            std.log.err("interactable value was not a table: room.{s}.{s}", .{ room.id, iabl_entry.key_ptr.* });
            return ContentError.InvalidInteractable;
        }

        try loadInteractable(game, room, iabl_entry.key_ptr.*, iabl_entry.value_ptr.*.table);
    }
}

/// Loads the Interactable object from this table
fn loadInteractable(game: *Game, room: *Room, id: []const u8, table: Table) ContentError!void {
    if (room.interactables.contains(id)) {
        //TODO: warn user about implicitly named interactables like doors?
        std.log.warn("interactable {s}.{s} is being created multiple times. this is propably unintended behaviour!", .{ room.id, id });
    }

    const iabl = try game.createInteractable(room, id, table.getString("group"));

    // display-name
    if (try getAssertType([]const u8, table, "display-name", .string)) |display_name| {
        iabl.display_name = try game.createText(display_name);
    }

    // text
    if (table.getString("text")) |text| {
        iabl.text = .{ .single = try game.createText(text) };
    } else if (table.getArray("text")) |text_array| {
        _ = text_array;
        std.debug.panic("TODO: implement randomized text", .{});
    } else if (table.table.get("text-locked")) |actual| {
        std.log.err("expected interactable.text-locked to be of type 'string' or 'array' found '{s}'", .{@tagName(actual)});
    }

    // text-locked
    if (table.getString("text-locked")) |text| {
        iabl.text_locked = .{ .single = try game.createText(text) };
    } else if (table.getArray("text-locked")) |text_array| {
        _ = text_array;
        std.debug.panic("TODO: implement randomized text", .{});
    } else if (table.table.get("text-locked")) |actual| {
        std.log.err("expected interactable.text-locked to be of type 'string' or 'array' found '{s}'", .{@tagName(actual)});
    }

    // require
    if (try getAssertType([]const u8, table, "require", .string)) |text| {
        iabl.require = try predicate_config.load(game, text);
    }

    // on-interact
    if (try getAssertType([]const u8, table, "on-interact", .string)) |text| {
        iabl.on_interact = try action_config.load(game, text);
    }

    // on-interact-locked
    if (try getAssertType([]const u8, table, "on-interact-locked", .string)) |text| {
        iabl.on_interact_locked = try action_config.load(game, text);
    }

    // hidden
    if (try getAssertType(bool, table, "hidden", .boolean)) |value| {
        iabl.hidden = value;
    }

    // once
    if (try getAssertType(bool, table, "once", .boolean)) |value| {
        iabl.once = value;
    }
}

fn getAssertType(comptime T: anytype, table: Table, key: []const u8, comptime expectedType: anytype) !?T {
    const value = table.table.get(key) orelse return null;

    switch (value) {
        expectedType => |x| return x,
        else => {
            std.log.err("expected interactable.{s} to be of type '{s}' but was '{s}'", .{ key, @tagName(expectedType), @tagName(value) });
            return error.InvalidInteractable;
        },
    }
}
