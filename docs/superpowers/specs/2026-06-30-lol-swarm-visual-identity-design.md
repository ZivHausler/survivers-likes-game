# LoL Swarm Visual Identity — Graphic Design Doc

**Date:** 2026-06-30
**Status:** Art-direction reference (target style guide)
**Related:** [LoL Swarm Weapon Re-Skin](2026-06-29-lol-swarm-weapon-reskin-design.md)

> Art-direction north star for friends-swarm. This is a *reference target* describing the look we are aiming for, modeled on **League of Legends: Swarm**. Estimates about asset/poly/texture budgets are visual approximations, **not** confirmed internal Riot data. Section 16 ("How To Recreate") is the actionable part for our indie production.

---

## 1. Overall Visual Identity

League of Legends: Swarm has a stylized sci-fi arcade combat identity: bright, readable, energetic, and overloaded with projectile/VFX information while still staying legible from a top-down camera.

The mood is not realistic or gritty. It is closer to:

> "neon anime sci-fi League of Legends, viewed through a bullet-heaven survival camera."

Visually, it combines:

- League's painterly-stylized 3D champion readability
- Anima Squad cyber-anime theming
- urban sci-fi arena maps
- massive enemy swarm readability
- high-saturation projectile VFX
- clean gameplay silhouettes
- arcade-like UI and upgrade feedback

The first impression is: **bright cyber-fantasy chaos**, with colorful champions carving through dense alien waves in a clean futuristic city map.

It feels more like a stylized top-down action game than standard Summoner's Rift League. The camera is farther out, the environments are more arena-like, and the art is optimized for many enemies + many projectiles + constant movement rather than lane-based PvP readability.

## 2. Art Style Classification

A precise classification:

> **Stylized 3D cyber-anime bullet-heaven with painterly League materials, simplified top-down readability, and neon sci-fi VFX.**

Swarm uses the existing League visual language — stylized proportions, strong silhouettes, painterly textures, readable value grouping, non-photorealistic materials — and overlays Anima Squad's futuristic cybernetic-animal fantasy: glowing blues, magentas, purples, cyan effects, sci-fi panels, and alien enemy forms.

It is **not**:

- realistic PBR
- pixel art
- low-poly minimalism
- pure cel-shaded anime

It is closer to:

- stylized 3D
- hand-painted / baked-detail game assets
- semi-anime sci-fi character theming
- high-VFX arcade combat
- top-down bullet-heaven composition

The art is production-efficient: forms are simplified and exaggerated enough to read under gameplay pressure, but detailed enough to belong in the League ecosystem.

## 3. Shape Language

Built around instant readability at a small on-screen size.

### Champions

Heroic, iconic silhouettes inherited from League:

- broad shoulder/torso shapes for tankier champions
- long weapon or wing shapes for ranged/fantasy champions
- strong costume silhouettes
- readable hair/weapon/body breaks
- exaggerated pose readability
- clean upper-body landmarks

Because the camera is top-down and distant, facial details are secondary. Silhouette, movement, weapon trails, and VFX identity matter more.

### Primordian enemies

Mostly mass-readable swarm units:

- insectoid / alien / beast-like shapes
- angular bodies, pointed limbs
- purple-blue carapace coloring
- repeated enemy archetypes
- strong head/body directional cues
- small unit silhouettes that duplicate well in huge quantities

Enemies are not individually ornate — design is optimized for instancing, repetition, and crowd readability. Stronger silhouettes are reserved for elites and bosses.

### Environment

- broad road planes, clean plazas
- circular sci-fi structures
- large modular city props
- simplified sidewalks and lane markings
- readable obstacles
- big geometric forms rather than noisy detail

The ground is a readable stage for combat, not a visual focus.

## 4. Character Design

Playable characters are adapted League champions wearing Anima Squad-themed skins: **anime/cybernetic animal hero + stylized League champion proportions.**

Traits:

- heroic proportions over realistic anatomy
- simplified facial readability from top-down view
- strong costume color blocking
- animal-ear, wing, visor, armor, or tech motifs per champion
- bright accent materials
- readable weapon/ability identity
- high contrast between character body and ground
- strong VFX association per champion

