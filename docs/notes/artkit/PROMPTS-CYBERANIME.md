# Prompt Pack — cyber-anime neon sci-fi (SDXL)

> **This is the active prompt pack for friends-swarm.**
> Copy-paste prompts tuned for a **cohesive neon cyber-anime roster** matching the
> [LoL Swarm visual identity](../../superpowers/specs/2026-06-30-lol-swarm-visual-identity-design.md).
> Works with both `gen.py --creature` (SDXL concept refs) and the full-prompt tools
> (Hunyuan3D pipeline, ComfyUI, WebUI).
>
> Consistency rule: **keep the STYLE BLOCK and NEGATIVE identical for every asset.**
> Only swap `{SUBJECT}`. Lock the seed while iterating.

---

## STYLE BLOCK (verbatim from §17 of the visual-identity north-star)

When building a prompt string, prepend `{SUBJECT},` before this block. For enemies and
props, also substitute the subject description for the phrase *"Create a full-body playable
hero character"* — everything else stays identical.

For `gen.py --creature`, pass only the `{SUBJECT}` line; the style block is baked into
`gen.py`. For full-prompt tools, concatenate `{SUBJECT},` + the block below.

```
Stylized 3D top-down game asset in the visual style of a neon sci-fi bullet-heaven action game, inspired by cyber-anime hero combat and polished MOBA character readability. Create a full-body playable hero character designed for a distant top-down/isometric camera, with a strong readable silhouette, exaggerated heroic proportions, simplified facial detail, large iconic weapon, clean armor shapes, cybernetic animal-themed costume elements, glowing cyan and magenta emissive accents, color-blocked materials, painterly stylized textures, baked ambient occlusion, simplified PBR-like metal and cloth separation, polished sci-fi armor panels, readable from gameplay distance. Bright saturated VFX aura, subtle rim lighting, soft studio/game lighting, clean neutral background, high clarity, optimized real-time game model look, medium-poly stylized 3D, animation-friendly topology, broad silhouette blocking, no realistic skin pores, no tiny unreadable details.

Camera: 3/4 top-down isometric gameplay view, full body visible, centered, neutral pose, readable silhouette.

Lighting: soft ambient illumination, subtle contact shadows, emissive glow on sci-fi details, controlled bloom.

Color palette: cyan, electric blue, purple, magenta, dark navy, silver, clean gray, with high contrast between character and background.

Rendering keywords: stylized 3D, MOBA-inspired, cyber-anime, bullet-heaven, hand-painted textures, baked AO, emissive masks, optimized game asset, clean topology, readable silhouette, high-saturation VFX, sci-fi armor, top-down readability.
```

---

## NEGATIVE PROMPT (verbatim from §17)

```
realistic military style, gritty realism, horror gore, photorealistic skin pores, muddy colors, low contrast, over-detailed microgeometry, noisy textures, cluttered silhouette, tiny accessories, unreadable weapon, dark lighting, cinematic close-up, first-person view, side-scroller view, pixel art, flat 2D sprite, excessive bloom covering the model, realistic smoke, messy UI, background clutter, hyper-real PBR, ultra-detailed face focus, thin fragile silhouette.
```

---

## Character T-pose constraints (MANDATORY for riggable characters)

Append to any character {SUBJECT} line. Required for Hunyuan3D → Mixamo auto-rigging.
A character holding a fused prop **cannot** be auto-rigged (Mixamo fails). Generate
props separately and attach to hand bones after rigging — see CHARACTER-GUIDE.md Stage 0.

**Prompt addition:**
```
strict T-pose, arms straight out horizontal, elbows straight, hands open and empty, full body head-to-boots, front view, symmetric, plain light-grey background, even lighting
```

**Negative addition for characters:**
```
holding object, weapon in hand, crossed arms, arms down, bent elbows, action pose, props in hands, fists, closed hands
```

---

## {SUBJECT} slot table

Each line is a drop-in replacement for `{SUBJECT}` in the STYLE BLOCK.

