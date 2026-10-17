# FSO.HIT: audio

FSO.HIT (`TSOClient/tso.sound`) reimplements HIT, Maxis's sound engine
from The Sims and TSO. Like SimAntics, HIT is a bytecode VM: sound
designers wrote small programs (tracks) that choose samples, loop, duck
other sounds, and react to game variables. FreeSO interprets those
programs and plays the samples through MonoGame's `SoundEffect` API.

The formats are read by [FSO.Files](./files.md#other-formats) (`HIT/`,
`UTK/`, `XA/`) and loaded by the content system's
[`Audio`](../../TSOClient/tso.content/Audio.cs) provider.

## How it works (update-46)

### Pieces

| Type | Role |
| --- | --- |
| [`HITVM`](../../TSOClient/tso.sound/HITVM.cs) | Singleton (`HITVM.Init`, `HITVM.Get`). Holds the running sounds, global variables, the four volume groups (FX, music, voice, ambience), and the current music. `Tick` is called once per frame from `TSOGame.Update`. |
| [`HITThread`](../../TSOClient/tso.sound/HITThread.cs) | One running track: its bytecode, registers, local variables, playing notes, and owners (the objects that keep it alive). |
| [`HITInterpreter`](../../TSOClient/tso.sound/HITInterpreter.cs) | One static method per opcode (about 100): arithmetic, comparisons, jumps and waits, note on and off, "smart" random choice from hitlists, ducking, and track control. |
| [`HITSound`](../../TSOClient/tso.sound/HITSound.cs) | Base for anything `HITVM` ticks, with volume, pan, and owner tracking. |
| [`HITTVOn`](../../TSOClient/tso.sound/Events/HITTVOn.cs) | Special handler for the `kTurnOnTV` event used by TVs, radios, and music stations. It plays a random `.xa` file from a station folder, or streams MP3 through `MP3Player` (see [common.md](./common.md#utilities)). |
| [`FSCPlayer`](../../TSOClient/tso.sound/FSCPlayer.cs) | Plays `.fsc` music sequences (timed sample lists). |
| [`AmbiencePlayer`](../../TSOClient/tso.sound/AmbiencePlayer.cs) | Loops lot ambience. |

### Playing a sound

Sounds start by event name:
`HITVM.Get().PlaySoundEvent("lot_enter")`. The name is lower-cased and
looked up in `Audio.Events`, a table built at startup from the `EVT` file
of every HIT resource group. If the same event is already playing, the
existing sound is returned instead of starting a second one. Otherwise
`HITVM` creates a `HITThread` for the event's track (or a `HITTVOn` for
`kTurnOnTV`) and ticks it every frame until it ends. One hard-coded
special case maps `piano_play` to `playpiano`, with a comment saying TSO
must have done the same.

Notes become `SoundEffect`s through `Audio.GetSFX`, which decodes UTK or
XA data on first use and keeps the result in `SFXCache`, a plain
dictionary that is never trimmed.

Callers:

- SimAntics: the Play Sound Event primitive (`VMPlaySound`) plays the
  event named by an object's `FWAV` chunk and attaches the thread to the
  object, so stopping or deleting the object stops the sound. Avatars
  also start voice events, and some network commands play UI sounds.
  Every SimAntics call is guarded with `VM.UseWorld`, so a headless
  server never touches audio.
- UI: buttons, the build mode panel, and interaction icons play UI
  events directly.

### Threading

Everything runs on the game thread in `TSOGame.Update`. There is no
separate mixer thread; MonoGame's backend (XAudio2 on DirectX builds,
OpenAL on DesktopGL) does the mixing.

## Modern .NET rewrite

### Approach

Keep the interpreter. It is self-contained, mostly pure logic over a
byte array, and easy to test. Port it as a library with no MonoGame
reference, behind a small playback interface:

```csharp
namespace FSO.HIT;

/// <summary>Plays decoded PCM for the HIT interpreter.</summary>
public interface ISoundOutput
{
    ISoundVoice Play(ReadOnlyMemory<byte> pcm, int sampleRate, int channels, bool loop);
}

public interface ISoundVoice : IDisposable
{
    bool IsPlaying { get; }
    void SetVolume(float volume, float pan);
}
```

This is a sketch and has not been compiled. The client implements the
interface with MonoGame's `SoundEffect`. Tests implement it with a fake
that records calls, so track behavior can be checked without audio
hardware.

### Changes

- **Singleton.** Replace `HITVM.Get()` with an instance passed in through
  DI or through the SimAntics presentation interface (see
  [simantics.md](./simantics.md#decouple-from-rendering)). The
  `VM.UseWorld` guards then become "no audio service registered".
- **Opcode table.** Replace the delegate array indexed by opcode with a
  `switch` over an `enum HitOpcode`, or keep the table but make it
  `static readonly` and bounds-checked. An unknown opcode in a corrupt file
  should end the thread, not throw.
- **Decoding.** UTK and XA decoders stay in FSO.Files and return PCM.
  Replace the unbounded `SFXCache` with a size-limited cache, since a long
  session otherwise keeps every sound it has ever played in memory.
- **MP3.** See [common.md](./common.md#modern-net-rewrite). NLayer is a
  managed, cross-platform decoder.
- **Paths.** `HITTVOn` lists station folders with `Directory.GetFiles`.
  Resolve them through the content system's case-insensitive index (see
  [content.md](./content.md#changes)), because station folder names in
  the original install mix case.
- **Backend.** MonoGame DesktopGL uses OpenAL Soft, which works on all
  three desktop platforms. FreeSO's client ships `soft_oal.dll` by hand;
  stock MonoGame packages include the native library per runtime.