Production likely relies on: broad silhouette blocking, texture-authored detail, baked AO, stylized material separation, LOD-aware geometry, animation-friendly topology, and League-style rig reuse.

Faces are not the gameplay priority. At Swarm's camera distance the readable features are: body silhouette, costume color, weapon silhouette, health bar, VFX aura, attack pattern.

### Estimated character asset complexity *(visual estimate, not confirmed data)*

- playable champions: mid-poly real-time assets, ~several thousand to low tens of thousands of triangles (champion/skin/LOD dependent)
- enemies: much cheaper, especially small swarm units
- detail: more texture/shader-driven than geometry-driven
- bosses: higher silhouette and material complexity than swarm units

Swarm needs many units on screen, so the pipeline almost certainly prioritizes LODs, mesh simplification, batching/instancing efficiency, simplified enemy rigs, repeated archetypes, and controlled material/shader cost. Riot has publicly described Swarm's technical challenges around minions, servers, and roguelike systems — consistent with displaying many AI units at once.

## 5. Environment Art

A futuristic urban combat arena — **Final City**, in the Anima Squad universe — not a natural fantasy map.

Characteristics:

- clean sci-fi city roads, plaza-like open arenas
- modular road/sidewalk surfaces
- large circular structures, industrial sci-fi props
- neon cyan accents
- road markings and geometric paving
- simplified destructibility (if any)
- sparse-to-medium prop density
- strong navigational clarity

Staged like a **combat board**: clear movement lanes, wide roads, open plazas, obstacle silhouettes, readable boundaries, low clutter under VFX.

Ground uses large readable material zones: gray asphalt, red/pink pavement, green grass/park, cyan sci-fi accents, yellow/white road markings, dark industrial machinery. This gives structure without competing with combat effects.

## 6. Materials and Texturing

A stylized League material model, not realistic PBR. Materials appear authored for readability: baked soft AO, color-blocked, hand-painted/painterly, moderately glossy on sci-fi surfaces, simplified roughness, optimized for top-down gameplay.

**Characters:** stylized skin shading, painted cloth/armor separation, (pseudo-)metallic sci-fi armor, emissive accents, baked crease shadows, color-blocked costume regions, texture-authored detail.

**Enemies:** purple/blue carapace surfaces, cool highlights, dark body masses, bright alien accents, repeated faction palettes, simplified surface breakup for mass readability.

**Environment:** clean asphalt/concrete, smooth sci-fi metals, stylized road markings, soft contact AO, minimal grime, limited texture noise, mostly matte surfaces with select glowing tech accents.

**Technical verbs:** sculpted for strong primary forms → retopologized for real-time → UV-unwrapped efficiently → baked normal/AO → stylized albedo → emissive/material masks → simplified for camera readability → optimized for large counts → color-blocked for gameplay roles → rim-lit/emissive via shader & VFX.

## 7. Lighting

Bright, soft, gameplay-readable — a controlled top-down setup, not harsh cinematic lighting. Goal: keep characters readable, enemies visible, projectiles distinct, ground navigable, UI clear.

Traits: soft ambient illumination, low-to-medium contrast shadows, baked/semi-baked impression, subtle AO under props/characters, bright emissive VFX, bloom on energy effects, glowing cyan/magenta accents, readable outlines through value contrast.

It avoids dramatic darkness because the player must parse dozens-to-hundreds of moving enemies. The strongest visual "light sources" are usually **not** environmental lamps but projectiles, abilities, explosions, shields, enemy attacks, pickups, and sci-fi map accents. Result: arcade combat look — clear battlefield, VFX provides the drama.

## 8. Color Palette

Highly saturated with a strong **cyan / blue / purple / magenta / pink** bias.

| Role | Colors |
|---|---|
| Enemies | purple / blue alien masses |
| Player abilities | bright, high-saturation VFX |
| Environment | neutral gray / muted red / green zones |
| UI | dark panels with bright readable icons/bars |
| Danger zones | strong colored circles / AoE fields |
| Pickups | bright green / blue / yellow |