### Friends (playable characters)

Append the T-pose constraints above to each friend's {SUBJECT} when generating riggable
character images. Accent colors are per-character identity landmarks; include them in the
STYLE BLOCK's **Color palette** line (replace or extend the base palette).

| Friend | {SUBJECT} |
|---|---|
| Avinoam | `radiant cyber-paladin, gold and white plate armor, large mechanical angelic tech wings, glowing golden halo ring, gold and white accent` |
| Avihay | `netrunner messenger hero, sleek wraparound visor headset, three floating holo-screens, data-cable sash, electric blue accent` |
| Barak | `beast-handler warrior, wolf-ear sensor visor, pulsing amber tech collar, rugged layered armor, amber and orange accent` |
| Ido | `hazmat cyber-alchemist, sealed hazmat helmet with faceplate, toxic-vent ports on shoulders, neon-green canister belt, toxic green accent` |
| Matan | `gadgeteer engineer, shoulder-mounted quad drone-pods, sensor antennae crown, compact multi-tool chassis, magenta accent` |
| Natali | `medic idol, glowing cyan cross emblem on chest, soft segmented armor plates, field medical pack, pink and cyan accent` |
| Yinon | `aviator ace, sleek back-mounted jet-pack, flip-down targeting visor, flight suit, military orange accent` |
| Yoav | `courier speedster, streamlined suit, large aerodynamic aero-fins on shoulders and calves, motion-blur speed lines, cyan and yellow accent` |
| Yuval | `DJ performer, large shoulder-mounted speaker rig, bass-cannon forearm brace, LED equalizer panel on chest, purple and cyan accent` |
| Ziv | `pop idol hero, holographic glam armor, floating charm-aura particle ring halo, crystalline mic-scepter, pink and magenta accent` |

### Enemies (Primordian aliens)

All enemies share the base alien palette: **purple-blue alien carapace, angular body, pointed
limbs, glowing alien accents**. Add T-pose constraints for riggable mesh generation; use a
loose neutral stance for concept ref images.

| Slot | {SUBJECT} |
|---|---|
| Small insectoid swarmer | `small insectoid alien swarmer unit, compact chitinous purple-blue carapace, four pointed limbs, mandibles, glowing amber eye accents, low readable silhouette` |
| Ranged spitter | `alien ranged spitter unit, bioluminescent acid sac on back, elongated lower jaw with nozzle, purple-blue carapace, glowing cyan dorsal stripe` |
| Heavy tank | `heavy armored alien tank unit, thick angular carapace shoulder plates, squat powerful build, reinforced chest guard, dark purple-blue with amber glow joints` |
| Ranged caster | `alien psionic caster unit, hovering levitating posture, elongated dome skull, glowing purple energy rings around forearms, dark carapace, magenta eye glow` |
| Fast dasher | `fast alien dasher unit, sleek streamlined narrow purple-blue carapace, digitigrade blade-legs, short spine-blades on arms, electric blue speed-line markings` |
| Boss — large ornate | `large ornate alien boss, imposing scale three times normal height, elaborate angular crown-carapace, multiple glowing rune markings, deep purple-blue with gold and magenta accents` |
| Boss — elite variant | `elite alpha alien boss, asymmetric battle-scarred carapace, exposed bioluminescent core at chest, multiple articulated arm-blades, purple-blue with intense cyan-white core glow` |

### Props (environment and weapon objects)

For props, use this camera/pose override instead of the character-facing section of the
STYLE BLOCK — prepend it to {SUBJECT}:

```
isolated prop object, side 3/4 profile view, plain white background, no hands, full object in frame, grip or mount point visible,
```

Negative additions for props:
```
hands, person, character, holding, scene background, multiple objects
```

