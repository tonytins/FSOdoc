# Introduction to SimAntics

> From the SimAntics Wiki ([Introduction to SimAntics](https://simantics.wikidot.com/wiki:introduction-to-simantics), [Edith](https://simantics.wikidot.com/wiki:edith), [Interactions](https://simantics.wikidot.com/wiki:interactions)), retrieved 2026-10-16, by its contributors, under
> [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/). Converted to Markdown and lightly
> edited; sections headed "Notes for NSOClient" are ours. See [README.md](README.md).

**SimAntics** is a [CISC](http://en.wikipedia.org/wiki/Complex_instruction_set_computing) bytecode language which powers the objects in The Sims and The Sims Online.

Development of SimAntics was coordinated by Jamie Doornbos with the help of Patrick J. Barrett III and Don Hopkins.

## Model

SimAntics assembly is assembled into bytecode which is executed within a virtual thread granted to that object. Altogether, the virtual threads are executed synchronously (one after the other) in a nonpreemptive virtual machine, the SimAntics environment.

Each object eventually relinquishes its control to the next object by calling the idle primitive or returning error; a return value of error tells the machine to kill the object and remove it from the lot, and in debug builds of the game, prompting a message that the object has crashed and providing its stack dump.

## Terminology

- action
- advertisement
- attenuation
- autonomy
- behavior
- bitfield
- check
- entry point
- function
- global
- local
- menu
- node
- object definition
- parameter
- primitive
- private
- scenario
- semiglobal
- slot
- stack object
- tree
- tuning constant
- variable

### Initialisms

- SAS, CAS: Select-A-Sim, Create-A-Sim
- GZ: Gonzo, a Maxis game development framework
- RZ: Rizzo, built on top of Gonzo
- EASTL: EA's Standard Template Library replacement, now released under the GPL: [https://github.com/paulhodge/EASTL](https://github.com/paulhodge/EASTL)
- LMS: Language Markup System
- EOD: What it stands for is unknown, but it refers to custom menus that override the panel at the bottom of the screen when your Sim is dancing or playing black jack, for example.
- AWC

## Text language

Edith provides a menu option (File -> Save all behaviors…) that disassembles all of the behaviors in the game into txt files, categorized by their containing IFF files. Before looking at the binary structure of behaviors, it helps to first look at this text representation.

The first line of the disassembly is the name of the IFF file, sans the file extension. For example, in behaviorscuckooclock.txt,
cuckooclock

Following this line is the disassembly for each behavior in the IFF file, sorted by ascending chunk ID. The first behavior in cuckooclock.iff is named "main":
(main).000 Stack Object ID 0 assign ( := ) My object id true:1
(main).001 Global: Idle (with ticks=10) true:2
(main).002 Private: process true:1

As in C and C++, the main function is where execution for the object begins. When our particular object is added to the lot and run for the first time in Live mode, the object's ID will be written into the "Stack Object ID 0" variable. Upon true, it will branch to the instruction at index 1—in our case, simply the next one down. As the branch destination for false has not been specified, it is implicitly defined to error; that is, if the result of the instruction were false, the program would "branch" to error, deleting itself and informing the virtual machine that it has "crashed". Note that an object can delete itself off the lot at any time, without informing the virtual machine of a crash, by simply branching to true or false in the main function. The cuckooclock does not ever delete itself, however, so the only way to remove it is by selecting it with the hand tool and deleting it, which can be seen as "force closing" the process.

The second instruction performs the "idle for X ticks" global with X=10; this relinquishes the object's execution context and returns true after 10 ticks have passed; in response, the program will branch to the instruction at index 2.

The third instruction calls a private subroutine named "process" defined in the very same IFF file and then branches back to the previous instruction. In this short loop, we can see that this subroutine, "process", must return true to hand the context back to the virtual machine.

## Edith

Objects for the game were programmed in an assembly intermediary of SimAntics using a developer tool called **Edith**, which is named after the first character produced for the game, Edith Bunker, and also stands for **Edit Hierarchies** or **Edit House**. The tool employs a box-and-arrow tree layout, in which each box describes an instruction and then points to one or more other boxes to direct control flow. This layout was designed and implemented by Jamie Doornbos. The workspace was saved as metadata with the objects and was normally stripped before release; the NPCs, however, did not have their workspaces stripped, and they can be read along with their comments by the 3rd-party clone of Edith called [Codex](http://niotso.org/Codex.zip).

Along with providing a tool editing interface, Edith allowed the programmer to load the Edith window alongside the game to immediately test newly created objects; thus, the E key was the "Edit House" command.

Edith was not officially released outside of Maxis but was demonstrated in short videos by Don Hopkins, which can be found on [the Movies section](http://www.donhopkins.com/home/movies/) of [his website](http://www.donhopkins.com/), specifically, in this order:

1. [The Sims Pie Menus (Edith demonstration)](http://www.donhopkins.com/home/movies/TheSimsPieMenus.mov) (47.1MB / 49,471,706 bytes)
1. [Free The Sims Demo](http://www.donhopkins.com/home/movies/FreeTheSimsDemo.mov) (7.94MB / 8,329,392 bytes)
1. [Transmogrifier Demo](http://www.donhopkins.com/home/movies/TransmogrifierDemo.mov) (5.23MB / 5,493,860 bytes)
1. [Object Exporter Demo](http://www.donhopkins.com/home/movies/ObjectExporterDemo.mov) (0.97MB / 1,026,770 bytes)
1. [Person Exporter Demo](http://www.donhopkins.com/home/movies/PersonExporterDemo.mov) (1.50MB / 1,578,455 bytes)

EA also allowed a computer science class taught by Kenneth D. Forbus at Northwestern University in May 2001 and May 2002 to use Edith as part of their curriculum, but no students ever saved the software. Some documents were provided to the public describing the virtual machine:

- [Under the hood of The Sims](http://www.cs.northwestern.edu/~forbus/c95-gd/lectures/)
- [Programming Objects in The Sims](http://www.qrg.northwestern.edu/papers/Files/Programming_Objects_in_The_Sims.pdf) (1.31MB / 1,383,488 bytes)

The text strings used in the GUI for Edith are shipped with the game in both The Sims 1 and The Sims Online in a file named `behavior.iff`. Numerical constants as well can be found in the OTF files in the globals folder as well as the C++ headers located in the UIGraphics folder of both games.

### Leak

Edith has been known since early 2012 to have been leaked in the final version of EA-Land. On December 22, 2012, a patch was released by Fatbag which launches Edith instead of the game. The patch can be downloaded here (please keep a copy of the entire original, unmodified game in a separate folder):

- [Edith.bps](http://niotso.org/files/Edith.bps)
- [Patch tool](http://byuu.org/programming/beat/)

Certain features, such as spawning new instances of objects on a lot and debugging them, are inactive without a working game lot.

## Interactions

**Interactions** are functions that can be queued onto objects or people by other objects or the player. Each interaction has a priority; if this is less than the interaction after it then the interaction is automatically canceled. Interactions are normally defined by Tree Tables (TTAB), but occasionally they directly execute functional trees not referenced by TTAB. Not much is known about interactions right now.

## Notes for NSOClient

In FreeSO's update-46, an error result unwinds the thread's whole stack. Any other failure inside a thread
resets the object, and a dialog reports it, at most once every 20 seconds. An object that fails
again within that window is deleted. See [FSO.SimAntics](../fso/simantics.md#executing-behavior).