The environment is deliberately controlled so VFX can be loud. The game relies on **high chroma contrast** over realism: purple enemies on gray roads read instantly, cyan/magenta projectiles pop, and dark UI backing keeps bars/timers visible.

## 9. Camera and Composition

A top-down / isometric-like League camera tuned for bullet-heaven: distant, top-down angled, perspective-like (not pure ortho), locked to readability, wide enough to show incoming waves, close enough to identify the champion and local threats.

Composition differs from PvP League because the mode depends on omnidirectional movement, enemies from all sides, large attack fields, circular AoE telegraphs, dense projectile patterns, and survival-space management.

Art is optimized for the angle: exaggerated silhouettes from above, minimal vertical detail that blocks readability, clean ground materials, enemy groups readable as colored masses, large VFX shapes, clear HUD overlays. The player reads the screen as a moving **tactical field**, not a cinematic scene.

## 10. Animation Style

Snappy, readable, stylized, arcade-like — built for combat readability from a distant view, not realistic mocap.

Traits: fast attack loops, readable movement cycles, simplified enemy locomotion, strong directional motion, short anticipation windows, clear impact timing, repeated swarm loops, exaggerated spell/attack timing, VFX-driven hit feedback, cycles optimized for many units.

Champions likely adapt League animation assets; the distant camera + high density demands readable-in-silhouette, non-subtle, VFX-synced, efficient playback. Enemies use simpler rigs/loops (crawl/run/fly, charge, hit/death dissolve, boss tells, limited states). The priority is **function over nuance**: the player must instantly read "enemy moving / attacking," "boss telegraph," "projectile incoming," "ability fired."

## 11. VFX Style

A defining layer: **neon, saturated, shader-driven, additive, readable, intentionally over-the-top.**

Effects: blue projectile streams, pink/purple bursts, glowing shields, circular AoE fields, slash trails, radial attack rings, energy waves, impact sparks, enemy hit flashes, large boss effects, pickup/XP effects, UI upgrade feedback.

Technical vocabulary: additive bloom, alpha-blended particles, emissive mesh projectiles, shader-authored trails, flipbook explosions, radial burst meshes, circular telegraph decals, dissolve death shaders, impact decals, screen-space glow, layered particle systems, color-coded attack zones, spline/ribbon trails, soft shockwave rings, projectile instancing.

VFX still need **hierarchy**: player effects feel powerful; enemy attacks stay readable; boss telegraphs override background noise; pickups are visible but not distracting; ally abilities don't hide danger. The strongest identity is cyan/blue player energy vs. purple/magenta alien chaos.

## 12. UI and HUD Style

Keeps League DNA, adapted for roguelite/bullet-heaven needs.

Components: bottom ability/item bar, champion portrait, health bar, XP/progression bar, top timer, minimap, teammate health/portraits, level-up/upgrade choice UI, dark rectangular panels, bright icon readability, compact information density.

Style: **clean sci-fi League HUD with roguelite upgrade readability** — functional and combat-focused, not ornate fantasy UI. Dark panels let colorful icons/bars pop; ability icons keep League's painterly icon language. The layout communicates current build, cooldowns/passive weapons, level/progression, team state, elapsed time, and map position. It avoids decorative borders — arcade-functional over cinematic.

## 13. Technical Graphics Impression

Runs inside the League engine/client ecosystem, but with substantial new work (controls, AI/base systems, minion/server challenges, roguelike systems).

**Rendering level:** optimized stylized real-time rendering, not high-end cinematic. Targets broad PC compatibility — supports many enemies, many VFX, co-op, stable frame rate, readable gameplay, low-to-medium hardware needs.

**Polygon density (estimated):** small enemies low-to-mid poly (heavily optimized); champions mid-poly (~League champion/skin range); bosses higher; environments modular medium detail with large simple surfaces; props simplified with baked/painted detail.

**Texture resolution (estimated):** characters moderate stylized maps; enemies lower-res or shared atlases; environment tiled/modular; VFX sprite sheets, flipbooks, gradients, emissive masks.

