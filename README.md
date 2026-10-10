# rsprite

Find and draw any RuneScape 3 sprite in one line.

![The rsprite finder window, with a grid of sprite previews beside the details and copy boxes for the selected sprite](docs/images/finder.png)

rsprite is a small library for developers working with the RuneScape 3 plugin API that makes finding and using the game's sprites painless. It looks names up safely, searches every sprite in the game you're running, and draws sprites and item art with the fiddly bits already handled.

It has no dependencies of its own, so it works whether or not your plugin uses PrettyUI.

## Installing

Add rsprite to your `plugin.json` like any other Plugin Hub dependency:

```json
{
  "requiredDependencies": {
    "rsprite": 0
  }
}
```

Swap the `0` for rsprite's Plugin Hub id once it's published. The client loads rsprite before your plugin and hands you its table as the global `rsprite`, named after the key you used.

## A quick taste

```lua
local attackId = rsprite.Get("SKILL_ATTACK")

local icon = rsprite.Draw(parent, { "SKILL_NECROMANCY", "BP3_MISSION_ICON_SKILL_NECROMANCY", Plugin.resources.my_icon }, {
    x = 10,
    y = 10,
    size = 24,
})

local ring = rsprite.DrawItem(parent, 13562, { x = 40, y = 10, size = 24 })
```

`Draw` works through the chain in order and draws the first thing that exists. Here that's the Necromancy mission icon, because there's no `SKILL_NECROMANCY` sprite. If nothing in the chain exists, you get a plain grey placeholder rather than an empty gap, so missing art is obvious while you're working. `DrawItem` draws an item's art from its item id, ready to go.

## The API

| Function | What it does |
| --- | --- |
| `rsprite.version` | The library version, such as `"0.1.0"`. |
| `rsprite.Get(name)` | The sprite id for a name, or `nil`. Case insensitive and cached. |
| `rsprite.Name(id)` | The sprite name for an id, or `nil`. Cached. |
| `rsprite.Resolve(nameOrChain)` | The first source in a chain that exists, plus its position, or `nil`. |
| `rsprite.Draw(parent, nameOrChain, options)` | A new `ui.Sprite` showing the first source that exists, plus its position. |
| `rsprite.SetSource(sprite, nameOrChain, options)` | Points an existing sprite at a new chain and gives back the position used. |
| `rsprite.DrawItem(parent, itemId, options)` | A new `ui.Sprite` showing item art. |
| `rsprite.SetItem(sprite, itemId, options)` | Points an existing item sprite at another item, giving `true` or `false`. |
| `rsprite.Find(text, options)` | Matching entries and the total match count. An empty string lists every sprite. |
| `rsprite.Tags()` | Every tag you can filter by, sorted alphabetically. |
| `rsprite.BuildIndex(onReady)` | Gets the search index ready over a few ticks and calls `onReady` when done. |
| `rsprite.IsIndexReady()` | Whether the search index is ready yet. |

A chain is an array, though a single value works too. Each entry can be a sprite name, a sprite id, or a resource handle from your own `Plugin.resources`.

`Draw` takes `x`, `y`, `xAnchor`, `yAnchor`, `size` (24 by default), `width`, `height`, `colour` (a packed `0xRRGGBBAA` number), `alpha` and `placeholder` (`true` by default). `DrawItem` takes the same layout options, `x`, `y`, `xAnchor`, `yAnchor`, `size`, `width` and `height`, plus `quantity` and `placeholder`. `SetSource` takes `colour`, `alpha` and `placeholder`, and `SetItem` takes `quantity` and `placeholder`.

`Find` takes `tags`, `limit` (50 by default) and `offset`. Each entry looks like `{ name, id, tags, aliases, width, height }`, and `width` and `height` are only there when they're known. Exact names and aliases come first, then names or aliases that start with your search, then tag matches, then everything else. Within each group, the handpicked sprites in the curated list come first.

