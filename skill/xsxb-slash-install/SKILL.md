---
name: xsxb-slash-install
description: Install a XSXB-Slash export (recipe.json + textures/*.png) as a sword / weapon slash trail in Unity, Godot 4 or Unreal Engine 5. Use when the user has a XSXB-Slash zip or folder and wants it working on a weapon in their game project.
---

# Install a XSXB-Slash trail

The export is engine-neutral. The exact contract (strip UVs, shader formula, units) is in `docs/SPEC.md` of the XSXB-Slash repo. The reference code for each engine is in `engines/<engine>/`. Do not invent a new shader: port these files, they already match the web preview.

## 1. Find out what you have

- The export folder: `recipe.json`, `textures/shape.png`, `textures/mask.png`, `textures/highlight.png`, `preview.png`. Read `recipe.json`; check `format == "XSXB-Slash-recipe"` and `version == 1`.
- The engine: `ProjectSettings/ProjectVersion.txt` → Unity; `project.godot` → Godot; `*.uproject` → Unreal.
- The weapon: ask the user which object is the blade if it is not obvious. You need two points on it: **hilt** (base of the blade) and **tip**. Create two empty child objects / sockets if they do not exist.

## 2. Import textures (all engines)

- All three are **data, not colour**: sRGB / "Color texture" OFF.
- `shape.png`, `highlight.png`: wrap **Clamp**. `mask.png`: wrap **Repeat**.
- No compression that destroys greyscale gradients if avoidable (Unity: R8 or default is fine; Unreal: Masks or Grayscale; Godot: default is fine).

## 3. Engine steps

### Unity (Built-in or URP)
1. Copy `engines/unity/XsxbSlashTrail.shader` and `XsxbSlashTrail.cs` into `Assets/XsxbSlashTrail/`.
2. Copy `recipe.json` into Assets (it imports as a TextAsset) and the textures with the import settings above.
3. Player Settings → Color Space should be **Linear**. If the project is Gamma, convert the recipe colours to gamma in `XsxbSlashTrail.cs` (`Mathf.LinearToGammaSpace`) before setting them.
4. Add `XsxbSlashTrail` to the weapon (or any object), assign recipe, hilt, tip, the 3 textures and the shader `XSXB-Slash/Layer`.
5. HDRP is not covered by this shader; write an HDRP Unlit Shader Graph with the same formula if needed.

### Godot 4
1. Copy `engines/godot/*` into `res://addons/xsxb_slash/` (the shaders `#include` that exact path).
2. Copy `recipe.json` and the textures into the project.
3. Add a `XsxbSlashTrail` node (script `xsxb_slash_trail.gd`), set `recipe_path`, `hilt`, `tip`, the 3 textures.
4. For HDR > 1 to glow: WorldEnvironment → Glow on, HDR threshold about 1.

### Unreal Engine 5
1. Copy `engines/unreal/XsxbSlashTrailComponent.h/.cpp` into a C++ module; add `"ProceduralMeshComponent", "Json"` to its Build.cs dependencies and enable the ProceduralMeshComponent plugin. Add the module's API macro to the class if it is used from another module.
2. Make two materials (Unlit, Two Sided, Translucent / Additive) with one Custom node each, body = `XsxbSlashLayer.hlsl`, inputs and parameter names as listed at the top of that file. Emissive = rgb, Opacity = a.
3. Import the textures (Compression: Masks or Grayscale, sRGB off, tiling as above).
4. Add `XsxbSlashTrailComponent` to the weapon actor, attach it to the weapon mesh, set `HiltSocket`, `TipSocket`, `RecipeFile`, textures and both materials.
5. If the project cannot use C++, a Niagara ribbon also works, but U must be the particle's **normalised age** (ribbon renderer U0 override bound to NormalizedAge) and UV1 must be tiled from the start in metres. Check it with debug mode 1 (below) — this is where ports usually go wrong. In that case feed the Custom node's `XU` input from the same normalised age (no texture fill).

## 4. Verify (required, do not skip)

Run the self-check in `docs/SPEC.md` section 5 and report what you saw:

1. `debugMode = 1`: strip is black/green at the blade and red at the tail; the **outer** edge (tip path) is green. Flipped green → swap V. Black tail → swap U.
2. `debugMode = 2`: stripes stay fixed in the world as the strip ages.
3. `debugMode = 0`: take a screenshot over a background like `recipe.preview.background` and compare with `preview.png`. Too thin / too dark usually means a texture still has sRGB on or the shape was sampled at `sv` instead of `1 - sv` (or the other way round).

## Already installed: switch to a new trail

When the trail is already working in the project and the user exports a new one ("use this trail", "switch to this one"), do not reinstall and do not touch the code:

1. Find the existing install: the recipe file the component reads (`recipe_path` / `RecipeFile` / the `recipe` TextAsset) and the three imported textures it uses.
2. Back up those four files, then overwrite them with the new `recipe.json` and `textures/*.png`, keeping the same file names / asset paths so every reference stays valid. Keep the import settings (sRGB off; Clamp / Repeat).
3. Reimport the textures. Unreal: reimport the existing texture assets (editor, or a headless editor script while the editor is closed). Unity / Godot: the editor reimports on focus.
4. The recipe is read when the trail starts; restart play (or the component) to pick it up. Layer count, colours, widths, lives and `fx` numbers all come from the recipe.
5. Verify as in section 4 (debugMode 0 screenshot vs the new `preview.png`) and tell the user which preview-only features (refraction, gnaw, wobble, colour over age, UV offsets) the engine port does not draw.

## Clean combos

- Wire `emitting` (Unity `emitting`, Godot `emitting`, Unreal `bEmitting`) to the attack's active window: animation events / notifies on, off at the end. Do not leave it on for a whole combo.
- `widthScale` = blade length in metres.
- If arcs look polygonal or detached, check the frame rate first (see SPEC section 2), then that sampling happens after animation.

## Common mistakes

- **Weapon mesh rotated in the hand.** A weapon imported as its own file and attached to a bone can carry the importer's axis fix (e.g. Godot adds a -90° X rotation to a Z-up FBX mesh node; bones keep their source-engine local frames). If the sword is authored for that bone (Unreal sockets/bones attach with no extra rotation), reset that node's transform. Do not trust markers parented to the same node as proof: compare the grip against the original engine or a reference pose.

- Using the engine's built-in trail with U on length: the shape and dissolve slide wrongly. Use the scripts here.
- Converting the linear colours to linear a second time (Godot `source_color`, Unity `Color` gamma conversions).
- Forgetting units: recipe is in **metres and seconds**; Unreal works in centimetres (the component converts).
- Drawing layers in the wrong order: `recipe.layers[0]` is the bottom layer.
