# Changelog

## 0.21.0
- Pool import removed: shared pools now arrive with each update, from the texts sent through the form.

## 0.20.3
- Code cleanup: shared helpers for buttons, bag searches and on/off settings, and removal of data migrations from earlier test versions.

## 0.20.2
- The debug log is no longer in the gear menu; `/angler debug on` still turns it on.
- Diagnostic events are only listened to while debugging.
- An old debug log is cleared on the next load after debugging is turned off.

## 0.20.1
- One hover per pool is enough: each catch keeps the hovered pool remembered for another 3 minutes.

## 0.20.0
- Pools are recorded only when something is caught in them, no longer on hover alone. Hovering the pool first is still needed, since only the tooltip names it.
- Spots saved on hover alone, which marked where the player stood, are removed.

## 0.19.0
- Ships the fishing pools sent by players through the submission form and shows them on the world map and minimap. Each update brings the latest list.
- A shared pool the player has also recorded shows only once.

## 0.18.0
- The slash command is now `/angler` instead of `/fish`.

## 0.17.0
- Removed the catch log: the window no longer lists fish per character, and `/fish` now lists the commands. Saved catch counts are cleared.
- The window has a fixed size; the resize grip and `/fish size reset` are gone.
- Lure data moved from `Fish.lua` to `Lures.lua`.

## 0.16.1
- The export window shows the link to the pool submission form, ready to copy.

## 0.16.0
- Export and import recorded fishing pools as a text string (`/fish export`, `/fish import` or the gear menu). Only precise pools, placed by a catch, are exported.
- Embedded LibSerialize and LibDeflate.

## 0.15.1
- A pool hovered from far away and then fished no longer leaves a second, approximate copy on the map.
- Pool names from the full list of Forever pools, in English and Spanish.
- Pool icons all use the same colour; approximate positions are no longer greyed out.

## 0.15.0
- Recorded fishing pools show on the world map and the minimap; grey icons are approximate positions.
- Gear menu option and `/fish pools on|off`.
- Embedded HereBeDragons-2.0 and HereBeDragons-Pins-2.0.

## 0.14.0
- Fishing pools are recorded when hovered, and placed more precisely after a catch. First step towards a shared pool map.

## 0.13.0
- Tooltips, chat replies and window texts rewritten in a short, impersonal style in every language.

## 0.12.0
- The **Apply lure** button pulses while the pole has no lure and a usable lure is in the bags. It checks again when the current lure should expire.

## 0.11.0
- **Apply lure** button: applies the best lure in the bags that the fishing skill allows, shows how many are left and, in the tooltip, the minutes left on the current lure.
- A secure button on `UIParent` takes the click, so the window stays movable and closable in combat.
- `/fish debug off` keeps the debug log; only `/fish debug on` clears it.

## 0.10.1
- Italian fish names, taken from current retail data because the Forever build has none.

## 0.10.0
- German, French, Portuguese (Brazil) and Italian, in addition to English and Spanish.
- Fish names per language from the Forever client data.
- `/fish language en|es|de|fr|pt|it`.

## Earlier
- Catch log per fish type and per character, with **Other** for everything else. Counts are kept for good; there is no reset.
- Window with skill bar, fish list, drag to move and resize grip.
- Skill-up alert.
- Louder splash while fishing, with the original sound settings restored afterwards.
- One-key fishing: one key casts and reels in. **Set key** button shows the chosen key; left-click assigns, right-click removes.
- **Equip pole** / **Swap back** button that remembers the previous weapons.
- Minimap button through LibDBIcon, listed as **Angler** by button collectors.
- Gear menu in the title bar with every `/fish` option.
- Language button with English and Spanish.
