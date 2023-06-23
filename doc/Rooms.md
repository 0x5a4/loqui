# Rooms
Rooms are the most basic thing a game is made from.  
The player can and will **always** be in **one** room exactly and can only interact with things in this room.  

*(Keep in mind that "Room" is not meant literally, but could also be an outside area.)*

## Layout

Rooms have the following properties:
 name         | required? | type   | description
--------------|-----------|--------|-----------------
id            | yes       | string | used to identify this room in e.g. doors
doors         | no        | array  | a list of doors attached to this room
interactables | no        | array  | a list of interactables attached to this room

## Syntax
```toml
# Note: values within "<>" brackets need to be replaced with something
# <room-id> should be replaced with e.g. "kitchen"

# A simple room can be created like this. 
[rooms.<room-id>]
```
## Attaching Interactables
For an explanation of interactables and their fields, see [their own page](Interactables.md).

```toml
# Note: values within "<>" brackets need to be replaced with something
# <id> should be replaced with e.g. "drawer"

# Attaching an interactable is as simple as this:
# if the <room-id> doesn't already exist, it is automatically created 
[rooms.<room-id>.interactables.<id>]
# fields

# because 'interactables' is anoying to type there's also a shorthand
[rooms.<room-id>.iabl-<id>]
# fields

```

## Creating Doors
Since doors are such a common thing, and are rather tedious to create using
the normal Interactable-Syntax, they have a special shortcut!

They automatically move the player to the room whose name is the id of the door.

```toml
# Note: values within "<>" brackets need to be replaced with something
# <to> should be replaced with e.g. "kitchen"

# if the <room-id> doesn't already exist, it is automatically created 
[rooms.<room-id>.doors.<to>]
text = "You enter the room this door leads to!"
# All Interactable fields except "on-interact" can be overwritten here!

```