Searching for an empty string browses the lot: curated sprites first, then everything else by id. It still respects `tags`, `limit` and `offset`, so `rsprite.Find("", { tags = { "skill" } })` lists every skill sprite, a page at a time. `rsprite.Tags()` gives you the tag names to offer, which is handy for a filter dropdown.

## Finding sprites

rsprite comes with a companion plugin, `rsprite-finder`, for picking sprites while you build. Players never need it, so install it in your dev setup rather than listing it as a dependency. It needs rsprite and PrettyUI enabled alongside it.

Open the Plugin Hub's Manage list, click the finder's settings cog, and press **OPEN FINDER**. You get a window with:

- **A search box.** Type a few words, such as `arrow`, `skill attack` or `necromancy`, and the results update once you stop typing. The cross at the end of the box clears it in one click.
- **A tag dropdown**, to narrow things down to buttons, icons, skills and so on.
- **A favourites star** next to the dropdown. Turn it on to see only the sprites you've starred, newest first. The search box and tag dropdown still narrow them down.
- **A grid of live previews**, 30 to a page, with arrows to page through. Hover over one to see its full name.
- **A detail panel** for whichever sprite you click. It shows a larger preview at 16, 24, 32, 48 or 64 px, its id, its size when that's known, and its tags and aliases.

Around the preview are a few controls:

- **The star** in the top left adds the sprite to your favourites, or takes it out again.
- **The swap button** in the top right switches the preview's background between dark, light and a checkerboard, so you can see sprites with dark or transparent edges properly. It only changes the large preview, not the grid.
- **The arrows** either side of the preview step through a sprite's numbered variants, when it has any.

Underneath are four boxes you can copy from:

- **Name** holds the bare sprite name.
- **Get** holds a ready to paste `rsprite.Get("NAME")` line.
- **Draw** holds `rsprite.Draw(parent, "NAME", { size = N })`, where N is whichever preview size is lit. Pick another size and it updates straight away.
- **PrettyUI** holds `window:AddSprite(rsprite.Get("NAME"), { size = N })`, for dropping the sprite into a PrettyUI window. It follows the lit size too.

Click a box, then press Ctrl+A and Ctrl+C to copy the whole thing. A long value may show only its end in the box, but it all gets copied. The boxes put their text back if you type into them by accident.

The finder's cog also has two options, both on to begin with. Change either one and an open finder updates straight away.

- **Group numbered variants** folds sprites that only differ by a trailing number, such as `ATTACKING_RETICULE_FRAME_1` to `_3`, into one tile. Hover over it to see how many variants it holds, then step through them with the arrows beside the preview. Everything in the detail panel, copy boxes included, follows the variant you're on.
- **Hide mobile and language copies** leaves out sprites with `_MOBILE` in their name, and the French, German, Portuguese and Spanish copies whose names end in `_FR`, `_DE`, `_PT` or `_ES`, with or without a number after them. English copies stay.

Favourites show exactly what you starred, whichever options are on. Starring keeps the exact variant you're looking at. If a game update removes a sprite you starred, it drops out of view but stays on your list, in case it comes back.

The finder remembers your last search, tag, page, selection (down to the exact variant), preview size and preview background between sessions, along with your favourites and the options. The first time you open it, it spends a moment reading sprite names before the grid fills in.

## Using it with PrettyUI

rsprite doesn't try to replace PrettyUI's widgets. It just gets you a good sprite to give them. `Resolve` hands back whatever wins the chain, so feed that straight in:

```lua
local close = rsprite.Resolve({ "CLOSE_BUTTONS_0", Plugin.resources.close_fallback })
prettyui.Sprite.new(parent, close, { size = 16 })
```

The same works anywhere PrettyUI wants a sprite id or an image, including `SimpleButton` and `BuffBar`.

## Nothing found means nil

rsprite gives you `nil` for anything it can't find, so a plain `if spriteId then` does the right thing. It also prints one `rsprite:` warning per missing name, so typos show up in the console rather than as a blank square.

