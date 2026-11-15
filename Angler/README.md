# Angler

Fishing companion for **World of Warcraft: Forever**: a fishing skill bar, one-click pole and lure buttons, one-key fishing, a louder splash, and a map of fishing pools shared by players.

## Installation

- **CurseForge app:** search for Angler and install it.
- **By hand:** copy the `Angler` folder into `World of Warcraft/_forever_/Interface/AddOns/`, so that `AddOns/Angler/Angler.toc` exists. Restart the game or type `/reload`.

Check that **Angler** is enabled in the AddOns list on the character screen.

## Quick start

1. Click the Angler button on the minimap (or type `/angler show`) to open the window.
2. Press **Equip pole**, then **Apply lure**.
3. Press **Set key** and then the key you want to fish with, for example `F`.
4. Type these two lines in chat once. The game keeps them, so you never need them again:
   ```
   /console SoftTargetInteract 3
   /console SoftTargetInteractRange 30
   ```
5. Press your key to cast. When the bobber splashes, press the same key again to reel in.
6. When you find a fishing pool, move the mouse over it once and fish in it. It is added to your map.

## The window

- **Skill bar:** your fishing skill and its maximum, plus in green the total with bonuses from pole, gear and lure, e.g. `Fishing  47 / 75  (72)`.
- **Equip pole:** takes the fishing pole from your bags and remembers your weapons. With the pole on, the button becomes **Swap back** and puts your weapons back.
- **Apply lure:** puts the best lure in your bags that your skill allows on the pole. The number shows how many lures are left, and the tooltip shows the minutes left on the current one. The button pulses when the pole has no lure and you have one.
- **Set key:** left-click, then press any key (Shift, Ctrl and Alt combinations are allowed). Escape cancels, right-click removes the key.
- **Language button** (`EN`, `ES`, `DE`, `FR`, `PT`, `IT`): changes the addon language. English is the default.
- **Gear menu** (title bar): turn the louder splash, the minimap button, the pools on the map and the reminder to send pools on or off; export your pools; set or remove the fishing key.
- Drag the window to move it. Its position is saved. Equip pole, Swap back and Apply lure don't work in combat.

## One-key fishing

- With a fishing pole equipped, your key **casts**. While the line is out, the same key **reels in**.
- Without a pole, the key does whatever it normally does.
- The key only reels in after the two `/console` lines from the quick start. Addons are not allowed to set them, so if they are missing, Angler prints them in chat as a reminder.

## Louder splash

While you fish, game sounds go to 100%, music and ambience are muted, and the master volume rises to at least 60% so the splash is easy to hear. Everything returns to your settings 15 seconds after your last cast. It is on by default. Turn it off in the gear menu or with `/angler sound off`.

## Skill-up alert

When your fishing skill goes up, Angler shows a message in chat and in the centre of the screen and plays a sound.

## Fishing pools

### Recording pools
The game never tells addons where a pool is, and only the mouseover tooltip shows its name. So:

1. Move the mouse over the pool once.
2. Fish in it. When you catch something, the pool is saved on your map and chat confirms it.

After that, every catch keeps the pool remembered for another 3 minutes, so one hover is enough for a whole fishing session there. Hovering alone saves nothing.

### On the map
Your pools show on the world map and the minimap with the icon of the pool's fish. Hover an icon to see the pool name. Hide or show them with the gear menu or `/angler pools off` / `on`.

### Pools from other players
Angler comes with pools sent in by other players, and each update adds the new ones. A pool you have also recorded yourself shows only once.

### Sending your pools
1. Open **Export pools** in the gear menu, or type `/angler export`.
2. The text is already selected: press Ctrl+C to copy it.
3. Click the link box below the text, press Ctrl+C, and open the link in your browser: [forms.gle/DGs2jQ9yjPVqo3jp6](https://forms.gle/DGs2jQ9yjPVqo3jp6).
4. Paste the text in the form (Ctrl+V) and send it. Your pools will be in the next version for everyone.

Once a day, when you log in, Angler reminds you if you have pools that are not on the shared map yet and that you haven't exported. Turn the reminder off in the gear menu or with `/angler reminder off`.

## Commands

| Command | Effect |
|---|---|
| `/angler` | List commands |
| `/angler show` / `hide` | Show or hide the window |
| `/angler key F` / `off` | Set or remove the fishing key (any key, e.g. `SHIFT-F`) |
| `/angler sound on` / `off` | Louder splash while fishing |
| `/angler pools on` / `off` | Pools on the world map and minimap |
| `/angler minimap on` / `off` | Minimap button |
| `/angler export` | Copy your pools to send them through the form |
| `/angler reminder on` / `off` | Daily reminder to send new pools |
| `/angler language en` / `es` / `de` / `fr` / `pt` / `it` | Addon language |
| `/angler debug on` / `off` | Diagnostics for bug reports |

Without `on` or `off`, a command only tells you its current state. For example, `/angler sound` says whether the louder splash is on.

## Troubleshooting

When fishing fails, Angler shows the reason in red in chat, in the addon language, so it stays visible after the game's message in the centre of the screen fades.

- **The key casts but does not reel in:** type the two `/console` lines from the quick start.
- **"Skill not high enough" when casting:** this water needs more fishing skill than you have. Fish in an easier zone until your skill goes up.
- **A pool was not recorded:** hover it first, then catch something within 3 minutes while standing near where you hovered it.
- **The minimap button is gone:** `/angler minimap on`.

## Limits

Some requests can't be done because the game doesn't allow addons to do them:

- **Highlight the bobber:** addons can't draw on objects in the world.
- **Reel in automatically when a fish bites:** every action needs a key press. Doing it automatically would make it a bot.
- **Reel in by clicking a button:** only a key can reel in.
- **List which fish each zone has:** that information is not in the game client.

## For developers

| File | Purpose |
|---|---|
| `Angler.lua` | Window, fishing, key, sound and pool recording |
| `Share.lua` | Export window |
| `Locales.lua` | Texts in every language |
| `Lures.lua` | Lures: item IDs, required skill, names per language |
| `Pools.lua` | Pool names recognised in tooltips |
| `Data/SharedPools.lua` | Pools sent by players. Generated, don't edit by hand |
| `Data/ErrorStrings.lua` | The game's error texts in every addon language. Generated by `tools/build-error-strings.lua`, don't edit by hand |
| `Libs/` | LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0, HereBeDragons-2.0 (with Pins), LibSerialize, LibDeflate |
| `Media/Icon.tga` | Addon list icon and window portrait |

- Saved data: `AnglerDB` (account: settings, window and minimap button positions, recorded pools) and `AnglerCharDB` (character: weapons to put back after fishing).
- Export format: `ANGLER1:` followed by the pools serialized with LibSerialize, compressed and encoded with LibDeflate.
- `Data/SharedPools.lua` is rebuilt before each release with `tools/build-shared-pools.lua` from the repository root. That tool reads the form responses, skips damaged texts, and merges reports of the same pool at their average position.
