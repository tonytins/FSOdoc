#!/usr/bin/env python3
"""Writes synthetic blueprint XML for comparing room maps with fso-oracle room-maps.

    python3 -I make_blueprints.py OUTPUT_DIR

FreeSO's shipped blueprints have floors but no walls, so these lots exercise what they
can't: rooms walled in (style 1) and fenced (other styles), diagonal walls with a floor on
each half, pools, upper floors with and without floor, walls on the lot's edges (FreeSO's
fill wraps around), and values .NET truncates or ignores (patterns past 65535, segments
that are 0 or negative). The lots are random but the same on every run.

Writes OUTPUT_DIR/synthetic-NNN.xml and OUTPUT_DIR/blueprints.txt, the list of files.
They contain no game data.
"""

import os
import random
import sys

LOTS = 60
SIZES = [6, 8, 10, 12, 16, 20, 24, 32]

TOP_LEFT, TOP_RIGHT, BOTTOM_RIGHT, BOTTOM_LEFT = 1, 2, 4, 8
HORIZONTAL_DIAGONAL, VERTICAL_DIAGONAL = 16, 32


class Lot:
    def __init__(self, size):
        self.size = size
        self.floors = {}  # (level, x, y) -> pattern
        self.pools = set()
        self.walls = {}  # (level, x, y) -> dict of attributes

    def wall(self, level, x, y):
        return self.walls.setdefault((level, x, y), {"segments": 0, "tls": 0, "trs": 0, "tlp": 0,
                                                     "trp": 0, "brp": 0, "blp": 0})

    def in_lot(self, x, y):
        return 0 <= x < self.size and 0 <= y < self.size

    def edge(self, level, x, y, side, style):
        """A wall on a tile's top-left (x) or top-right (y) edge."""
        if not self.in_lot(x, y):
            return
        tile = self.wall(level, x, y)
        if side == "x":
            tile["segments"] |= TOP_LEFT
            tile["tls"] = style
            if self.in_lot(x - 1, y):
                self.wall(level, x - 1, y)["segments"] |= BOTTOM_RIGHT
        else:
            tile["segments"] |= TOP_RIGHT
            tile["trs"] = style
            if self.in_lot(x, y - 1):
                self.wall(level, x, y - 1)["segments"] |= BOTTOM_LEFT

    def xml(self):
        lines = ['<?xml version="1.0" encoding="utf-8"?>', "<house>", f"  <size>{self.size}</size>",
                 "  <category>0</category>", "  <world>", "    <floors>"]
        for (level, x, y), pattern in sorted(self.floors.items()):
            lines.append(f'      <floor level="{level}" x="{x}" y="{y}" value="{pattern}" />')
        lines += ["    </floors>", "    <walls>"]
        for (level, x, y), tile in sorted(self.walls.items()):
            attributes = " ".join(f'{key}="{value}"' for key, value in tile.items())
            lines.append(f'      <wall level="{level}" x="{x}" y="{y}" {attributes} placement="0" />')
        lines += ["    </walls>", "    <pools>"]
        for x, y in sorted(self.pools):
            lines.append(f'      <pool x="{x}" y="{y}" value="0" />')
        lines += ["    </pools>", "  </world>", "  <objects />", "</house>", ""]
        return "\n".join(lines)


def rectangle(rng, size):
    x0, y0 = rng.randrange(0, size), rng.randrange(0, size)
    return x0, y0, min(size, x0 + rng.randrange(1, size // 2 + 2)), min(size, y0 + rng.randrange(1, size // 2 + 2))


def floor_pattern(rng):
    return rng.choice([1, 2, 3, 9, 10, 25, 0, 65534, 70001])


def wall_style(rng):
    return rng.choice([1, 1, 1, 1, 2, 3, 255])


def room(rng, lot, level):
    """A rectangle of walls, sometimes with a gap, and its floor."""
    x0, y0, x1, y1 = rectangle(rng, lot.size)
    style = wall_style(rng)
    gap = rng.random() < 0.3
    for y in range(y0, y1):
        lot.edge(level, x0, y, "x", style)
        lot.edge(level, x1, y, "x", style)
    for x in range(x0, x1):
        lot.edge(level, x, y0, "y", style)
        lot.edge(level, x, y1, "y", style)
    if gap:
        key = (level, rng.randrange(x0, x1), y0)
        if key in lot.walls:
            lot.walls[key]["segments"] &= ~TOP_RIGHT
    if rng.random() < 0.7:
        pattern = floor_pattern(rng)
        for x in range(x0, x1):
            for y in range(y0, y1):
                lot.floors[(level, x, y)] = pattern


def diagonal(rng, lot, level):
    """A run of diagonal walls with a floor pattern on each half."""
    x, y = rng.randrange(lot.size), rng.randrange(lot.size)
    vertical = rng.random() < 0.5
    first, second = floor_pattern(rng), floor_pattern(rng)
    for _ in range(rng.randrange(1, lot.size)):
        if not lot.in_lot(x, y):
            break
        tile = lot.wall(level, x, y)
        tile["segments"] = VERTICAL_DIAGONAL if vertical else HORIZONTAL_DIAGONAL
        tile["tls"], tile["tlp"], tile["trs"] = first, second, rng.choice([0, 1])
        x += 1
        y += 1 if vertical else -1


def noise(rng, lot, level, count):
    """Walls with arbitrary segments, styles, and patterns."""
    for _ in range(count):
        tile = lot.wall(level, rng.randrange(lot.size), rng.randrange(lot.size))
        tile["segments"] = rng.choice([0, -1, 64, rng.randrange(1, 64), rng.randrange(1, 16)])
        tile["tls"], tile["trs"] = wall_style(rng), wall_style(rng)
        tile["tlp"] = floor_pattern(rng)


def make_lot(index):
    rng = random.Random(index)
    lot = Lot(rng.choice(SIZES))
    kind = index % 4
    # Ground floor: patches of floor over bare ground.
    for _ in range(rng.randrange(0, 6)):
        x0, y0, x1, y1 = rectangle(rng, lot.size)
        pattern = floor_pattern(rng)
        for x in range(x0, x1):
            for y in range(y0, y1):
                lot.floors[(0, x, y)] = pattern
    for _ in range(rng.randrange(0, 3)):
        x0, y0, x1, y1 = rectangle(rng, lot.size)
        lot.pools.update((x, y) for x in range(x0, x1) for y in range(y0, y1))
    levels = [0] if kind == 0 else [0, 1] if kind == 1 else [0, 1, 2]
    for level in levels:
        for _ in range(rng.randrange(1, 6)):
            room(rng, lot, level)
        if kind >= 2:
            for _ in range(rng.randrange(1, 4)):
                diagonal(rng, lot, level)
        if kind == 3:
            noise(rng, lot, level, lot.size * 2)
    if index % 10 == 0:
        # A wall all the way around, on the lot's edges.
        for i in range(lot.size):
            lot.edge(0, 0, i, "x", 1)
            lot.edge(0, i, 0, "y", 1)
    return lot


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    output = sys.argv[1]
    os.makedirs(output, exist_ok=True)
    names = []
    for index in range(LOTS):
        name = f"synthetic-{index:03}.xml"
        with open(os.path.join(output, name), "w", encoding="utf-8") as file:
            file.write(make_lot(index).xml())
        names.append(os.path.join(output, name))
    with open(os.path.join(output, "blueprints.txt"), "w", encoding="utf-8") as file:
        file.write("\n".join(names) + "\n")


if __name__ == "__main__":
    main()
