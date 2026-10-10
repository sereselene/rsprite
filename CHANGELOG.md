# Changelog

Everything notable that changes in rsprite lands here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [0.1.0] - Unreleased

The first release, built against client `950-1`.

### Added

- `rsprite.Get(name)` and `rsprite.Name(id)` for looking sprites up in either direction. `Get` is case insensitive, both are cached for the session, and both give `nil` when there's nothing there.
- `rsprite.Resolve(nameOrChain)` for picking the first sprite in a fallback chain of names, ids and your own resource images, ready to hand to PrettyUI or anything else that takes a sprite.
- `rsprite.Draw` and `rsprite.SetSource` for bare sprites with a fallback chain, sizing, colour and alpha, plus a neutral placeholder when nothing in the chain exists.
- `rsprite.DrawItem` and `rsprite.SetItem` for item art by item id, ready to draw.
- `rsprite.Find(text, options)` for searching every sprite name in the game you're running by name, tag and alias, with paging and tag filters. An empty string browses every sprite, curated ones first.
- `rsprite.Tags()` for listing every tag you can filter by.
- `rsprite.BuildIndex(onReady)` and `rsprite.IsIndexReady()` for getting the search index ready over a few ticks instead of all at once.
- A curated starter set of tags and aliases covering the skill icons and common buttons.
- `rsprite-finder`, a developer tool for picking sprites while you build:
  - Search every sprite, with live previews that update once you stop typing.
  - Filter by tag, and page through the results 30 at a time.
  - A detail panel with each sprite's id, size, tags and aliases, and boxes to copy its name, a `rsprite.Get` line, a `rsprite.Draw` line or a PrettyUI `AddSprite` line.
  - Numbered variants grouped into one tile, with arrows beside the preview to step through them.
  - An option to hide mobile and language copies.
  - Favourites you can star, and a switch to show only those.
  - A preview background that cycles through dark, light and a checkerboard.
  - Your search, tag, page, selection, preview settings, favourites and options are remembered between sessions.
