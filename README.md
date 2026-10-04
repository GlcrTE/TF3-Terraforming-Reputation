# Terraforming Costs and Reputation Customization (TF3)

A Transport Fever 3 mod: landscaping near a town costs **100x to 2000x less reputation**, adjustable in 10 steps. Optionally, terraforming also costs **2x to 100x less money**. A debug mode resets a town's reputation with a click.

## Rules

- In the base game, 2 million m³ of moved earth cost a town 100% of its reputation. The game books this as "Landscaping" (`TerrainModification`).
- With this mod, that loss is divided by the factor of the mod option "Landscaping reputation loss reduction": 100x (default), 150x, 200x, 300x, 400x, 500x, 750x, 1000x, 1500x or 2000x less.
- Landscaping covers everything the game counts as such: the terrain brush (raise, lower, smooth), the terrain alignment of constructions (stations, depots, ...) and tunnels.
- The reputation preview shown while building uses the same reduced value.
- Other reputation losses stay as in the base game: removed trees and rocks, demolished town buildings, interrupted main connections, failed subsidies.
- The option is read on every build, so changing it in a running game takes effect right away.

| Option | Moved earth for 100% loss | Loss for 1 million m³ |
|---|---|---|
| base game | 2 million m³ | 50% |
| 100x less | 200 million m³ | 0.5% |
| 500x less | 1 billion m³ | 0.1% |
| 1000x less | 2 billion m³ | 0.05% |
| 2000x less | 4 billion m³ | 0.025% |

### Terraforming costs

Mod option "Terraforming cost reduction": **Off** (default, base game prices) or 2x, 3x, 5x, 7x, 10x, 15x, 20x, 30x, 50x or 100x less. It divides the price of raising and lowering terrain per m³. In the base game that is 4.50 (raise) and 5.25 (lower) per m³, times the difficulty's infrastructure cost scale.

The prices are set when a game is loaded. After changing the option, save and load the game.

### Debug mode

Mod option "Debug mode": when **On**, clicking a town (its name sign or one of its buildings) resets that town's reputation to full. A penalty for currently interrupted main connections stays, because the base game keeps it as long as the connection is interrupted. Each reset is written to the game log: `[Terraforming Costs and Reputation Customization] debug: reputation of <town> (<id>) reset`; a click on something that isn't a town logs `debug: selected entity <id> is not a town`. Turn it off again for normal play.

## How it works

`content/terraforming_reputation/terraforming_reputation.gs.lua` registers a game script (`terraforming_reputation.script.tl`) for the simulation (`update`) and the GUI (`guiUpdate`, `guiHandleEvent`). The wrapper is installed from these functions, not when the file is loaded: at load time `ug_require` looks for the path inside this mod and fails (seen in-game).

1. The base game computes a build's reputation impact per town in `town_util.calculateProposalImpact` (`game_mechanics/towns/town_util.tl`). The towns game script applies it on `onPreBuildProposal`, and the construction GUI uses the same function for the reputation preview.
2. Both call it through the shared `town_util` module table. The script replaces the function in that table with a wrapper that divides `impact.terrainModification` by the chosen factor; all other fields stay untouched. A marker on the module keeps it from being wrapped twice. No base game file is overwritten.
3. Terraforming costs: `content/terraforming_reputation/mod.script.tl` is the mod's `preRunScript`. The base game sets the prices per m³ in its own `preRunFn` (`base/mod.script.tl`: `baseConfig.costs.terrainRaise`, `terrainLower`). Mods' `preRunFn`s run after it, so this one divides the two prices and writes `baseConfig.costs` back, like the base game assigns it. The log gets `[Terraforming Costs and Reputation Customization] terraforming costs divided by <factor>: raise …, lower … per m^3`.
4. Debug mode: the script subscribes to the GUI event `select` (GUI events reach `guiHandleEvent` only after subscribing, like the base game's achievements script does). On `mainView` / `select`, the script finds the clicked town (the town itself, a town building, or a construction with town buildings) and sends the base game's own event `Towns` / `decreaseReputation` with `amount = 1`. A positive amount recovers reputation (`town_util.recoverReputation`); the game's mission script resets towns the same way.

When the wrapper is installed, the game log gets `[Terraforming Costs and Reputation Customization] landscaping reputation loss divided by <factor>` (once per Lua state). Errors are logged as `[Terraforming Costs and Reputation Customization] error: …`. The game log is `<Steam>\userdata\<your Steam ID>\3493540\local\crash_dump\stdout.txt`.

## Status

Type-checked against the game's definitions, with the rules covered by tests.

Tested in-game (1.0): the landscaping reputation loss is reduced. The debug mode didn't work in 1.0 (the script wasn't subscribed to `select`); fixed in 1.1 and tested in-game. The terraforming cost reduction (1.2) is not yet tested in-game.

To check in-game: with the terrain brush near a town, the reputation preview should show a much smaller "Landscaping" loss than without the mod, and the log should contain the "divided by" line.

## Installation

Copy `mod/glcrte_terraforming_reputation_1` into your local TF3 mods folder:

```
<Steam>\userdata\<your Steam ID>\3493540\local\mods\
```

Then enable the mod in the game's mod menu. It can be added to running savegames; reputation already lost stays lost and recovers as usual (or use the debug mode).

`tools/deploy.ps1` copies the mod into the `staging_area` folder next to `mods`, where it shows up under "My Mods" in the in-game Mod Manager for uploading to mod.io. `tools/deploy.ps1 -Target mods` installs it as a plain local mod instead. Either way the copy in the other folder is removed, so the mod ID never exists twice.

## Development

```
pip install lupa
python tools/check.py [--game "<TF3 install dir>"]
```

This checks that `_content.json` lists every file in `content/`, type-checks all `.tl` scripts against the game's definitions, and runs the tests in `tests/`.

## Changelog

### 1.2

- New mod option "Terraforming cost reduction": Off (default) or 2x to 100x less, in 10 steps.

### 1.1

- Debug mode works: the script subscribes to the GUI event `select`.
- The wrapper is also installed in the GUI right away (`guiUpdate`), so the reputation preview is reduced from the start.
- No more `module ... not found` errors in the log at load time.

### 1.0

- First release.

## License

MIT, see [LICENSE](LICENSE).
