# Friends Swarm — Design Spec

**Date:** 2026-06-28
**Engine:** Godot 4 (GDScript)
**Genre:** Horde-survivor / bullet-heaven (Vampire Survivors–style), single-player
**Working title:** Friends Swarm (rename freely)

## 1. Concept

A horde-survivor game where each playable character is based on one of the
designer's real friends. You pick a friend, spawn in an arena, and survive
endless waves of enemies. You control only movement; your character's signature
ability auto-fires. Killing enemies drops XP; leveling up lets you pick
upgrades that build toward a powerful evolved ability.

## 2. v1 Scope (this spec)

**In scope:**
- One arena, single-player.
- Core run loop: move-only control, auto-firing signature ability, XP gems,
  level-up, upgrade selection, escalating difficulty, death → game-over screen.
- Enemy waves with a few enemy types and a mini-boss cadence.
- Full upgrade + synergy/evolution system.
- **Two playable characters: Ziv (control) and Avihay (DPS spray).**

**Out of scope (deferred to later versions):**
- The other 8 characters (system is built to add them as data; abilities coded later).
- Meta-progression (between-run coins, unlocks, permanent boosts).
- Co-op / multiplayer.
- Final art and audio (v1 uses placeholder sprites/shapes).

## 3. Core Game Loop (one run)

1. Title screen → character select (Ziv or Avihay).
2. Spawn in center of arena. Enemies spawn at the edges and path toward the player.
3. Signature ability auto-fires on a timer. Player controls movement only
   (WASD / arrow keys).
4. Killed enemies drop XP gems; walking near them (pickup magnet) collects them.
5. Filling the XP bar triggers a level-up: game pauses, player picks 1 of 3
   random upgrades.
6. Difficulty escalates on a timeline (more/tougher enemies; mini-boss roughly
   every 5 minutes).
7. Player HP reaches 0 → game over, showing survival time and kill count.
   Option to restart / return to character select.

Target run length: ~15–20 minutes at full difficulty curve.

## 4. Enemies & Waves

- **Enemy types (v1):**
  - *Swarmer* — fast, low HP, low damage; comes in large numbers.
  - *Tank* — slow, high HP, high contact damage.
  - *Spitter* — ranged; keeps distance and fires slow projectiles.
- **Behavior:** simple steering toward the player (classic horde pathing).
- **Spawning:** a `Spawner` reads a difficulty timeline that increases spawn
  rate and unlocks tougher variants over time.
- **Mini-boss:** a larger, high-HP enemy spawns on a cadence (~every 5 min);
  dies into a burst of XP.

## 5. Upgrades & Synergy / Evolution

On each level-up, offer **1 of 3** drawn from:
- **Signature upgrades** — level the character's main ability (levels 1→5:
  more damage, projectiles, size, fire rate, etc.).
- **Dedicated passive** — each signature ability has exactly one matching
  passive, which also levels up.
- **Generic passives** — move speed, max HP, pickup magnet range, fire rate,
  armor, etc.

**Evolution rule:** when the **signature ability is at max level** AND the
character **owns its dedicated passive (≥ level 1)**, a special golden
**"EVOLVE"** option appears in the next level-up choice set. Selecting it
replaces the signature with its evolved form (one evolution per character).

### v1 character synergy chains

| Character | Signature | Dedicated Passive | Evolution |
|-----------|-----------|-------------------|-----------|
| **Ziv** | *Stunning Looks* — sparkle charm aura + slow piercing rainbow beams | *Vanity Mirror* (charm duration) | **Absolutely Fabulous** — permanent charm field + sweeping disco laser |
| **Avihay** | *Chat Spam* — rapid WhatsApp message-bubble projectiles in all directions | *Unlimited Data* (fire rate) | **Reply-All Apocalypse** — homing bubbles flood the screen |

## 6. Full Roster (design reference; only Ziv & Avihay built in v1)

