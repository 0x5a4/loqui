# Actions
Actions give life to interactables. Without them they are nothing more than a sign with some text on it.

They are specified like this:  
`<action-id>:<param>`

These actions exist:
 id          | param         | description
-------------|---------------|---------------
give-item    | item-id       | gives the player an item
remove-item  | item-id       | removes the item with the given id from the players inventory. if the inventory does not contain that item, nothing happens
move         | room-id       | moves the player to a different room