**Shader complexity:** stylized diffuse/specular, emissive masks, alpha-blended particles, additive VFX, simple dissolve/death, decals/telegraphs, bloom/post, AO/baked shading. **Not** dependent on ray tracing, accurate reflections, high-end SSS, dense tessellation, or cinematic GI.

**Performance strategy:** LODs, simplified enemy rigs, repeated archetypes, texture atlasing, shader budget discipline, VFX pooling, projectile batching, modular environment reuse, controlled lighting, limited expensive dynamic shadows.

## 14. Asset Production Breakdown

### Characters

1. **Concept art** — define Anima Squad fantasy: cyber-animal hero, champion identity, color palette, VFX motif.
2. **Blockout** — readable top-down silhouette: head, shoulders, weapon, costume landmarks.
3. **High-poly sculpt / form pass** — large armor, cloth, hair, cybernetic parts, wings/ears/weapon forms.
4. **Retopology** — animation-friendly low/mid-poly game mesh.
5. **UV unwrapping** — prioritize visible upper body, weapons, major costume elements.
6. **Baking** — normals, AO, curvature, possibly cavity.
7. **Texture authoring** — stylized albedo, masks, emissive regions, roughness/specular behavior.
8. **Rigging/skinning** — reuse champion rig standards; ensure readability.
9. **Animation integration** — idle, move, attack, cast, hit, death/respawn, ability loops.
10. **VFX binding** — trails, projectiles, shields, auras, impacts.
11. **LOD optimization** — reduce geometry/detail for gameplay camera + mass performance.

### Enemies

- archetype concept (small swarm, ranged swarm, elite, boss)
- strong silhouette blockout → simplified model
- shared material palette
- basic rig or procedural movement
- reusable hit/death/dissolve VFX
- aggressive optimization for large counts

### Environment

- map layout blockout → gameplay readability testing
- modular road/plaza kit
- prop kit (sci-fi machinery, barriers, park areas, structures)
- material set (asphalt, pavement, grass, metal, glowing tech)
- lighting pass → VFX/telegraph readability pass
- optimization and collision simplification

## 15. Similar Games / Visual References

| Game | Similar because | Different because |
|---|---|---|
| **Vampire Survivors** | enemy flood, frequent attacks, readability over combat detail | pixel/retro 2D vs. stylized 3D |
| **HoloCure** | bullet-heaven crowd-clearing readability | 2D anime pixel/chibi vs. 3D cyber-anime |
| **Temtem: Swarm** | top-down creature-swarm survival readability | cuter/toy-like vs. sharper neon cyber-sci-fi |
| **LoL: Arena** | shared champion materials, UI DNA, top-down readability | smaller PvP vs. dense enemy/projectile handling |
| **Risk of Rain (Returns / 2)** | roguelite escalation, VFX-heavy survival pressure | different camera/style |
| **Battlerite** | top-down readability, ability telegraphs, arena clarity | different fantasy and enemy density |

## 16. How To Recreate This Style *(actionable for our indie target)*

The goal is **not** "copy League." Practical target:

> **Stylized 3D top-down sci-fi bullet-heaven with clean silhouettes, modular city arenas, and saturated neon VFX.**

### Character modeling

**Do:** strong top-down silhouette; medium detail density; clear head/torso/weapon separation; exaggerated costume landmarks; large readable accessories; simplified anatomy; broad forms before small details; color-blocked armor/clothing; emissive accents.

**Avoid:** tiny details that vanish from camera; realistic face detail as a priority; noisy silhouettes; thin gray weapons that blend into the ground; excessive micro-geometry.

### Enemy modeling

**Do:** 3–5 enemy families max for early production; strong repeated silhouettes; purple/blue alien palette; cheap rigs; obvious movement direction; readable elite variants; exaggerated boss scale.

For regular swarm: simple mesh, clear outline, low animation complexity, obvious attack state, cheap materials, easy recolor variants.

### Texturing

**Do:** stylized albedo, baked AO, hand-painted gradients, controlled roughness, emissive masks, low noise, clear material separation.

**Avoid:** photoreal scans, gritty realism, overly detailed normals, muddy textures, high-frequency dirt everywhere.

