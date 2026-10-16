// Members the 2017 code uses that stock MonoGame 3.8 lacks: XNA 4.0 members MonoGame
// dropped, and additions from FreeSO's MonoGame fork (not checked out here). C# 14
// extension members add them without editing the 2017 sources.
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;

namespace FSO.Oracle.Stubs
{
    public static class MonoGameForkExtensions
    {
        extension(Color)
        {
            /// <summary>XNA 4.0's transparent black: every channel zero.</summary>
            public static Color TransparentBlack => new Color(0, 0, 0, 0);
        }

        extension(RenderTarget2D target)
        {
            /// <summary>
            /// FreeSO's fork lets a render target share another's depth buffer. The
            /// oracle never renders, so this only has to compile.
            /// </summary>
            public void InheritDepthStencil(RenderTarget2D source)
            {
            }
        }
    }
}
