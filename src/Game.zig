const std = @import("std");
const components = @import("components.zig");
const interface = @import("interface.zig");

const Self = @This();

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const HashMap = std.AutoHashMap;
const StringHashMap = std.StringHashMap;
const StringSet = StringHashMap(void);
const AllocError = Allocator.Error;

pub const RuntimeError = error{
    InvalidStartingRoom,
} || AllocError;

pub const Player = struct {
    room_index: usize,
    inventory: StringSet,

    pub fn init(alloc: Allocator) Player {
        return Player{
            .room_index = 0,
            .inventory = StringSet.init(alloc),
        };
    }

    pub fn deinit(self: *Player, alloc: Allocator) void {
        var item_iter = self.inventory.keyIterator();
        while (item_iter.next()) |key| {
            alloc.free(key.*);
        }
        self.inventory.deinit();

        self.* = undefined;
    }
};

pub const Config = struct {
    starting_room: ?[]const u8,
    startup_text: ?usize,

    pub fn deinit(self: *Config, alloc: Allocator) void {
        if (self.starting_room) |starting_room_ptr| {
            alloc.free(starting_room_ptr);
        }
    }
};

alloc: Allocator,

player: Player,
config: Config,

rooms: ArrayList(components.Room),
room_map: StringHashMap(usize),

interactables: ArrayList(components.Interactable),
interactables_locked: HashMap(usize, void),

text: ArrayList([]const u8),
text_randomized: ArrayList([]const usize),

action_params: ArrayList([]const u8),
predicate_params: ArrayList([]const u8),

commands: StringHashMap(*const components.CommandFn),

pub fn init(alloc: Allocator) Self {
    return Self{
        .alloc = alloc,
        .config = Config{
            .starting_room = null,
            .startup_text = null,
        },
        .player = Player.init(alloc),
        .rooms = ArrayList(components.Room).init(alloc),
        .room_map = StringHashMap(usize).init(alloc),
        .interactables = ArrayList(components.Interactable).init(alloc),
        .interactables_locked = HashMap(usize, void).init(alloc),
        .text = ArrayList([]const u8).init(alloc),
        .text_randomized = ArrayList([]const usize).init(alloc),
        .action_params = ArrayList([]const u8).init(alloc),
        .predicate_params = ArrayList([]const u8).init(alloc),
        .commands = StringHashMap(*const components.CommandFn).init(alloc),
    };
}

pub fn run(self: *Self) RuntimeError!void {
    // apply config
    if (self.config.starting_room) |starting_room| {
        if (self.room_map.get(starting_room)) |room_index| {
            self.player.room_index = room_index;
        } else {
            std.log.err("non-existent starting room '{s}'", .{starting_room});
            return RuntimeError.InvalidStartingRoom;
        }
    }

    if (self.config.startup_text) |text_index| {
        self.print("{s}\n", .{self.text.items[text_index]});
    }

    // Used to hold the current command and its args.
    // Decreases the amount of allocations performed drastically, since it will quickly reach a capacity
    // that is sufficient for every command.
    // Also avoids creating the buffer, deallocating it and immediatly recreating it.
    var command_buffer = ArrayList([]const u8).init(self.alloc);
    defer command_buffer.deinit();

    while (true) {
        defer command_buffer.shrinkRetainingCapacity(0);

        var answer = self.prompt("") orelse break;
        defer self.alloc.free(answer);

        // split args
        var answer_splitter = std.mem.splitScalar(u8, answer, ' ');
        while (answer_splitter.next()) |part| {
            if (part.len == 0) continue;
            try command_buffer.append(part);
        }

        if (command_buffer.items.len == 0) continue;
        const command_name = command_buffer.items[0];
        const command_args = command_buffer.items[1..];

        if (self.commands.get(command_name)) |commandfn| {
            try commandfn(command_name, command_args, self);
        } else if (std.mem.eql(u8, command_name, "quit")) {
            break;
        } else {
            self.print("unknown command '{s}'\n", .{command_name});
        }
    }
}

pub fn prompt(self: *Self, question: []const u8) ?[]const u8 {
    var stdout = std.io.getStdOut().writer();
    var stdin = std.io.getStdIn().reader();

    return interface.prompt(self.alloc, question, stdout, stdin, .{
        .answer_prefix = "> ",
        .same_line = true,
    }) catch {
        stdout.writeByte('\n') catch {};
        return null;
    };
}

