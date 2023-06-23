# Interactables
Interactables could be described as the thing that makes games fun.  
All of the below can be implemented using Interactables:
- NPCs
- Signs
- Chests containing Items
- Teleporters
- basically anything that breaks down to 'push button -> perform action'

## Layout
An Interactable consists of the following properties

 name              | required? | type                 | description
-------------------|-----------|----------------------|-----------------
id                 | yes       | string               | used to identify this interactable. must be unique on a room-level
group              | no        | string               | used to group interactables together
display-name       | no        | string               | used instead of the id if this is displayed somewhere
text               | no        | string/array<string> | text displayed when successfully interacted with. If this is an array, an options is chosen at random
text-locked        | no        | string/array<string> | text displayed when successfully interacted with. If this is an array, an options is chosen at random
require            | no        | predicate            | prohibts interaction if the predicate isnt true
on-interact        | no        | action               | executed if interacted with
on-interact-locked | no        | action               | executed if interacted with, while `require` is not fulfilled
hidden             | no        | bool                 | indicates that this interactable should be hidden
once               | no        | bool                 | lock this interactable after successfully being interacted with once. Does not lock if `require` is not fulfilled

## Groups
*As a wise man once said: a person is, in fact, not a door.* 

Groups are useful if a command should only be applicable to a specific type of interactable. Touching a chest may lead to opening it, but touching a person 
wont make them talk to you and will most likely get you arrested.  

Interactables are always part of the default group.

## Syntax

## Examples
