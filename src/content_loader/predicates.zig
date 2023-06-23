const std = @import("std");
const mem = std.mem;

const Game = @import("../Game.zig");
const Predicate = @import("../components.zig").Predicate;

pub fn load(game: *Game, predicate_text: []const u8) !Predicate {
    const separator = mem.indexOfScalar(u8, predicate_text, ':') orelse return error.InvalidAction;

    const id = predicate_text[0..separator];
    const param = predicate_text[(separator + 1)..];

    if (mem.eql(u8, id, "item")) {
        if (param.len == 0) {
            std.log.err("action '{s}' expects a parameter, found none", .{id});
            return error.InvalidAction;
        }

        const param_index = try game.createPredicateParam(param);
        return Predicate{ .item = param_index };
    } else {
        std.log.err("unrecognized predicate type '{s}'", .{id});
        return error.InvalidAction;
    }
}