pub fn print(_: *const Self, comptime fmt: []const u8, args: anytype) void {
    var stdout = std.io.getStdOut().writer();
    stdout.print(fmt, args) catch {};
}

pub fn executeAction(self: *Self, action: components.Action) AllocError!void {
    switch (action) {
        .none => {},
        .move => |param_index| {
            const param = self.action_params.items[param_index];

            const room_index = self.room_map.get(param) orelse {
                std.log.err("action tried to move player to invalid room '{s}'", .{param});
                return;
            };

            self.player.room_index = room_index;
        },
        .give_item => |param_index| {
            const param = self.action_params.items[param_index];

            if (!self.player.inventory.contains(param)) {
                // all of this feels wrong. maybe count items upfront and guarantee room?
                // another table maybe?
                const item = try self.alloc.dupe(u8, param); 
                try self.player.inventory.put(item, {});
            }
        },
        .remove_item => |param_index| {
            const param = self.action_params.items[param_index];

            _ = self.player.inventory.remove(param);
        },
    }
}

pub fn checkPredicate(self: *const Self, predicate: components.Predicate) bool {
    switch (predicate) {
        .none => return true,
        .item => |param_index| {
            const param = self.predicate_params.items[param_index];
            return self.player.inventory.contains(param);
        },
    }
}

pub fn showText(self: *const Self, text: components.Text) void {
    switch (text) {
        .none => {},
        .single => |text_index| {
            self.print("{s}\n", .{self.text.items[text_index]});
        },
        .randomize => {
            std.debug.panic("TODO: implement randomized text", .{});
        },
    }
}

pub fn interactWith(self: *Self, interactable_index: usize) !void {
    if (self.interactables_locked.contains(interactable_index)) {
        return;
    }

    const interactable = self.interactables.items[interactable_index];

    if (self.checkPredicate(interactable.require)) {
        if (interactable.once) {
            try self.interactables_locked.put(interactable_index, {});
        }

        try self.executeAction(interactable.on_interact);
        self.showText(interactable.text);
    } else {
        try self.executeAction(interactable.on_interact_locked);
        self.showText(interactable.text_locked);
    }
}

/// Creates a new Room and returns a pointer to it.
/// Correctly adds the room to both the room array and the room map.
/// If a room with that id already exists, returns a pointer to that instead
///
/// The returned pointer is only valid until a new room is added.
/// The id is duped using, so the original is still owned by the caller.
pub fn createRoom(self: *Self, id: []const u8) AllocError!*components.Room {
    if (self.room_map.get(id)) |room_index| {
        return &self.rooms.items[room_index];
    }

    const new_id = try self.alloc.dupe(u8, id);
    errdefer self.alloc.free(new_id);
    var room = components.Room.init(self.alloc, new_id);
    errdefer room.deinit(self.alloc);

    const index = self.rooms.items.len;
    const room_ptr = try self.rooms.addOne();
    errdefer _ = self.rooms.pop();
    room_ptr.* = room;

    try self.room_map.put(new_id, index);
    errdefer _ = self.room_map.remove(new_id);

    std.log.debug("created room '{s}'", .{new_id});

    return room_ptr;
}

/// Creates a new Interactable and returns a pointer to it.
/// Correctly adds the Interactable to both the interactables array and
/// the rooms internal reference array.
///
/// The returned pointer is only valid until a new interactable is added.
/// Both id and group duped, so the original is still owned by the caller.
pub fn createInteractable(
    self: *Self,
    room: *components.Room,
    id: []const u8,
    group: ?[]const u8,
) AllocError!*components.Interactable {
    const new_id = try self.alloc.dupe(u8, id);
    errdefer self.alloc.free(new_id);

    const index = self.interactables.items.len;
    const interactable_ptr = try self.interactables.addOne();
    errdefer _ = self.interactables.pop();
    interactable_ptr.* = components.Interactable.init(new_id, null);

    try room.interactables.put(new_id, index);
    errdefer _ = room.interactables.remove(new_id);

    if (group) |group_name| {
        const maybe_group = try room.groups.getOrPut(group_name);
        if (!maybe_group.found_existing) {
            maybe_group.key_ptr.* = try self.alloc.dupe(u8, group_name);
            maybe_group.value_ptr.* = ArrayList(usize).init(self.alloc);
        }

        interactable_ptr.*.group = maybe_group.key_ptr.*;
        try maybe_group.value_ptr.*.append(index);
    }

    std.log.debug("created interactable '{s}'(group: {s}) in room '{s}'", .{
        new_id,
        group orelse "default",
        room.id,
    });

    return interactable_ptr;
}

