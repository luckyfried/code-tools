---
name: comfyui-troubleshooter
description: Use to diagnose why a ComfyUI run went wrong after the quick checks have not explained it - out-of-memory that freeing memory did not fix, generation far slower than the hardware should allow, a queue that will not move, a node pack that broke after an update, or output that runs fine but looks wrong (burned or overcooked faces, blurry, black, washed out, oversaturated, ignores the prompt, wrong identity, watermarks). Reads the error, logs, launch flags, and hardware through the comfy MCP server tools where connected, and gives the fix. Triggers include "why does this look bad", "faces look burned", "black image", "output is blurry", "ignores my prompt", "still out of memory", "ComfyUI is slow", "queue stuck", "broke after update", and "which launch flags". For install, launch, and the run-and-check loop, use comfyui-setup-and-verify; for fixing the workflow JSON itself, use comfyui-workflow-json; for rewriting prompt text, use comfyui-prompt-engineer.
---

Adapted from MCKRUZ/ComfyUI-Expert (MIT); see LICENSE.

# ComfyUI troubleshooter

## 1. Classify

| Category | Symptoms | First check |
|---|---|---|
| Server | Connection refused, timeouts, crash mid-run | `server_info` (is it running, where) and `get_logs` |
| Workflow | Rejected before running: missing node, bad value, bad link | `validate_workflow` on the workflow file |
| Execution | Accepted, then a node raised | `job(action="error", prompt_id=…)` |
| Performance | Out of memory, very slow | `system_stats` (VRAM free and total), then launch flags |
| Quality | Runs fine, output looks wrong | The settings and prompt (below) |

Without the MCP server, the same facts come from the HTTP API: `GET /system_stats`, the 400 body from `POST /prompt`, and `status.messages` in `GET /history/<prompt_id>` (see comfyui-api).

## 2. Gather before diagnosing

1. The exact error text, with the failing node id and class.
2. The workflow JSON, or at least the loader, sampler, and output nodes.
3. The model files it loads (checkpoint, diffusion model, LoRA, VAE, ControlNet).
4. The settings: `cfg`, steps, sampler, scheduler, resolution, batch size.
5. The machine: `server_info`'s `hardware` block and `system_stats`'s per-device `vram_total` / `vram_free`. Include `system.argv` from `system_stats` to see which launch flags are active.
6. What is installed: `nodes` for node classes, `search_models` for model files, and `server_info`'s `freshness` block for an outdated ComfyUI or node pack.

## 3. Common errors

**`Node '<name>' not found. The custom node may not be installed.`** (`missing_node_type`)
The class is not in this install. Run `workflow_deps` on the workflow to map classes to node packs. Install the `not-installed` packs with `install_node` (it takes registry pack ids, not class names, and asks the user first), then restart ComfyUI with `restart_comfyui`. A class under `unknown_nodes` belongs to no known pack; check the class name for a typo against `nodes(action="search", query=…)`.

**`Value not in list`** (`value_not_in_list` in `node_errors`)
Usually a model file name the install does not have, or a sampler/scheduler name it does not know. Run `search_models` (with `folder`, such as `checkpoints` or `loras`) and use the exact file name it lists, including any subfolder prefix. If the model is genuinely missing, get a direct download URL from its model page and fetch it with `download_model` into the right folder. For enum inputs, read the allowed values with `nodes(action="get", name=<class>)`.

**`required_input_missing` / `return_type_mismatch`**
A link is missing or connects the wrong output type. Check the input names and output indexes against `nodes(action="get", …)`. The workflow format is covered in comfyui-workflow-json.

**Out of memory** (ComfyUI's message: "This error means you ran out of memory on your GPU")
In order:
1. Check batch size and resolution first; ComfyUI's own tip is an accidentally large batch.
2. `free_memory`, then run again.
3. Swap `VAEDecode` for `VAEDecodeTiled` when the failure happens at decode.
4. Relaunch with a lower-memory flag through `restart_comfyui(extra_args=[…])`:
   - `--fp8_e4m3fn-unet` stores diffusion model weights in fp8.
   - `--reserve-vram <GB>` keeps VRAM free for other software.
   - `--novram` offloads harder; `--cpu` runs everything on the CPU (very slow).
   - `--lowvram` does nothing while ComfyUI's dynamic VRAM is on. Only with dynamic VRAM off does it move the text encoders to the CPU.
5. If it still does not fit, use a smaller or quantized variant of the model (`search_templates` / `search_models`).

**Black images**
Often the VAE in fp16. Relaunch with `--fp32-vae`.

**Queue stuck, or a run will not stop**
`job(action="cancel", prompt_id=…)` or `POST /interrupt`, then `free_memory`. If ComfyUI no longer responds, `restart_comfyui` and read `get_logs` for the cause.

**Very slow generation**
- Look at `system.argv`: `--lowvram`, `--novram`, `--cpu`, or `--disable-smart-memory` left on from an earlier fix will slow a machine that has the memory. `--highvram` keeps models on the GPU between runs instead of unloading them.
- `--use-sage-attention` is available but needs the `sageattention` Python package installed; ComfyUI logs an error naming the package if it is missing.
- Confirm from `system_stats` that the device is the GPU, not `cpu`.

**Crashes after an update, or a node pack stops working**
Check `server_info`'s `freshness` block and update with `update_comfyui`. A pack that needs a newer ComfyUI fails at import; `get_logs` shows it at startup.

## 4. Quality issues

```
OUTPUT LOOKS WRONG
|-- Faces
|   |-- Burned / overcooked (InstantID) -> lower cfg to about 4-5 or add RescaleCFG; lower the InstantID weight
|   |-- Wrong identity -> clearer, front-facing reference; for InstantID confirm the antelopev2 InsightFace models are installed
|   |-- Deformed -> add anatomy terms to the negative (only acts when cfg > 1.0)
|   |-- Different every run -> fix the seed; use a character LoRA for consistency
|-- Colors
|   |-- Oversaturated -> lower cfg (or FLUX guidance)
|   |-- Washed out -> confirm the right VAE is loaded for the model
|   |-- Black -> --fp32-vae
|-- Sharpness
|   |-- Blurry -> resolution that matches the model's native size; more steps
|   |-- Pixelated after enlarging -> UpscaleModelLoader + ImageUpscaleWithModel instead of a plain resize
|-- Composition
|   |-- Ignores the prompt -> for classic models raise cfg slightly; for FLUX [dev] raise FluxGuidance, not cfg; simplify the prompt
|   |-- Extra limbs or objects -> negative prompt (cfg > 1.0), or ControlNet for structure
|   |-- Watermarks with InstantID at 1024x1024 -> use a slightly off size such as 1016x1016
```

Prompt rewrites belong to comfyui-prompt-engineer.

## 5. After the fix

Rerun, then check the output itself (open the image, not only the job status) the way comfyui-setup-and-verify describes. Change one thing at a time so the fix is known.

## 6. Escalation

1. Search the ComfyUI GitHub issues for the exact error text.
2. Search the issues of the custom node pack that owns the failing class (`workflow_deps` names it).
3. Ask the user to share the error, the workflow, and `get_logs` output in the ComfyUI community channels.
