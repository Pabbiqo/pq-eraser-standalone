# pq-eraser-standalone
Someone needed an eraser that deletes tiles across all layers and levels. Since Automapper/pq-tools 5.0 is still unfinished for more Weeks, im sharing this small standalone tool in case anyone else needs it.

Options:

Choose the highest level to erase (1–32)
Ignore the Floor layer on level 0
Delete BMP colors from BMP0/BMP1
Prepare RoomDefs for removal

Add the following entry to your LuaTools.txt:
``
tool
{
    label = Layer Eraser on All Levels
    icon = tool-pq-eraser.png
    script = tool-pq-eraser.lua
    dialog-title = Layer Eraser on All Levels
}
``
If the selected area contains RoomDefs, a blue selection box remains after erasing. To remove them, select:

Tools -> RoomDefecator -> Remove RoomDefs

A single Click deletes only 1x1 Space on all Layers awell.

This tool has only been tested with Alrees B42 tools. I could not find a way to delete RoomDefs with a single click using Alrees tools.
