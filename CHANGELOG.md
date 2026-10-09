# Farm Time — Changelog

## v1.8.0

- **Fish catch alert redesigned:** it now uses the game's own achievement alert art, textures, sizes and timings from the Blizzard AchievementAlertFrame.
  - **Look:** the achievement background, the achievement icon frame, a flash glow, and a shine sweep across the alert.
  - **Rarity:** the item's rarity colors the icon frame, the glow and the item name. Amount is shown below the name.
- **Catch sound vs. fishing addons:** many fishing addons lower the game volume to make the bobber splash easier to hear, which also lowered the catch sound.
  - **How it's avoided:** the catch sound now plays on the Dialog channel, and Dialog and master volume are raised only while it plays (about 3 seconds).
  - **Restore:** volumes are put back afterwards, unless another addon changed them in the meantime.
  - **Muted game:** if all game sound is off, nothing is forced.
  - **Option:** "Catch sound ignores lowered volume" (`/ft loudsound`).

## v1.7.1

- **Minimap button:** now registered through the standard LibDBIcon when another addon provides it (Questie, Details, Bartender and many others embed it). Minimap button collectors (MinimapButtonButton, Minimap Button Bag…) handle it like any other button and no longer warn about a "custom button". Without LibDBIcon, the old button is still used.
- **Fish catch animation:** now plays the game's achievement sound. On clients without achievements, it falls back to the epic loot sound.

## v1.7.0

- **New: F to fish.**
  - **When:** you have a fishing pole equipped and there is nothing to interact with.
  - **What F does:** casts Fishing.
  - **Back to Interact:** as soon as something is in reach (herb, ore, corpse, the bobber), and while you are channeling Fishing, so F can click the bobber.
  - **How:** uses an override binding, which the game only lets addons change out of combat.
  - **Options:** "F casts Fishing" in the panel or `/ft fishkey`.

## v1.6.0

- **New: fish catch animation.** Every item you fish up shows an achievement-style toast: a large plate with the item icon, name and amount.
  - **Rarity color:** the border, glow and header use the item's rarity color (grey, white, green, blue, purple…), like the borders on herbs and ores.
  - **Animation:** slides in with a pop and a pulsing glow, stays for a few seconds, then fades out.
  - **Queue:** several items from one catch are shown one after another.
  - **Options:** "Fish catch animation" in the panel or `/ft fishtoast`. Preview it with `/ft fishtest`.

## v1.5.5

- **Arrow:** now always points to the nearest available (confirmed) node. Unavailable grey nodes are ignored, even when they are shown.
- **New options:** "Show herbs" and "Show ores" in the settings panel (also `/ft herbs`, `/ft ores`). They hide that type everywhere: plate above the node, in-world markers, arrow and the "Press F" prompt. Session tracking is not affected.

## v1.5.4

- **Fixed:** nodes were confirmed by the tooltips of other addons' minimap pins (GatherLite, GatherMate2, HandyNotes, Questie…). Those pins mark where a node used to be, not where it is now. Only the game's own minimap tracking dots confirm nodes now.
- **Debug:** with "Debug in chat" on, each confirmation prints `confirmed: <node>`.

## v1.5.3

- **Option renamed:** "Show unavailable herbs/ores (grey)". It controls whether nodes that are not confirmed, or were already gathered, are shown in grey or hidden (default: hidden). Also available as `/ft grey`.

## v1.5.2

- **Fixed:** a node you just gathered could be re-confirmed while its loot window was still open, so it kept showing. Proximity can no longer re-confirm a node for 2 minutes after you gather it (minimap: 15 seconds).
- **New:** hovering the minimap exactly over a confirmed node with no tracking dot there for half a second unconfirms it, and it disappears from your view.

## v1.5.1

- **Fixed:** saved-node markers and the arrow showed the wrong distance and direction (the distance grew as you walked toward a node). The world position axes were swapped when reading the player position.
- **Note:** nodes saved by earlier versions had wrong positions and are cleared once on update. Gather again to rebuild them.
- **Sharing:** the message format was bumped to version 2. Nodes shared by players still on v1.5.0 are ignored.

## v1.5.0 — First public release

**Game version:** WoW Forever (Classic+) beta 1.60.1 (interface 16001). Also declared for Classic Era 1.15.9 (11509).
**Optional:** Auctionator (for item prices in the session window).

### Gathering helper
- **Node highlight:** when the herb or ore in front of you becomes the interact target, a nameplate-style plate (item icon, name, type) appears above the node. Green border for herbs, orange for ores.
- **Hide the game's label:** optionally hides the game's own small name/icon above the node so only one label is shown.
- **"Press F" prompt:** shows `[F] Gather Kingsblood`, `[F] Mine Copper Vein` or `[F] Skin Plainstrider`, only when you are actually in range to gather or skin.
- **F to gather:** binds F to the game's "Interact with Target" action. Your previous F binding is saved and can be restored from the settings panel.
- **Fast loot:** loots everything instantly. Hold Shift to skip it for that loot.

### Saved nodes, 3D markers and arrow
- **Saved nodes:** every herb and ore you gather is saved with its location.
- **In-world markers:** saved nodes are shown in your field of view, at the node's direction and distance, with the distance in yards.
- **Confirmed nodes only (default):** a node is confirmed when you hover its tracking dot on the minimap (Find Herbs/Minerals on), or when you get close to it. A confirmation lasts 5 minutes; gathering the node clears it. Unconfirmed nodes can optionally be shown in grey.
- **Camera calibration:** markers use the real camera distance plus an adjustable camera angle. Use the "Calibrate" button once to line the markers up with the ground.
- **Arrow:** a TomTom-style arrow points to the nearest confirmed node, with its icon, name and distance. The arrow can be dragged.

### Sharing
- **Share with guild and/or party/raid (off by default):** confirmed and gathered nodes are sent to other Farm Time users through the official addon message channel. Nothing appears in chat.

### Session window
- **What it tracks:** herbs, ores, skinning, fishing and trade goods (cloth, meat, leather, elementals…) looted during the session.
- **Value:** quantity times the last price Auctionator saw, plus a running total.
- **Timer and reset:** a timer counts from the first item of the session, and a Reset button clears it.
- **Behavior:** the window can be moved. It hides on login and reopens on your next gather.

### General
- **Settings and minimap:** settings panel and minimap button. No external libraries.
- **Languages:** English (default) and Português (BR), switchable in the panel or with `/ft lang`.
- **Diagnostics:** `/ft status` shows client, position and sharing info.
- **Commands:** `/ft` opens the panel; `/ft help` lists all commands.

### Known limitations
- **Detection range:** addons cannot list objects in the world. Live highlighting only works for the node the game picks as your interact target, which happens at close range.
- **Approximate markers:** the game does not expose camera rotation to addons. In-world markers follow your character's facing; rotating the camera with the left mouse button does not move them.
- **Manual confirmation:** minimap tracking dots cannot be read by addons. Confirming a node requires hovering its dot or getting close to it.
