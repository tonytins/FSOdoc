<p align="center">
    <picture>
      <img alt="SimsCraft" src="docs/assets/logo.svg" width="200">
    </picture>
  </a>
</p>

<h1 align="center">SimsCraft</h1>

<p align="center">
  <b>an open-source Swift reimplementation of FreeSO's engine-agnostic libraries.</b><br>
  File I/O, content loading, and SimAntics<br>
  Backwards compatible with 1.0 and Beta
</p>

## Background

This started as FSOdoc, an ill-fated attempt to document FreeSO's sparsely commented code using just ChatGPT. This was before stuff like Claude Code or Copilot even existed. Naturally, it didn't go exactly as planned. Probably would have taken hundreds of hours to even get remotely close.

But my long term goal has always been to start fresh with a new language and engine. Now that all this stuff is finally a thing, I have begun reimplementing the reimplementation in Swift, with the aid of AI, and trying out new things, like a [scripting language](./NSOClient/SimsScript/README.md)!

My version, NewSO (NSOClient), does differ ever so slightly. Mine was built against TSO Beta because that's all I was able to get extracted properly on Linux; the old EA downloaders no longer worked. So in order to keep things running smoothly, mine is backwards compatible.

<!--
FSOdoc is a fork of FreeSO that aims to address the lack of documentation in the original project. FSOdoc focuses on a specific snapshot (Aug 9, 2017) of FreeSO’s source code and uses the power of AI to generate comments and documentation to aid in understanding the logic behind the codebase.

## Background

As a reimplementation of The Sims Online, FreeSO is a complex project that uses Monogame as its framework. However, large chunks of the source code have gone uncommented for years, making it challenging for individual developers, including myself, to study, improve, or derive from the codebase. This lack of documentation has been a major hindrance to fully understanding the project’s inner workings.

### Fixing the Documentation Gap

FSOdoc seeks to fix this documentation gap by utilizing AI to aid in generating comments and documentation for the previously uncommented sections of the code. The AI-powered commenting process provides a better understanding of the logic behind each individual method, which in turn helps to improve comprehension of the project as a whole. With FSOdoc, I finally have a means to address the lack of documentation without spending excessive hours and resources.
 --->

## Getting around

| Folder | Holds |
| --- | --- |
| [`NSOClient/`](./NSOClient/) | The Swift code: independent Swift packages for the file formats (TSOFiles), content (TSOContent), and the SimAntics VM (SimAntics), plus tools and SimsScript |
| [`TSOClient/`](./TSOClient/) | FreeSO's C# source as of August 9, 2017, the reference NSOClient is checked against. It's read, never changed |
| [`docs/`](./docs/README.md) | How FreeSO and NSOClient work, the plan, and the results, with a glossary of terms |

To build and test, you need Swift 6 (and the .NET 10 SDK to compare with FreeSO). You don't need
the game: tests run on [`NSOClient/MockInstall`](./NSOClient/MockInstall/README.md), a tiny made-up
install, and skip what needs the real one.

```sh
swift test --package-path NSOClient/SimAntics
```

Start with [docs/README.md](./docs/README.md). The rules for changing the code, for people and AI
assistants alike, are in [AGENTS.md](./AGENTS.md). The game's files are EA's and never go in the
repository.

## Licensing

SimsCraft, like its parent project FreeSO, is licensed under the MPL-2.0 (Mozilla Public License 2.0). This open-source license allows for free use, modification, and distribution of the codebase.

---

<p align="center">
  <i>It's all coming back to you! 🪃</i>
</p>