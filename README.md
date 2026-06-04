# hexdraw

A tool for drawing, solving, and exporting spell patterns from [Hex Casting](https://github.com/FallingColors/HexMod), a magic mod for Minecraft.

In Hex Casting, spells are cast by tracing continuous paths across a triangular hex grid. The shape of the path determines what the spell does. hexdraw lets you design these patterns visually, find every valid way a given pattern can be drawn on the grid, and export the results as PNG images or animated GIFs.

---

## Features

- **Draw mode** - freehand path drawing on a zoomable hex grid; drag from either endpoint to extend or prepend
- **Type mode** - enter a spell signature directly (`a q w e d`) and see it rendered in real time
- **Solver** - exhaustive search for all valid ways a pattern can be placed on the grid; results are browsable in a gallery
- **Export** - copy to clipboard, save PNG, or render an animated GIF (trace or pulse animation)
- **Palettes** - three built-in colour gradients plus custom start/end HSB palettes
- **Presets** - save named patterns; 14 example spells included by default
- **Settings** - arc mode, grid dots, stroke width, animation speed, background colour, and more; all persisted in `config.json`

---

## Running

**Requirements:** Java 17 or newer. Tested on Linux and Windows; macOS should work but is untested.

```
java -jar hexdraw.jar
```

The window is resizable. Size and position are remembered between sessions. `config.json` and the `exports/` folder are created next to the JAR.

---

## Keyboard shortcuts

| Key | Action |
|-----|--------|
| `S` | Solve current pattern |
| `I` | Save PNG + copy to clipboard |
| `J` | Export animated GIF |
| `H` | Toggle arc mode |
| `G` | Toggle grid dots |
| `Tab` | Fit / re-centre pattern |
| `Ctrl+Z` | Undo last draw step |
| `Ctrl+Backspace` | Clear pattern |
| `Ctrl+V` | Paste signature |
| `1`-`5` | Open/close panels |
| `Backspace` / Right-click | Return to playground from gallery |

---

## Building from source

Requires the [Processing IDE](https://processing.org/download) installed.

```
bash build-jar.sh
```

The script expects Processing to be installed at its default location. Edit the path at the top of `build-jar.sh` if yours differs.

---

## License

Copyright (C) 2025 listlessvoid. Licensed under the [GNU General Public License v3.0](LICENSE).

Spell patterns are based on the [Hex Casting](https://github.com/FallingColors/HexMod) mod by petrak@, licensed under LGPL 2.1.

This project uses [Processing](https://processing.org) (LGPL 2.1) and the NeuQuant/GIF encoder by Kevin Weiner (public domain).
