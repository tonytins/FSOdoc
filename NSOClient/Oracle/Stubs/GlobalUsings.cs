// The 2017 sources import both System.Drawing and Microsoft.Xna.Framework, which only
// worked because the 2017 build had no System.Drawing.Color in scope. Modern .NET does,
// so this alias picks XNA's Color, the one the 2017 code means.
global using Color = Microsoft.Xna.Framework.Color;
global using FSO.Oracle.Stubs;
