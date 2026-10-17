# SimAntics reference (from the SimAntics Wiki)

A Markdown copy of the [SimAntics Wiki](https://simantics.wikidot.com/), a community reference for
the scripting language behind objects and Sims in The Sims and The Sims Online. It describes what
the game does; the [FreeSO docs](../fso/simantics.md) describe how FreeSO's update-46 snapshot implements it.
Where the two disagree, FreeSO's code is what NSOClient matches, and the "Notes for NSOClient"
sections at the end of each page say so.

| Page | What it covers |
| --- | --- |
| [Introduction](introduction.md) | The model, terminology, the text form of behaviors, Edith, interactions |
| [Primitives](primitives.md) | Every TSO primitive by opcode, with operand layouts, modes, and flags |
| [Generic Sims Online Call](generic-sims-online-call.md) | The calls behind primitive 1 |
| [Scopes](scopes.md) | Variable scopes, including the object definition fields |
| [Object Data](object-data.md) | The 80 values every object has |
| [Person Data](person-data.md) | The values every Sim has |
| [Motive Data](motive-data.md) | Motives, also used for advertisements |
| [Global Data](global-data.md) | The lot's global values |
| [Body Strings](body-strings.md) | A Sim's appearance strings |
| [Walking Animations](walking-animations.md) | Animations the walking engine uses |

The wiki is unfinished, and much of it is marked as guesswork. Treat it as a map, and check
anything that matters against FreeSO's code or `fso-oracle` (see `NSOClient/FSO.Oracle/README.md`).

## License and attribution

These pages are adapted from the SimAntics Wiki at <https://simantics.wikidot.com/>, by its
contributors (see each page's history there), retrieved 2026-10-16. The wiki is licensed under the
[Creative Commons Attribution-ShareAlike 3.0 License](https://creativecommons.org/licenses/by-sa/3.0/),
and so are these adapted pages, including the "Notes for NSOClient" sections added to them. The
license covers this folder only; the rest of the repository is unaffected.

Changes from the original:

- Converted from HTML to Markdown, with tables and links kept.
- The Edith and Interactions pages are merged into the introduction.
- Operand tables are rewritten as byte ranges, and wiki markup leftovers fixed.
- Links to pages the wiki never wrote (entry points, balloon icons) became plain text.
- Notes comparing the text with FreeSO's code (update-46) were added.

Left out: the front page, which is only navigation, and the glossary, which is an empty template.
