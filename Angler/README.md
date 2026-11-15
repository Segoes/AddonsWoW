# Angler

Fishing companion for **World of Warcraft: Forever** (Interface 16001).

## Features

### Window
- Uses Blizzard's `PortraitFrameTemplate`: a round portrait with the addon artwork, a title bar and a close button.
- **Skill bar** shows base skill and maximum, plus the total including bonuses (pole, gear, lure) in green: `Fishing  47 / 75  (72)`.
- **Language** button (`EN`, `ES`, `DE`, `FR`, `PT`, `IT`): English, Spanish, German, French, Portuguese or Italian for every addon text, including lure names (official client names; Italian ones come from current retail data because this build has none). English by default; same as `/angler language en|es|de|fr|pt|it`.
- **Gear menu** (title bar): toggles for the louder splash, the minimap button and fishing pools on the map; export or import pools; set or remove the fishing key. Same options as the slash commands.
- **Set key** button: left-click, then press any key (modifiers allowed) to set the one-key fishing key; Escape cancels, right-click removes it. Same as `/angler key`.
- **Equip pole** button: equips the fishing pole from your bags and remembers your weapons; with the pole on it becomes **Swap back** and puts them back. Not available in combat.
- **Apply lure** button: puts the best lure from your bags that your fishing skill allows on the equipped pole; the count shows how many are left, and the tooltip shows the minutes left on the current lure. It pulses while the pole has no lure and you have one to apply. Not available in combat.
- **Movable** by dragging. Position and visibility are saved.

### Skill-up alert
- A chat message, a centre-screen message and a sound when the base fishing skill increases.
- Bonus changes (applying a lure, equipping gear) do not trigger it.

### Louder splash while fishing
- While fishing: sound effects at 100%, music and ambience muted, and master volume raised to at least 60%.
- Original values return 15 seconds after the last cast, on logout, or on the next login after a crash.

### One-key fishing
- With a fishing pole equipped, the chosen key **casts**. While the line is out, the same key **reels in** through the soft-interact target.
- Without a pole the key keeps its normal binding.
- In combat, binding changes are deferred until combat ends.

### Fishing pool records
- A pool is recorded when something is caught in it: pool type, map and position. Chat confirms each new pool.
- The client never gives a pool's position, and only the mouseover tooltip names it, so the pool must be hovered once. A catch within 3 minutes, within 30 yards of where it was hovered, places it about 15 yards ahead of the player, where the bobber lands.
- Each catch restarts those 3 minutes, so one hover covers a whole fishing session at that pool.
- Later catches in the same pool are merged into it with a counter.
- Spots saved on hover alone by earlier versions mark where the player stood, so they are removed on load.
- Pools are server spawns, so they are recognised by the tooltip name: the English names in `Pools.lua`, mapped localized names, and in Spanish any name starting with "Banco", "Aguas" or "Restos".
- Saved per account in `AnglerDB.pools`, by map.
- Recorded pools show on the **world map** and the **minimap** (HereBeDragons), with the icon of the pool's fish. Hovering an icon shows the pool name.
- Toggle in the gear menu or with `/angler pools on` / `off`.

### Shared pools
- The addon ships with the pools players sent through the submission form (`Data/SharedPools.lua`). They show on the map like recorded ones, so every update brings the latest list.
- A shared pool the player has also recorded shows only once, as the player's own.
- The list is rebuilt before each release with `tools/build-shared-pools.lua` (outside the addon folder): it reads the form responses, drops texts that are damaged or have unknown pool types, and merges reports of the same pool at their average position. Deleting a response from the sheet removes its pools on the next build.

