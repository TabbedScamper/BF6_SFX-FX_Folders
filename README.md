# BF6 SFX & FX Folders

Place the game's **visual effects (FX)** and **sounds (SFX)** in your Portal
maps straight from the Object Library — organized into a tidy **FX** and
**SFX** folder per map instead of flooding the library with 1,400 entries.

- **471 FX** and **941 SFX** as placeable objects, each wrapped in the SDK's
  own spawnable-object pattern — the level validator and the Portal exporter
  treat them exactly like any other placed object.
- **Folder view**: every map's asset grid gets an `FX` and an `SFX` folder at
  the top. Double-click to browse (map-exclusive effects first, then the
  global set); Back returns to the map's props. The tab bar stays clean.
- **Per-map validity** built in: placing an effect on a map that doesn't
  support it shows the standard configuration warning with the list of valid
  maps.

## Install

1. Download **`bf6_sfx_fx.zip`** from the
   [latest release](https://github.com/TabbedScamper/BF6_SFX-FX_Folders/releases/latest)
   and extract it into your Portal SDK Godot **project folder** (it merges
   into `addons/bf6_sfx_fx/`). Any folder under `addons/` works too.
2. Enable **BF6 SFX & FX Folders** under Project → Project Settings → Plugins.
3. In the **SFX & FX** dock (top right), hit **Install / Repair**.
4. Restart the editor. Open any map — the Object Library now shows the FX and
   SFX folders.

Everything the installer does is reversible: it keeps backups and the dock's
**Restore stock library view** button puts the original Scene Library back.
Effects already placed in your levels keep working either way.

## What the installer changes

| Step | What | Undo |
|---|---|---|
| Library content | Extracts the wrapper scenes/scripts to `objects/fx`, `objects/audio`, `scripts/fx`, `scripts/audio` | Files are inert if unused; kept on restore so placed effects don't break |
| Folder view | Replaces the Scene Library addon's script with the folder-view build | Original backed up as `scene_library.gd.stock`, restored by the Restore button |
| Collections | Adds the per-map FX/SFX collections to `scene_library.json` | Pre-install backup kept; Restore removes only these collections |

## Credits

The folder view is a modified build of the
[Scene Library](https://github.com/mansurisaev/scene-library) addon by Mansur
Isaev and contributors (MIT), which the Portal SDK uses for its Object
Library. The original license is included at
`addons/bf6_sfx_fx/scene_library_patch/LICENSE.md`.

Companion projects:
[BF6 High-Poly Preview](https://github.com/TabbedScamper/BF6_High_Poly_Godot_Plugin)
· [BF6 Model Viewer](https://github.com/TabbedScamper/BF6_Model_Viewer)
