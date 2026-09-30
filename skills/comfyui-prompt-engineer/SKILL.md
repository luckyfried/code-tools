---
name: comfyui-prompt-engineer
description: Use when writing or rewriting the text of a ComfyUI positive or negative prompt for a specific model family - FLUX, SDXL, SD 1.5, Wan video, AnimateDiff - or for a run that uses a character LoRA, InstantID, PuLID, IP-Adapter, or a FLUX Kontext edit. Covers prompt style per model, trigger words, (word:1.2) weighting, negative prompts and when they do nothing, and where FLUX guidance is set. Triggers include "write a prompt for", "improve this prompt", "FLUX prompt", "SDXL prompt", "negative prompt", "prompt weighting", "trigger word", "Kontext edit prompt", and "the output ignores my prompt". For building or editing the workflow graph itself, use comfyui-workflow-json; for failed runs or broken-looking output, use comfyui-troubleshooter.
---

Adapted from MCKRUZ/ComfyUI-Expert (MIT); see LICENSE.

# ComfyUI prompt engineer

Different model families read prompts differently. Find out which model the workflow loads before writing a word. With the comfy MCP server connected, read the workflow's loader node, or use `search_models` to see what is installed. When the workflow came from an official template (`search_templates`, `fetch_template`), keep its sampler settings as the starting point and change only the prompt text.

## Where each setting lives

- Prompt text goes in the text encoder node: `CLIPTextEncode.text`, or `CLIPTextEncodeFlux.clip_l` and `.t5xxl` for FLUX.
- `KSampler.cfg` is classifier-free guidance. At `cfg` 1.0 ComfyUI skips the negative pass entirely, so **a negative prompt has no effect at cfg 1.0**.
- FLUX.1 [dev] is guidance-distilled: its guidance strength is set on the conditioning, not with `KSampler.cfg`. Use the `FluxGuidance` node (input `guidance`, default 3.5) on the positive conditioning, or the `guidance` input of `CLIPTextEncodeFlux` (same default). Use one or the other, not both. Keep `KSampler.cfg` at 1.0 for these models. The value only acts on a checkpoint that carries a guidance embedding; FLUX.1 [schnell] does not, so it ignores it.

## Model rules

### FLUX (dev, schnell, Kontext)

- Write natural-language sentences: subject, setting, lighting, camera or style.
- Leave out tag soup such as "masterpiece, best quality, 8k". It does not help and crowds out description.
- On [dev]-type checkpoints, raise or lower `FluxGuidance.guidance` to change how strongly the prompt is followed. Do not raise `KSampler.cfg`.
- With `cfg` at 1.0 the negative prompt is ignored. Say what you want instead of listing what to avoid.

Good:

```
photorealistic portrait of a woman with auburn hair and green eyes, freckles across
her nose and cheeks, wearing a cream knit sweater, sitting in a cafe with warm ambient
lighting, shallow depth of field, shot on an 85mm lens
```

Weak:

```
masterpiece, best quality, 8k uhd, highly detailed, photorealistic portrait...
```

### SDXL and SD 1.5 (and checkpoints fine-tuned from them)

- Tag-style, comma-separated phrases work well. Quality tags at the front are a common habit with these families.
- SD 1.5 prompts work best short and dense. SDXL tolerates longer, more descriptive prompts.
- These are run with `cfg` above 1.0, so the negative prompt is used. Start from the checkpoint's or template's recommended `cfg`; `KSampler` defaults to 8.0.
- Weighting: `(phrase:1.3)` sets a weight; each bare `( )` pair multiplies by 1.1, so `((phrase))` is 1.21. Keep weights modest, because large ones distort.
- Textual inversion embeddings are referenced as `embedding:name` in the prompt text.

```
masterpiece, best quality, photorealistic portrait of a woman, detailed skin texture,
freckles, green eyes, auburn hair, natural window light, indoor, shallow depth of field,
film grain
```

### Wan video

- Describe the motion, not only the appearance: who moves, how, and what the camera does.
- Keep it short and concrete: subject, action, setting, then light or style.
- When the workflow's `cfg` is above 1.0 the negative prompt is used, and one listing motion faults helps.

```
young woman with auburn hair talking naturally with gentle hand gestures,
seated at a modern desk, slow push-in, soft studio lighting
```

### AnimateDiff

Prompt as for the base model it runs on (SD 1.5 or SDXL), and add explicit subject and camera motion.

## With identity and edit methods

### Character LoRA

- Put the LoRA's trigger word first. The trigger is whatever the LoRA was trained with, so read it from the LoRA's model card or metadata. Never guess it.
- Do not re-describe features the LoRA has learned. Spend the words on what varies: pose, clothing, setting, lighting.

```
<trigger>, standing on a rooftop at sunset, wind in her hair, casual summer dress,
city skyline behind, golden hour light, cinematic composition
```

### InstantID (SDXL)

- Do not describe facial features; the reference image supplies them. Describe everything else.
- Its author recommends lowering CFG to about 4-5 (or adding `RescaleCFG`), since InstantID tends to burn the image.
- Its training data carried watermarks, so a size slightly off the standard ones (for example 1016x1016 instead of 1024x1024) avoids them.

```
photorealistic portrait, black leather jacket, standing in an alley, dramatic side
lighting, moody urban atmosphere
```

### PuLID

- Facial description is tolerated better than with InstantID, but the reference still leads.
- The `method` input: `fidelity` stays closest to the reference, `style` gives the checkpoint more freedom, and `neutral` applies no normalization (lower the weight when using it).

### IP-Adapter / FaceID

- Describe the style and scene you want, not the face.
- `weight_type` controls how the reference is applied; `style transfer` is one of its options when the goal is the reference's look rather than its content.

### FLUX Kontext (editing)

- Describe the edit, not the whole image. Name what changes and what must stay.

```
Change the outfit to a formal black evening dress while keeping the face, hair, and
pose exactly the same. Add subtle jewelry.
```

## Negative prompt starters

Only for models run with `cfg` above 1.0.

General (SDXL / SD 1.5):

```
(worst quality:1.4), (low quality:1.4), blurry, deformed, bad anatomy, bad hands,
extra fingers, missing fingers, extra limbs, fused fingers, text, watermark,
signature, jpeg artifacts
```

Photorealism:

```
3d render, cartoon, anime, illustration, painting, drawing, cgi, plastic skin,
airbrushed, doll, mannequin, oversaturated
```

Video:

```
static, frozen, jerky motion, low quality, blurry, distorted face, bad anatomy,
glitch, flickering, jittery, unnatural movement
```

## Process

1. Identify the model family from the loader node and checkpoint file.
2. Note any LoRA (and its trigger word), identity node, or Kontext edit in the graph.
3. Write the positive prompt in that family's style.
4. Write a negative prompt only if `cfg` is above 1.0.
5. Say which settings to change alongside the prompt (FLUX guidance, InstantID CFG) and where they live in the graph.
6. After a run, look at the output before iterating, and change one thing at a time.
