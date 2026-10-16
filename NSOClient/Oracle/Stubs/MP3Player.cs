// Stands in for FSO.Common's MP3Player (excluded: it needs Mp3Sharp). The oracle runs
// without audio, and the HIT code that uses this is never reached headless.
using System;
using Microsoft.Xna.Framework.Audio;

namespace FSO.Common.Audio
{
    public class MP3Player : IDisposable
    {
        public MP3Player(string path)
        {
            throw new NotSupportedException("The oracle runs without audio.");
        }

        public DynamicSoundEffectInstance Inst => null;

        public bool IsEnded() => true;

        public void Stop()
        {
        }

        public void Dispose()
        {
        }
    }
}
