# rsprite API reference

Every function and option in rsprite. For installation and a quick start, see the [README](../README.md).

## Functions

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

## Chains

`Draw`, `SetSource` and `Resolve` accept a single source or an ordered array of sources. Each entry may be a sprite name, a sprite id, or a plugin resource such as `Plugin.resources.my_icon`. The first existing entry is used.

A `nil` entry terminates the array, so chains must not contain gaps. An empty chain, or one with no existing entry, draws the placeholder unless `placeholder = false` is passed.

## Options

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

## Items

- `nil` means no item. `DrawItem(parent, nil)` returns a hidden sprite, and `SetItem(sprite, nil)` clears and hides it and returns `false`. Neither warns or shows the placeholder.
- Any other id that is not a whole number 0 or above logs one warning and shows the placeholder, unless `placeholder = false`.
- A valid item id without an icon draws nothing.
- `SetSource` and `SetItem` can switch a single sprite between an item icon and a sprite.

## Search

`Find(text, options)` matches each word against names, tags and aliases, ignoring case. Exact matches rank first, and curated sprites rank above others.

Options are `tags` (tag names to filter by), `limit` (default 50) and `offset`. Each entry is `{ name, id, tags, aliases, width, height }`, with dimensions present only when known.

An empty query lists every sprite, with `tags`, `limit` and `offset` still applied. The index is built on the first search; call `rsprite.BuildIndex()` at startup to spread that work over several ticks.

## Errors and warnings

- Missing sprites return `nil` and log one `rsprite:` warning per name.
- Invalid arguments and options raise an error at the caller's line.
- Runtime problems never raise.

## Notes

- Sprites are drawn at a fixed size, 24 by 24 by default. `Find` reports a sprite's native size when it is known.
- Names are read from the running client, so they always match the current game build.
- Sprites known to crash the game client are treated as missing.
