const std = @import("std");
const StringHashMap = std.StringHashMap;

const ArrayList = std.ArrayList;
const Game = @import("Game.zig");

/// Callback function for a Command
pub const CommandFn = fn (name: []const u8, args: [][]const u8, game: *Game) void;

pub const Room = struct {
    /// id of this room.
    /// The Room does NOT own this memory.
    id: []const u8,

    interactables: StringHashMap(usize),
    groups: StringHashMap(ArrayList(usize)),

    /// Creates a new Room with the given id.
    /// The id is owned by the caller.
    pub fn init(alloc: std.mem.Allocator, id: []const u8) Room {
        return Room{
            .id = id,
            .interactables = StringHashMap(usize).init(alloc),
            .groups = StringHashMap(ArrayList(usize)).init(alloc),
        };
    }

    /// Releases memory allocated by the underlying data structures.
    /// This does NOT release the id!
    pub fn deinit(self: *Room, alloc: std.mem.Allocator) void {
        // interactables
        var i_iter = self.interactables.keyIterator();
        while (i_iter.next()) |key| {
            alloc.free(key.*);
        }
        self.interactables.deinit();

        // groups
        var g_iter = self.groups.iterator();
        while (g_iter.next()) |entry| {
            alloc.free(entry.key_ptr.*);
            entry.value_ptr.deinit();
        }
        self.groups.deinit();
    }
};

/// the tag is the predicate type, contained value is an index into
/// the Game.predicate_params array or void if no param is required
pub const Predicate = union(enum) {
    none: void,
    item: usize,
};

/// the tag is the predicate type, contained value is an index into
/// the Game.action_params array or void if no param is required
pub const Action = union(enum) {
    none: void,
    move: usize,
    give_item: usize,
    remove_item: usize,
};

// If this is of type .single then the contained value is an index into
// the Game.text array
//
// If this is of type .randomize then the contained value is an index into
// the Game.text_randomized array, which contains even more indices into the
// Game.text array to be randomized from
pub const Text = union(enum) {
    none: void,
    single: usize,
    randomize: usize,
};

pub const Interactable = struct {
    /// id of this interactable,
    /// the interactable does NOT own this memory.
    id: []const u8,

    /// group this interactable is in,
    /// the interactable does NOT own this memory.
    group: ?[]const u8,

    /// index into Game.text
    display_name: ?usize,

    text: Text,
    text_locked: Text,

    require: Predicate,
    on_interact: Action,
    on_interact_locked: Action,

    hidden: bool,
    once: bool,

    pub fn init(id: []const u8, group: ?[]const u8) Interactable {
        return Interactable{
            .id = id,
            .group = group,
            .display_name = null,
            .text = Text{ .none = {} },
            .text_locked = Text{ .none = {} },
            .require = Predicate{ .none = {} },
            .on_interact = Action{ .none = {} },
            .on_interact_locked = Action{ .none = {} },
            .hidden = false,
            .once = false,
        };
    }
};