### Sharing pools
- **Export pools** (gear menu or `/angler export`) opens a window with the recorded pools as one text, already selected: Ctrl+C copies it.
- Below the hint, the export window shows the link to the submission form ([forms.gle/DGs2jQ9yjPVqo3jp6](https://forms.gle/DGs2jQ9yjPVqo3jp6)) in a read-only box: click it and press Ctrl+C. Pools sent there are meant to be merged into the pool data shipped with later versions.
- **Import pools** (gear menu or `/angler import`): paste a text with Ctrl+V and press **Import**. Pools merge with the ones already recorded; chat reports how many are new.
- Format: `ANGLER1:` followed by the pools serialized with LibSerialize, compressed and encoded with LibDeflate. Each pool carries its English type, map and position.

### Minimap button
- Standard LibDBIcon button: click shows or hides the window, drag moves it, the tooltip shows the fishing skill.
- Minimap button collectors (such as Leatrix Plus) list it as **Angler**.

### Addon list icon
- Custom artwork in `Media/Icon.tga` (64×64), set through `## IconTexture`.

## Commands

| Command | Effect |
|---|---|
| `/angler` / `/angler help` | List commands |
| `/angler show` / `/angler hide` | Show or hide the window |
| `/angler language en` / `es` / `de` / `fr` / `pt` / `it` | Addon language |
| `/angler pools on` / `off` | Show or hide recorded fishing pools on the world map and minimap |
| `/angler export` | Window with the recorded pools as a text to share |
| `/angler import` | Window to paste a shared pool text |
| `/angler minimap on` / `off` | Show or hide the minimap button (click toggles the window, drag moves it) |
| `/angler sound on` / `off` | Louder splash while fishing (default on) |
| `/angler key F` / `off` | Set or remove the one-key fishing key (any key, e.g. `SHIFT-F`) |
| `/angler debug on` / `off` | Write diagnostics to chat and to SavedVariables (not in the gear menu; for bug reports). The log stays readable on disk until the next load after turning it off |

A bare `/angler sound`, `/angler language`, `/angler minimap`, `/angler pools`, `/angler key` or `/angler debug` only reports the current state.

## Setup for one-key fishing

The soft-interact CVars are protected, so addons cannot set them. Type these once; the game keeps them:

```
/console SoftTargetInteract 3
/console SoftTargetInteractRange 30
```

The addon tries to set them anyway and prints these lines if that fails.

## Files

| File | Purpose |
|---|---|
| `Angler.toc` | Manifest |
| `Locales.lua` | Texts in every addon language |
| `Lures.lua` | Lure list (item IDs, required skill, names per language) |
| `Pools.lua` | Fishing pool names recognised in tooltips |
| `Data/SharedPools.lua` | Pools sent by players, generated by `tools/build-shared-pools.lua` |
| `Libs/` | Embedded LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0, HereBeDragons-2.0 (with Pins), LibSerialize and LibDeflate |
| `Angler.lua` | Everything else |
| `CHANGELOG.md` | Summary of changes per version |
| `Media/Icon.tga` | Icon for the addon list and window portrait |

Saved data:
- `AnglerDB` (account): window position and visibility, minimap button position and visibility, sound and key settings, last known skill, recorded fishing pools, debug log.
- `AnglerCharDB` (character): weapons to put back after fishing.

## Forever-specific notes

- Fishing loot is only detected reliably on `LOOT_OPENED`, not on `LOOT_READY` alone.
- Several spells are named "Fishing" (7620 and newer IDs), so casts are matched by spell name.
- Fishing skill is read with `C_SkillInfo` (skill line 356). The `modifier` field holds the bonus from gear and lures.
- "Skill not high enough" when casting means the zone needs more fishing skill. It is not an addon error.

## Not possible

These were investigated and are blocked by the client or by the game rules:

- **Outline or circle around the bobber.** Addons cannot draw on world objects or get a bobber's screen position, and the `Outline` CVar does not apply to the bobber.
- **Automatic reeling when a fish bites.** Every action needs a key press; automating it would be a bot.
- **Reeling in from a mouse-clicked button.** No secure action type or slash command exists for interact; only a key binding can do it.
- **Fishing zones per fish.** Loot tables are server-side and not in the client data.

## Testing

The logic is covered by an offline harness running on Lua 5.1 with a fake WoW API. It covers loot detection, the window layout, skill bonus, sound restore, key bindings, combat deferral and resizing. In-game checks are still needed for visuals and real client behaviour.
