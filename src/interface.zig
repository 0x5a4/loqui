const std = @import("std");
const ansi = @import("ansi-term");

pub const PromptOptions = struct {
    /// whether to erase both prompt and answer when done
    erase: bool = true,

    /// accept empty answers
    accept_empty: bool = false,

    /// if set to false, does not check the question for newlines which will break
    /// erasing and retrying in case of an empty answer.
    /// implied if "erase and not accept_empty"
    unsafe: bool = false,

    /// whether the question should be on the same line as the answer
    same_line: bool = false,

    /// printed right before the answer(e.g. > for a command-line style prompt)
    /// if this contains newlines, breakage will occur!
    answer_prefix: ?[]const u8 = null,
};

/// Prints the specified question to the given writer, waits for the user to answer and returns the answer.
///
/// Caller owns returned memory.
pub fn prompt(
    alloc: std.mem.Allocator,
    question: []const u8,
    outStream: anytype,
    inStream: anytype,
    options: PromptOptions,
) ![]const u8 {
    var buffer = std.ArrayList(u8).init(alloc);
    var stream = buffer.writer();
    errdefer buffer.deinit();

    // line occupied by prompt and answer combined, used for erasing
    var lines_occupied = blk: {
        if (!options.erase and options.accept_empty) break :blk 1;
        if (options.unsafe) break :blk 1;

        var i: u32 = 1;
        for (question) |char| {
            if (char == '\n') i += 1;
        }

        if (!options.same_line) {
            i += 1;
        }

        break :blk i;
    };

    try ansi.cursor.saveCursor(outStream);
    try outStream.writeAll(question);

    while (true) {
        if (!options.same_line) {
            try outStream.writeByte('\n');
        } else if (question.len > 0) {
            try outStream.writeByte(' '); // no one wants question and answer right beside each other
        }

        if (options.answer_prefix) |answer_prefix| {
            try outStream.writeAll(answer_prefix);
        }

        try inStream.streamUntilDelimiter(stream, '\n', null);

        if (buffer.items.len > 0 or options.accept_empty) {
            break;
        } else {
            try ansi.cursor.cursorUp(outStream, 1);
            try ansi.clear.clearCurrentLine(outStream);
            try ansi.cursor.cursorUp(outStream, 1);

            if (options.same_line) {
                try ansi.cursor.restoreCursor(outStream);
                try outStream.writeAll(question);
            }
        }
    }

    if (options.erase) {
        var i: u32 = 0;
        while (i < lines_occupied) : (i += 1) {
            try ansi.cursor.cursorUp(outStream, 1);
            try ansi.clear.clearCurrentLine(outStream);
        }
    }

    return try buffer.toOwnedSlice();
}