| Slot | {SUBJECT} |
|---|---|
| Sci-fi barrier | `sci-fi modular barrier wall panel, reinforced angular form, cyan emissive edge stripe, matte dark metal` |
| Circular structure | `large circular sci-fi plaza ring structure, glowing neon ring accent, smooth panel surfaces, electric blue glow` |
| Machinery unit | `industrial sci-fi machinery block unit, vent grates, pressure pipes, recessed control panel, dark brushed metal` |
| Neon pylon | `tall neon energy pylon beacon, angular faceted column, pulsing cyan-magenta gradient glow core, heavy tech base` |
| Neon sign | `floating holographic neon sign panel, angular sci-fi typeface characters, electric blue and magenta color, thin mounting arm` |
| Industrial crate | `sci-fi industrial container crate, brushed metal shell, stencil warning markings, glowing edge-lit corner brackets` |
| Energy conduit | `armored energy conduit cable segment, ribbed casing, small viewport window showing glowing plasma core within` |
| Sci-fi terminal | `upright sci-fi data terminal console, angular dark metal chassis, embedded holographic display, cyan status glow` |

---

## Generation settings (SDXL)

| Setting | Value |
|---|---|
| Sampler | DPM++ 2M Karras |
| Steps | 30 |
| CFG scale | 6.5 |
| Size | 1024×1024 |
| Seed | **lock a fixed number** while building the roster; vary only to explore |
| Clip skip | 1 (SDXL default — do not skip) |

These match the values already in `gen.py`. Pass `{SUBJECT}` via `--creature`; the style
block is baked into the script's prompt template. For full-prompt tools (WebUI, ComfyUI),
prepend `{SUBJECT},` + T-pose constraints + STYLE BLOCK manually.

---

## Baked block (gen.py, ≤77 tokens)

The condensed versions below are what is **baked into `gen.py`** as `STYLE_BLOCK` and `NEGATIVE`.
SDXL's CLIP encoder truncates at 77 tokens; the full §17 block above exceeds that limit and is
intended for long-prompt tools (ComfyUI, compel, WebUI with prompt editing). This baked block is a
faithful distillation of §17 for single-pass SDXL generation via `gen.py --creature`.

> **Note:** keep `--creature` to **≤15 words** — the static STYLE_BLOCK is ~52 tokens, so a longer subject pushes the combined prompt past CLIP's 77-token limit and the tail silently truncates. For longer subjects, use a long-prompt tool (ComfyUI/compel).

**STYLE_BLOCK** (`{creature}` is injected at runtime via `--creature`):

```
{creature}, stylized 3D cyber-anime hero, neon sci-fi bullet-heaven, strong readable silhouette, exaggerated heroic proportions, glowing cyan and magenta emissive accents, color-blocked painterly textures, baked ambient occlusion, clean topology, polished sci-fi armor, soft studio lighting, plain background, top-down game-ready
```

**NEGATIVE**:

```
realistic, photorealistic, gritty, muddy colors, low contrast, noisy textures, cluttered silhouette, tiny details, dark lighting, pixel art, flat 2d sprite, blurry, deformed, bad anatomy, extra limbs, text, watermark
```

---

## Direction / facing variants

You only need **front** for the T-pose source; all other angles come from Hunyuan3D.
If generating a concept ref at a specific angle, append ONE of these to the STYLE BLOCK:

- Front: `front-facing view, facing the viewer`
- 3/4 top-down: `3/4 top-down isometric view` (default — already in STYLE BLOCK)
- Side profile: `strict side profile view, facing right`

Keep everything else identical so the same character reads across angles.

---

## Quick consistency checklist

- [ ] Same STYLE BLOCK + NEGATIVE for every asset
- [ ] Same model/checkpoint + same sampler/steps/CFG
- [ ] Locked seed while iterating one asset
- [ ] Characters: T-pose constraints appended, hands open and empty, plain light-grey background
- [ ] Props: isolated object, side 3/4 profile, plain white background, no hands in frame
- [ ] Once you have ~15 approved reference images → train a `cyber-anime swarm style` LoRA
      (see STYLE-GUIDE-CYBERANIME.md) and prepend its trigger word to lock the look permanently
