# Belt Balancer (Unofficial 2.1 Fix)

Factorio mod `belt-balancer-Unofficial-2-1Fix`. Place **Balancer Parts** next to each other and connect belts, undergrounds,
splitters, loaders or linked belts to the edges; all input lanes are balanced onto all output lanes.

Original mod: Belt Balancer 2 by knoxfighter, archiehalliwell and IThundxr
(<https://mods.factorio.com/mod/belt-balancer-2>), Belt Balancer 3 (Factorio 2.1 update) by NightPablo
(<https://mods.factorio.com/mod/belt-balancer-3>). 2.1 fix and save-state rebuild by kfsone.
This repository: <https://github.com/kfsone/belt-balancer-unofficial-2-1fix>. Neither upstream mod publishes a source
repository, so there is nothing to send a pull request to.

## Replacing Belt Balancer 2 / 3 in an existing save

This mod is **not** a drop-in rename. It keeps the prototype names, so the balancer-parts, recipes and technologies of your
save carry over, but a mod's script state is private to the mod name, so a renamed mod starts with an empty state. This
mod therefore rebuilds the state from the placed entities when it is added to a save:

1. Disable or remove `belt-balancer-2` / `belt-balancer-3` (they are marked incompatible) and enable this mod.
2. Load the save. Every balancer-part, and every belt, underground belt, splitter, loader and linked belt next to one,
   on every surface (space platforms included) is registered by replaying the mod's own build logic. Up to 50 parts
   are handled per tick, so a save with ~1000 parts finishes within about 25 ticks.

Not recoverable: items that were held in a balancer's internal buffer (at most two per output lane) when the old mod was
removed.

## Developer notes

* `objects/rebuild.lua` is the rebuild. It is idempotent: parts that are already tracked are skipped.
* Remote interface `belt-balancer-unofficial`: `statistics()`, `fingerprint()` (canonical dump of the tracked state, used
  to compare a rebuilt state with a live-built one), `rebuild(sync)`, `rebuild_pending()`.
* Console command `belt-balancer-statistics` works without a player and also writes a `[BBSTAT]` line to the log.
* Per-tick cost added by this mod: one `storage.rebuild` nil check inside the existing on_tick handler.

## Licence

MIT. The licence texts of belt-balancer-3 (`LICENSE`) and belt-balancer-2 (`LICENSE-belt-balancer-2`) are both kept.
