# Body Strings

> From the SimAntics Wiki ([Body Strings](https://simantics.wikidot.com/wiki:body-strings)), retrieved 2026-10-16, by its contributors, under
> [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/). Converted to Markdown and lightly
> edited; sections headed "Notes for NSOClient" are ours. See [README.md](README.md).

Body Strings are a special type of string resource held by Person type objects which hold information on that person's appearance, gender, name(s, eg for random selection), person type (eg. adult, child, cat or dog) and other things. The meaning of each field is documented here:

| Index | Name | Notes |
|---|---|---|
| 0 | Type | Defines what type of avatar this object is. Valid values include "adult", "cat", "dog" and "child", though children are not present in TSO. |
| 1 | Body Outfit | The resource ID of the default body outfit for this avatar. In The Sims 1, this is instead a string identifier to the mesh. |
| 2 | Head Outfit | The resource ID of the default head outfit for this avatar. In The Sims 1, this is instead a string identifier to the mesh. |
| 3 | Head Bone | Always "HEAD". Assumed meaning comes from block caps and following reference to R_HAND |
| 4 | "Top" | The string "Top". Not quite sure. |
| 5 | Slot 0 Bone | The bone name of the bone to be used to position objects carried by the avatar (in slot 0). Always "R_HAND". |
| 6 | "Palm" | The string "Palm" |
| 7 | Blank | N/A |
| 8 | Blank | N/A |
| 9 | Random Body ID | A semicolon separated list of outfit IDs to be considered for this avatar's body. If not empty, this is used instead of field 1 to determine a body. |
| 10 | Random Head ID | A semicolon separated list of outfit IDs to be considered for this avatar's head. If not empty, this is used instead of field 1 to determine a head. |
| 11 | Names | A semicolon separated list of names this person can be assigned. For example, the maid has many possible names, and the cat template defaults to "Fido" |
| 12 | Gender | Defines this avatar's gender. Valid values are "male", "female", "catmale", "catfemale", "dogmale", "dogfemale" |
| 13 | Age | Usually around 27. |
| 14 | Skin tone | Light = lgt, Medium = med, Dark = drk |
| 15 | Unused in TSO | Appears to be id for nightwear. |
| … | … | … |
| 30 | Appearance ID | Only present on template person. May be proxy sim appearance? |
