# Farm Time — Changelog

## v1.14.0

- **Saved nodes come back by themselves, no minimap needed.** After you gather a node once, you no longer have to hover the minimap to see it again.
  - **When it shows:** 10 minutes after it was last gathered (respawn time), a saved node shows up again with its marker and the arrow whenever you are within the area the minimap covers.
  - **How it gets hidden again:** addons can't read the minimap dots, so the node is assumed to have respawned. It is hidden again for 10 minutes if you hover its spot on the minimap and there is no dot, or if you walk to it and the game doesn't find the herb/ore within a few seconds (someone took it, or it spawned at another spot).
  - **Confirmation:** hovering the minimap dot or getting close still confirms the node.
  - **Option:** "Saved nodes come back by themselves (no minimap)" (on by default), or `/ft respawn`.
- **Tutorial:** step 4 now describes this behavior.

## v1.13.1

- **Arrow always goes to the nearest node.** Since v1.12.0, spotting a new unknown node on the minimap deleted every other unknown prediction, so the arrow could point to a far one while a closer node had been seen before.
  - **Kept now:** different minimap dots are kept as separate predictions (up to 6), and the arrow picks the nearest available node. After you gather it, the arrow moves on to the next nearest one.
  - **Same dot seen again:** a new prediction with the same name within 60 yards still replaces the old one, so there are no duplicates.
  - **Clean screen:** only the nearest unknown prediction gets an on-screen marker.

## v1.13.0

- **New: tutorial.** On the first login after installing (or updating), a short two-page window explains the main features.
  - **Herbs and ores:** turn on Find Herbs/Find Minerals, hover a yellow dot on the minimap to get a marker and the arrow, press F to gather, and saved nodes come back with a quick minimap pass.
  - **Fishing:** with a fishing pole, F casts; when the bobber splashes, F again catches the fish.
  - **Reopen:** "Tutorial" button in the settings panel, or `/ft tutorial`.
- **New: tracking warning.** If your character knows Find Herbs or Find Minerals and neither is active, a warning appears below the minimap.
  - **Dismiss:** the X hides it until tracking changes.
  - **Option:** "Warn when Find Herbs/Minerals is off" in the panel, or `/ft trackwarn`.
  - **Hunters:** classic clients allow only one tracking type at a time, so use the X or the option if you are tracking beasts on purpose.

## v1.12.0

- **New 3D arrow.** The flat arrow was replaced by a real 3D arrow (beveled, lit, with outline and ground shadow), pre-rendered from 64 angles. The arrow picks the frame for the node's direction instead of rotating a flat image. It is still tinted by the node color (green herb, orange ore, yellow unknown, grey unavailable) and slightly bigger.
- **One unknown prediction at a time.** Several approximate "?" markers cluttered the screen. Now only the most recently seen unknown node is kept; spotting a new one replaces the previous one. Existing extra predictions are cleaned up automatically.

## v1.11.1

- **Unknown predictions hide when the real node is in sight.** When the game picks a herb/ore as your interact target (the big plate over it), unknown nodes with the same name within 60 yards are hidden: no "?" marker and no arrow to them. They come back if the target goes away without being gathered. Gathering removes them as before.

## v1.11.0

- **Unknown nodes are corrected as you get close.** The minimap only gives a rough position, so the marker and arrow could point a few yards to the side of the real herb/ore.
  - **When the game targets it:** the game's name plate is on top of the real node. Its screen position is converted back to a ground position (the reverse of the marker projection), and the node is pulled toward it a little every 0.2 seconds. The marker and arrow slide onto the real node as you walk.
  - **In gathering range:** the node moves to your position, and later minimap hovers no longer move it.
  - **Accuracy:** this uses the camera angle from the calibration (`/ft calibrate`) and works best with the camera behind your character. Estimates more than 40 yards away are ignored.

## v1.10.1

- **Fixed: the same herb/ore showed up twice** (a saved grey node plus a yellow "unknown" one next to it).
  - **Cause:** the minimap tracking dot is several pixels wide and its tooltip shows with the cursor anywhere over it. Zoomed out, that is tens of yards of error, so the cursor position missed the saved node and a duplicate was created.
  - **Fix:** the match tolerance now grows with the minimap zoom (about 40 yards fully zoomed out). A saved node always wins over an unknown one, and confirming a saved node removes unknown duplicates around it.
  - **Gathering:** gathering a herb/ore also removes unknown nodes with the same name within 45 yards.
  - **Position:** an unknown node's position is now the average of every cursor position over the dot. Sweeping the mouse across the dot puts it at the center.

## v1.10.0

- **New: loot alert.** With fast loot the loot window barely shows, so every looted item of **uncommon (green) quality or better** now shows the same achievement-style alert as fish, titled "Item looted!".
  - **Tooltip:** hover the alert to see the item's tooltip.
  - **Stays while hovered:** the alert doesn't fade while the mouse is over it. It fades 1.5 seconds after the mouse leaves; moving back over it during the fade brings it back.
  - **Chat link:** Shift+click the alert to link the item in chat.
  - **Fish alert:** now also shows the tooltip and stays while hovered.
  - **Options:** "Alert for looted green or better items" (on by default), or `/ft loottoast`. Preview it with `/ft loottest`.

## v1.9.0

- **New: unknown nodes from the minimap.** Hovering a herb or ore tracking dot on the minimap that isn't in your saved nodes adds it as an **unknown** node at the cursor position.
  - **Look:** yellow border with a "?" on the in-world marker; the arrow shows "? <name>" and "Unknown - <distance>".
  - **Arrow:** points to unknown nodes like any other available node, so you can walk to herbs and ores you have never gathered.
  - **Position:** each new hover refines the approximate position. Gathering it turns it into a normal saved node at your exact position.
  - **Cleanup:** unknown nodes are deleted when their dot is gone from the minimap, after 5 minutes without confirmation, or when the option is turned off. They are never shared (their position is approximate).
  - **Option:** "Unknown nodes spotted on the minimap" (on by default), or `/ft unknown`.
  - **Limitation:** addons can't read minimap dots on their own; a node is only spotted when you hover its dot.

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