/// Creates a new command.
///
/// The id is duped, so the original is still owned by the caller.
pub fn createCommand(self: *Self, id: []const u8, commandfn: *const components.CommandFn) AllocError!void {
    var new_id = try self.alloc.dupe(u8, id);
    errdefer self.alloc.free(new_id);

    try self.commands.put(
        new_id,
        commandfn,
    );

    std.log.debug("created command '{s}'", .{new_id});
}

/// Creates a new text in the text array and returns its index.
///
/// The text is duped, so the original is still owned by the caller.
pub fn createText(self: *Self, text: []const u8) AllocError!usize {
    var new_text = try self.alloc.dupe(u8, text);
    errdefer self.alloc.free(new_text);

    const index = self.text.items.len;
    try self.text.append(new_text);

    std.log.debug("created new text", .{});

    return index;
}

/// Creates a new randomized text in the randomized text array and returns its index.
///
/// Each text is duped, so the original is still owned by the caller.
pub fn createRandomizedText(self: *Self, randomized_text: [][]const u8) AllocError!usize {
    var list = try self.alloc.alloc(usize, randomized_text.len);
    errdefer self.alloc.free(list);

    const list_index = self.text_randomized.items.len;
    try self.text_randomized.append(list);
    errdefer _ = self.text_randomized.pop();

    try self.text.ensureUnusedCapacity(list.len);

    const base_index = self.text.items.len;
    var i: usize = 0;
    while (i < list.len) : (i += 1) {
        var new_text = try self.alloc.dupe(u8, list[i]);
        self.text.appendAssumeCapacity(new_text);
        list[i] = base_index + i;
    }

    std.log.debug("created new randomized text with {} options", .{list.len});

    return list_index;
}

/// Creates a new action parameter in the action_params array and returns its index.
///
/// The parameter is duped, so the original is still owned by the caller.
pub fn createActionParam(self: *Self, param: []const u8) AllocError!usize {
    var new_param = try self.alloc.dupe(u8, param);
    errdefer self.alloc.free(new_param);

    const index = self.action_params.items.len;
    try self.action_params.append(new_param);

    std.log.debug("created new action parameter", .{});

    return index;
}

/// Creates a new predicate parameter in the predicate_params array and returns its index.
///
/// The parameter is duped, so the original is still owned by the caller.
pub fn createPredicateParam(self: *Self, param: []const u8) AllocError!usize {
    var new_param = try self.alloc.dupe(u8, param);
    errdefer self.alloc.free(new_param);

    const index = self.predicate_params.items.len;
    try self.predicate_params.append(new_param);

    std.log.debug("created new predicate param", .{});

    return index;
}

pub fn deinit(self: *Self) void {
    self.config.deinit(self.alloc);
    self.player.deinit(self.alloc);
    self.interactables.deinit();
    self.interactables_locked.deinit();

    freeAll(u8, self.alloc, self.text);
    freeAll(usize, self.alloc, self.text_randomized);
    freeAll(u8, self.alloc, self.action_params);
    freeAll(u8, self.alloc, self.predicate_params);

    // free rooms
    var i: usize = 0;
    while (i < self.rooms.items.len) : (i += 1) {
        self.rooms.items[i].deinit(self.alloc);
    }
    self.rooms.deinit();

    // free room map
    var room_map_iter = self.room_map.keyIterator();
    while (room_map_iter.next()) |key| {
        self.alloc.free(key.*);
    }
    self.room_map.deinit();

    // free commands
    var command_iter = self.commands.keyIterator();
    while (command_iter.next()) |key| {
        self.alloc.free(key.*);
    }
    self.commands.deinit();

    self.* = undefined;
}

fn freeAll(comptime T: anytype, alloc: Allocator, list: ArrayList([]const T)) void {
    var i: usize = 0;
    while (i < list.items.len) : (i += 1) {
        alloc.free(list.items[i]);
    }
    list.deinit();
}
