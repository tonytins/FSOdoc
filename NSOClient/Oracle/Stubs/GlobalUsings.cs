// The 2017 sources import both System.Drawing and Microsoft.Xna.Framework, which only
// worked because FreeSO's build had no System.Drawing.Color in scope. Modern .NET does,
// so this alias picks XNA's Color, the one FreeSO's code means.
global using Color = Microsoft.Xna.Framework.Color;
global using FSO.Oracle.Stubs;