| # | Character | Signature Ability | Archetype |
|---|-----------|-------------------|-----------|
| 1 | Ziv | Stunning Looks — charm aura + piercing rainbow beam | Control |
| 2 | Avinoam | Divine Smite — holy beams on random enemies | Random nuke |
| 3 | Matan | Irritation Aura — enrages enemies to attack each other + long melee | Melee/control |
| 4 | Avihay | Chat Spam — bullet-hell message bubbles | DPS spray |
| 5 | Ido | Toxic Trail — fart gas DoT clouds + burp knockback | Area denial |
| 6 | Yuval | Soundwave Rings — expanding stun pulses | AoE control |
| 7 | Natali | Contagious Laughter — heal aura + freeze enemies | Support |
| 8 | Barak | Dog + Vanish — pet summon + periodic invincibility | Summoner |
| 9 | Yinon | Rockets — explosive artillery + yell knockback | Burst AoE |
| 10 | Yoav | Wolt Strike — delivery-scooter strafes + exploding coins | Strafe/summon |

Each will follow the same signature → passive → evolution structure when built.

## 7. Project Structure (Godot, data-driven)

Designed so adding a new friend is mostly authoring a data file plus one
ability scene.

- **`Player`** (scene): movement, HP, XP, leveling, holds the equipped
  `Weapon` and applies passives. Shared by all characters.
- **`Weapon`** (interface/base script): common API (`fire()`, `level_up()`,
  `evolve()`). Each signature ability is its own scene/script extending it.
- **`CharacterData`** (Resource): `{ name, sprite, base_stats, weapon_scene,
  dedicated_passive, signature_upgrades, evolution }`. One per friend.
- **`Enemy`** (scene + variants): HP, contact damage, steering toward player.
- **`Spawner`**: reads difficulty timeline, spawns enemies and mini-bosses.
- **`XPGem`** (scene): dropped on kill, magnetized to player.
- **`UpgradeSystem` / `UpgradeUI`**: builds the level-up choice set (including
  the evolution rule) and applies picks.
- **`GameManager`**: run state, timer, kill count, pause/level-up flow,
  game-over.
- **Art:** placeholder colored shapes / simple sprites in v1; real art later.

## 8. AI Knowledge Base (Zettelkasten)

The repo maintains a Zettelkasten-style knowledge base so any future session
(human or AI) can get oriented from a few small linked notes instead of
re-reading the whole codebase.

- **Location:** `docs/notes/`, with `docs/notes/INDEX.md` as the entry point
  (a "map of content" listing all notes by category — read this first).
- **Atomic notes:** one concept per file, with frontmatter
  (`id`, `title`, `tags`, `links`) and cross-links via `[[note-id]]`. Each note
  is ~one screen and points at the relevant code (file paths + key scene/node
  names) — it indexes the source, it does not duplicate it.
- **Note types:**
  - *System notes* — one per component: `player`, `weapon-system`, `spawner`,
    `upgrade-system`, `enemy`, `game-manager`, `xp-gem`.
  - *Concept notes* — cross-cutting: `evolution-rule`, `difficulty-timeline`,
    `data-driven-characters`.
  - *Decision notes* (ADR-style, the *why*): `adr-godot`,
    `adr-data-driven-roster`.
  - *Runbook notes* — task recipes: `how-to-add-a-character`,
    `how-to-add-an-enemy`.
- **Code back-references:** every GDScript file begins with a one-line header
  comment pointing to its note (e.g. `# See docs/notes/weapon-system.md`).
- **The hard rule (enforced in the implementation plan):** every task that adds
  or changes a component must create or update its note in the same step. A
  component is not "done" until its note exists and is current. This keeps the
  knowledge base from rotting.

## 9. Testing Approach

- Manual playtest as the primary check (it's a feel-driven game).
- Unit-test pure logic where it pays off: upgrade pool generation, the
  evolution-eligibility rule, and difficulty-timeline scaling.
- Build vertical-slice first: a player that moves + one auto-firing weapon +
  one enemy type + XP/level-up, then layer on upgrades, synergy, second
  character, more enemies, and the mini-boss.

## 10. Success Criteria (v1)

- Can select Ziv or Avihay and play a full run start to death.
- Signature ability auto-fires and is visibly different between the two.
- Leveling offers 1-of-3 upgrades; signature, passive, and generic upgrades
  all appear and apply.
- Reaching max signature + owning the passive surfaces the golden EVOLVE
  option, and taking it visibly transforms the ability.
- Difficulty escalates over time; a mini-boss appears on cadence.
- Death shows survival time + kill count and allows restart.
- `docs/notes/` exists with an `INDEX.md` map of content and a current,
  cross-linked note for every component built in v1; each GDScript file
  header-comments its note path.
