# rsprite

Name based sprite lookup, search and drawing for the RS3 plugin API.

> **Status:** early development. Not yet on the Plugin Hub. Tested against game client `950-1`.

![The rsprite finder window, with a grid of sprite previews beside the details and copy boxes for the selected sprite](docs/images/finder.png)

rsprite is a dependency free Lua library that resolves sprites by name, searches the full sprite catalogue, and draws sprites and item icons with consistent sizing, fallbacks and error handling. It works with or without PrettyUI.

## Installation

rsprite is not yet on the Plugin Hub and must be installed manually, using either:

- **A release:** unzip the `rsprite` zip from the [latest release](https://github.com/sereselene/rsprite/releases) into the client's development plugins folder.
- **A clone:** copy `plugins/rsprite` into the same folder. This tracks `main` rather than a tested release.

Declare the dependency in your plugin's `plugin.json`:

```json
{
  "requiredDependencies": {
    "rsprite": "rsprite"
  }
}
```

In the game console, run `prf`, then `prl rsprite`, then load your plugin. The client exposes rsprite as the global `rsprite`, named after the dependency key, so no `require` is needed.

Once rsprite is published, replace `"rsprite"` with its Plugin Hub id. The client then installs it automatically for players.

## Example

```lua
local attackId = rsprite.Get("SKILL_ATTACK")

local icon = rsprite.Draw(parent, { "SKILL_NECROMANCY", "BP3_MISSION_ICON_SKILL_NECROMANCY", Plugin.resources.my_icon }, {
    x = 10,
    y = 10,
    size = 24,
})

local ring = rsprite.DrawItem(parent, 13562, { x = 40, y = 10, size = 24 })
```

- `Get` resolves a name to an id, case insensitively.
- `Draw` draws the first chain entry that exists. `SKILL_NECROMANCY` does not exist, so the mission icon is used. If no entry exists, a grey placeholder is drawn.
- `DrawItem` draws an item icon by item id.

## API

| Function | Description |
| --- | --- |
| `rsprite.version` | Library version, as `"X.Y.Z"`. |
| `rsprite.Get(name)` | Sprite id for a name, or `nil`. Case insensitive and cached. |
| `rsprite.Name(id)` | Sprite name for an id, or `nil`. Cached. |
| `rsprite.Resolve(nameOrChain)` | First existing source in a chain and its position, or `nil`. |
| `rsprite.Draw(parent, nameOrChain, options)` | Creates a `ui.Sprite` from the first existing source. Returns the sprite and the position used. |
| `rsprite.SetSource(sprite, nameOrChain, options)` | Sets an existing sprite to a new chain, clearing any item icon set by rsprite. Returns the position used. |
| `rsprite.DrawItem(parent, itemId, options)` | Creates a `ui.Sprite` showing an item icon. Returns the sprite. |
| `rsprite.SetItem(sprite, itemId, options)` | Shows an item icon on an existing sprite. Returns `true` if an item is shown. |
| `rsprite.Find(text, options)` | Searches names, tags and aliases. Returns the matching entries and the total match count. |
| `rsprite.Tags()` | All filterable tags, sorted alphabetically. |
| `rsprite.BuildIndex(onReady)` | Builds the search index over several ticks, then calls `onReady` with the sprite count. Calls it immediately if the index is ready. |
| `rsprite.IsIndexReady()` | Whether the search index is ready. |

### Chains

`Draw`, `SetSource` and `Resolve` accept a single source or an ordered array of sources. Each entry may be a sprite name, a sprite id, or a plugin resource such as `Plugin.resources.my_icon`. The first existing entry is used.

A `nil` entry terminates the array, so chains must not contain gaps. An empty chain, or one with no existing entry, draws the placeholder unless `placeholder = false` is passed.

### Options

| Option | Used by | Description |
| --- | --- | --- |
| `x`, `y` | `Draw`, `DrawItem` | Position within the parent, in interface units. Any finite number. Default 0. |
| `xAnchor`, `yAnchor` | `Draw`, `DrawItem` | Reference point in the parent as a fraction of its width and height: 0 is the left or top edge, 0.5 the centre, 1 the right or bottom edge. Any finite number. Default 0. |
| `size` | `Draw`, `DrawItem` | Width and height. Finite and above 0. Default 24. |
| `width`, `height` | `Draw`, `DrawItem` | Individual dimensions, overriding `size`. Finite and above 0. |
| `colour` | `Draw`, `SetSource` | Tint as a packed `0xRRGGBBAA` number. |
| `alpha` | `Draw`, `SetSource` | Opacity from 0 to 1. |
| `quantity` | `DrawItem`, `SetItem` | Stack count shown on the item. Whole number, 0 or above. |
| `placeholder` | `Draw`, `SetSource`, `DrawItem`, `SetItem` | Whether to draw the placeholder when no source exists. Default `true`. |

### Items

- `nil` means no item. `DrawItem(parent, nil)` returns a hidden sprite, and `SetItem(sprite, nil)` clears and hides it and returns `false`. Neither warns or shows the placeholder.
- Any other id that is not a whole number 0 or above logs one warning and shows the placeholder, unless `placeholder = false`.
- A valid item id without an icon draws nothing.
- `SetSource` and `SetItem` can switch a single sprite between an item icon and a sprite.

### Search

`Find(text, options)` matches each word against names, tags and aliases, ignoring case. Exact matches rank first, and curated sprites rank above others.

Options are `tags` (tag names to filter by), `limit` (default 50) and `offset`. Each entry is `{ name, id, tags, aliases, width, height }`, with dimensions present only when known.

An empty query lists every sprite, with `tags`, `limit` and `offset` still applied. The index is built on the first search; call `rsprite.BuildIndex()` at startup to spread that work over several ticks.

### Errors and warnings

- Missing sprites return `nil` and log one `rsprite:` warning per name.
- Invalid arguments and options raise an error at the caller's line.
- Runtime problems never raise.

### Notes

- Sprites are drawn at a fixed size, 24 by 24 by default. `Find` reports a sprite's native size when it is known.
- Names are read from the running client, so they always match the current game build.
- Sprites known to crash the game client are treated as missing.

## Finder

`rsprite-finder` is a separate development plugin for browsing sprites. It requires rsprite and PrettyUI, and must not be listed as a dependency.

Install it from the same release, or copy `plugins/rsprite-finder` from a clone, then run `prl rsprite-finder`. Open it from the finder's settings cog in the Plugin Hub's Manage list, using **OPEN FINDER**.

- Search by name, tag or alias, filter by tag, and star favourites.
- Browse 30 previews per page, with full names on hover.
- View a selected sprite at 16 to 64 px on a dark, light or checkerboard background, with its id, size, tags, aliases and numbered variants.
- Copy its name, or a ready to paste `Get`, `Draw` or PrettyUI snippet.
- Group numbered variants and hide mobile and language copies, both enabled by default in the settings cog.

The finder remembers its state between sessions. If the client closes during a draw, the sprites being drawn are hidden and the finder reopens on page 1. **Show hidden sprites again** on the settings cog restores them.

## Using rsprite with PrettyUI

rsprite supplies sprites to PrettyUI components rather than replacing them. Pass the result of `Resolve` to any component that accepts a sprite id or image, such as `Sprite`, `SimpleButton` or `BuffBar`:

```lua
local close = rsprite.Resolve({ "CLOSE_BUTTONS_0", Plugin.resources.close_fallback })
prettyui.Sprite.new(parent, close, { size = 16 })
```

## Contributing

Suggest tags or aliases, report bugs, or report a sprite that crashes the game client, using the forms on the [issue tracker](https://github.com/sereselene/rsprite/issues).

## Licence

PolyForm Strict 1.0.0. See the [licence](https://github.com/sereselene/rsprite/blob/main/LICENSE).

You can install rsprite and use it from your own plugins through the Plugin Hub dependency. You can't copy, change or republish the code, or build new works from it. It's for noncommercial use only: free plugins that accept donations are fine, paid or paywalled plugins are not.

Using this code to train AI models, or as input to AI tools that produce derivative code, is not permitted.

Versions up to and including 0.1.1 were released under the MIT licence.