Mistakes in how you call rsprite, like a `nil` parent or an option name it doesn't recognise, raise an error that points at your own line. Problems at runtime, like an unknown sprite, never raise.

## Sizes

rsprite always draws at a size, 24 by 24 unless you say otherwise. Where a sprite's size is known, `Find` tells you.

## Where the names come from

The names come from the game you're running, so they're never out of date. The first `Find` takes a moment while rsprite gets them ready. If you'd rather spread that over a few ticks, call `rsprite.BuildIndex(onReady)` early on.

The `catalogue/` folder holds the handwritten tags and aliases, plus a record of each game build's names so changes between builds can be reviewed.

## Contributing

Tags and aliases are what make searching feel smart, and adding more is the easiest way to help. They live in two files.

`catalogue/tag-rules.json` tags every sprite whose name starts with, contains or ends with some text:

```json
{ "prefix": "PRAYER_", "tags": ["prayer"] }
```

`catalogue/curated.json` gives one sprite its own tags and aliases, and puts it near the top of searches:

```json
"SKILL_ATTACK": { "tags": ["combat"], "aliases": ["attack"] }
```

Then:

1. Edit either file.
2. Run `npm run catalogue`. It rebuilds the generated module and checks that every curated name exists and every rule matches at least one sprite.
3. Run `npm test`.
4. Open a pull request.

Rather not touch the files? Suggestions are just as welcome as issues on [the issue tracker](https://github.com/sereselene/rsprite/issues).

## Working on rsprite

You'll need Node 22.12 or later. StyLua and lefthook ship as platform specific binaries, so if you work from both Windows and WSL, run `npm install` once from each side. Never run `npm ci` locally, because it throws away the other side's binaries. `npm run check-platform` tells you if the current side is missing anything.

| Command | What it does |
| --- | --- |
| `npm test` | Runs the Lua selftests, then the script tests. |
| `npm run format` | Formats every Lua file with StyLua. |
| `npm run catalogue` | Rebuilds the generated module from the committed sprite list after you change the tags or aliases. |
| `npm run catalogue -- --dump <path> --client <build>` | Rebuilds the whole catalogue from a new game build's sprite name list. |
| `npm run catalogue -- --check` | Fails if the generated catalogue files are out of date. |
| `npm run placeholder` | Regenerates the placeholder image. |
| `npm run finder-images` | Regenerates the finder's own images: the text box background and the checkerboard behind the preview. |
| `npm run dev-install -- --target <folder>` | Copies rsprite, the finder and the example plugin into the game's dev plugin folder. |
| `npm run validate-tag -- v0.1.0` | Checks a release tag against `plugin.json`, `rsprite.version` and the changelog. |

`dev-install` also reads the target from the `RSPRITE_DEV_PLUGIN_FOLDER` environment variable. It only ever replaces its own `rsprite`, `rsprite-finder` and `rsprite-example` folders, and refuses to touch anything else. After installing, run `prf` in the game's console first, then `prl rsprite`, `prl rsprite-finder` and `prl rsprite-example`. Open the example's settings cog to see everything drawn, or the finder's cog to start searching.

Raw sprite name lists never live in this repository. Keep them somewhere alongside it, such as `../sprite-dumps/950-1.txt`, and pass one to `--dump` when a new game build comes out.

Luacheck and gitlint are called by name from the git hooks, so install them wherever you commit from.

## Releasing

Both plugins in this repository ship on the same version, and `validate-tag` checks every `plugin.json`, `rsprite.version` and the changelog against the tag. It runs again from a git hook whenever you push a tag.

While a release is being worked on, its changelog heading reads `## [0.1.0] - Unreleased`. When you tag it, change `Unreleased` to the date you tag on, such as `## [0.1.0] - 2026-10-10`. A tag whose heading still says `Unreleased` is refused.

## Licence

MIT. See [LICENSE](LICENSE).
