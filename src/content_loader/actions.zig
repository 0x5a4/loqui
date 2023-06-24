const std = @import("std");
const mem = std.mem;

const config = @import("../config.zig");
const components = @import("../components.zig");

const Game = @import("../Game.zig");
const Action = components.Action;

pub fn load(game: *Game, action_text: []const u8) config.ContentError!Action {
    const separator = mem.indexOfScalar(u8, action_text, ':') orelse return error.InvalidAction;

    const id = action_text[0..separator];
    const param = action_text[(separator + 1)..];

    if (mem.eql(u8, id, "move")) {
        if (param.len == 0) {
            std.log.err("action '{s}' expects a parameter, found none", .{id});
            return error.InvalidAction;
        }

        const param_index = try game.createActionParam(param);
        return Action{ .move = param_index };
    } else if (mem.eql(u8, id, "give-item")) {
        if (param.len == 0) {
            std.log.err("action '{s}' expects a parameter, found none", .{id});
            return error.InvalidAction;
        }

        const param_index = try game.createActionParam(param);
        return Action{ .give_item = param_index };
    } else if (mem.eql(u8, id, "remove-item")) {
        if (param.len == 0) {
            std.log.err("action '{s}' expects a parameter, found none", .{id});
            return error.InvalidAction;
        }

        const param_index = try game.createActionParam(param);
        return Action{ .move = param_index };
    } else {
        std.log.err("unrecognized action type '{s}'", .{id});
        return error.InvalidAction;
    }
}