### Lighting

**Do:** bright ambient lighting, soft shadows, subtle AO, neutral ground lighting, bloom only on important effects, emissive sci-fi accents.

**Avoid:** dark dramatic lighting, heavy fog hiding enemies, realistic contrast that reduces readability, too many colored lights competing with projectiles.

### Color

| Layer | Palette |
|---|---|
| Environment | gray, muted red, muted green, dark metal |
| Player VFX | cyan, blue, gold, pink |
| Enemies | purple, blue, magenta |
| Danger zones | red, orange, purple |
| Pickups | bright green, blue, yellow |

Keep the background **less saturated** than combat VFX.

### VFX

**Do:** radial bursts, projectile ribbons, additive glows, emissive meshes, circular telegraphs, dissolve deaths, impact flashes, controlled screen shake, color-coded enemy attacks.

**Avoid:** VFX that fully cover the player; same color for enemy danger and player attacks; particles with too much alpha noise; long lingering effects that hide the ground; realistic smoke/dust dominating the screen.

### UI

**Do:** dark panels, bright icons, simple borders, readable health bars, clear XP/progression bar, large upgrade-choice cards, compact build icons, minimal clutter.

**Avoid:** ornate fantasy UI, too many tiny numbers, low-contrast text, transparent panels over busy combat.

### Camera

**Do:** top-down perspective, fixed combat distance, slight isometric angle, wide enemy visibility, large readable attack shapes, character centered or slightly offset.

**Avoid:** low third-person camera, excessive zoom-in, camera shake that prevents projectile reading, cinematic angles during active combat.

### Polygon/detail budget *(indie approximation, not confirmed League data)*

| Asset | Triangle budget |
|---|---|
| Small enemies | 500–2,000 |
| Elite enemies | 2,000–6,000 |
| Bosses | 8,000–25,000 |
| Playable characters | 8,000–25,000 |
| Weapons/accessories | separate simple meshes, strong silhouette |
| Environment props | modular, low-to-mid poly |

Use LODs aggressively when many enemies are on screen.

## 17. Prompt For Image / 3D Asset Generation

### Reusable prompt

> Stylized 3D top-down game asset in the visual style of a neon sci-fi bullet-heaven action game, inspired by cyber-anime hero combat and polished MOBA character readability. Create a full-body playable hero character designed for a distant top-down/isometric camera, with a strong readable silhouette, exaggerated heroic proportions, simplified facial detail, large iconic weapon, clean armor shapes, cybernetic animal-themed costume elements, glowing cyan and magenta emissive accents, color-blocked materials, painterly stylized textures, baked ambient occlusion, simplified PBR-like metal and cloth separation, polished sci-fi armor panels, readable from gameplay distance. Bright saturated VFX aura, subtle rim lighting, soft studio/game lighting, clean neutral background, high clarity, optimized real-time game model look, medium-poly stylized 3D, animation-friendly topology, broad silhouette blocking, no realistic skin pores, no tiny unreadable details.
>
> **Camera:** 3/4 top-down isometric gameplay view, full body visible, centered, neutral pose, readable silhouette.
>
> **Lighting:** soft ambient illumination, subtle contact shadows, emissive glow on sci-fi details, controlled bloom.
>
> **Color palette:** cyan, electric blue, purple, magenta, dark navy, silver, clean gray, with high contrast between character and background.
>
> **Rendering keywords:** stylized 3D, MOBA-inspired, cyber-anime, bullet-heaven, hand-painted textures, baked AO, emissive masks, optimized game asset, clean topology, readable silhouette, high-saturation VFX, sci-fi armor, top-down readability.

### Negative prompt

> realistic military style, gritty realism, horror gore, photorealistic skin pores, muddy colors, low contrast, over-detailed microgeometry, noisy textures, cluttered silhouette, tiny accessories, unreadable weapon, dark lighting, cinematic close-up, first-person view, side-scroller view, pixel art, flat 2D sprite, excessive bloom covering the model, realistic smoke, messy UI, background clutter, hyper-real PBR, ultra-detailed face focus, thin fragile silhouette.
