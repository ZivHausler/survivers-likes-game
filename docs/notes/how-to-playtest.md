# how-to-playtest

Manual playtest checklist for the Wave 3 vertical slice.  
Run the game with `godot` (interactive) from the repo root.

---

## A — Launch & Character Select

1. Launch — the game opens on the **Character Select** screen.
2. Verify two buttons appear, each tinted by their character colour (Ziv = pink, Avihay = blue).
3. Click **Ziv** → arena loads; Player appears as a pink square.

---

## B — Basic gameplay (Ziv)

4. Move with WASD — player moves in all 8 directions.
5. Within ~3 seconds an enemy (red swarmer) appears on the edge and moves toward you.
6. Enemies deal contact damage → HP bar (top-left) decreases.
7. Kill an enemy — a yellow XP gem spawns at the death position.
8. Walk near the gem OR wait for it to magnet in → XP bar fills.

---

## C — Level-up + Upgrade UI

9. Collect enough XP to level up — the game **pauses** and the upgrade panel appears.
10. Verify three choices are shown with descriptive names.
11. Pick **Stunning Looks+** (signature) → panel closes, game unpauses; weapon level increases (effect: beam_damage/charm_count scale up each level-up).
12. Pick generic upgrades at subsequent level-ups (e.g. Vitality Boost, Swift Feet) — confirm stats change (HP bar max grows, movement feels faster).

---

## D — Evolution unlock

13. Reach signature level 5 (pick **Stunning Looks+** five times total).
14. Also pick **Lingering Gaze** (passive) at least once.
15. On the next level-up the panel should show a **golden** button labelled "EVOLVE: Absolutely Fabulous".
16. Click EVOLVE → weapon evolves: beam now rotates continuously; CharmField is always-on.

---

## E — HUD accuracy

17. Timer in top-left increments in real time.
18. Kill counter increments each time an enemy dies.
19. HP bar reflects current/max HP correctly (goes up after Vitality Boost upgrade).
20. XP bar resets and refills between levels.
21. Level label updates each level-up.

---

## F — Mini-boss (at ~5 min / 300 s)

22. Survive to the 5:00 mark.  A **large white tank** (×3 scale) spawns — this is the mini-boss.
23. It has ~8× normal tank HP; it drops a burst of XP on death.

---

## G — Death & Game Over

24. Let enemies kill the player (HP → 0).
25. Game-over screen appears with:
    - "Survived M:SS" matching roughly how long you played
    - "Kills: N" matching the in-run kill counter
26. Click **Character Select** → returns to selection screen.
27. Click **Avihay** → arena reloads with Avihay (blue square, Chat Spam weapon firing bubbles).
28. Confirm Avihay loop: bubbles fire toward nearest enemy; evolve path shows "EVOLVE: Reply-All Apocalypse".
29. Click **Retry** on game-over → returns to arena with the same character.

---

## H — Success criteria mapping

| Criterion (spec §10) | Verified by step |
|---|---|
| Ziv loop + evolution | B–D |
| Avihay loop + evolution | G (Avihay run) |
| Upgrade UI golden EVOLVE slot | D step 15 |
| HUD timer / kills / HP / XP | E |
| Mini-boss at 300 s | F |
| Game-over shows correct score | G steps 25 |
| Retry and character select buttons work | G steps 26–29 |
| Full GUT suite 108/108 | CI / `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit` |
