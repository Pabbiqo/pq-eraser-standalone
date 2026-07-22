pq-eraser-standalone

Someone needed an eraser that removes tiles across all selected layers and levels. Since Automapper/pq-tools 5.0 is still unfinished and may take a while longer, I am sharing this small standalone tool in case anyone else needs it.

Options

Choose the highest level to erase (1–32)

Ignore the Floor layer on level 0

Delete BMP0 colors

Delete BMP1 colors

Prepare RoomDefs for removal

Installation

Add the following entry to your LuaTools.txt:

tool
{
    label = Layer Eraser on All Levels
    icon = tool-pq-eraser.png
    script = tool-pq-eraser.lua
    dialog-title = Layer Eraser on All Levels
}

Usage

Click and drag to erase a larger area. A single click erases one tile (1×1) across all selected layers and levels.

If the selected area contains RoomDefs and the RoomDef option is enabled, a blue selection box remains after erasing. Remove the selected RoomDefs with:

Tools -< RoomDefecator -> Remove RoomDefs

Compatibility

This tool has only been tested with Alree's B42 tools. I could not find a way to delete RoomDefs with a single click using Alree's tools.
