---
name: comfyui-workflow-json
description: Use when reading, writing, editing, or fixing a ComfyUI workflow JSON file - telling the UI/workflow format (nodes, links, widgets_values) from the API/prompt format (node id to class_type and inputs), getting the API format the server accepts, looking up real node definitions before writing any node, wiring links, setting seeds and widget values, and validating a graph before submitting it. Use when the user says "workflow json", "API format", "export API", "class_type", "node not found", "missing_node_type", "build a workflow", "write a ComfyUI graph", "prompt outputs failed validation", "Value not in list", or pastes ComfyUI JSON. To run the graph and check the result, use comfyui-setup-and-verify.
---

# ComfyUI workflow JSON

The loop is: find out which format you have, get the API format, look up every node you use in the running install, write or edit the graph, validate it, then hand it to comfyui-setup-and-verify to run and check. A graph written from memory is a guess: class names, input names, output order, and allowed values all come from the install you are targeting.

## The rule

- Never invent a `class_type`, an input name, an output index, or a combo value (model file, sampler, scheduler). Look each one up (section 3).
- A custom node class only exists if its pack is installed and ComfyUI has been restarted since.
- Validate before you call a graph finished (section 7). Submitting is not validating, and a queued prompt id is not a result.

## 1. Which format is this?

| | UI / workflow format | API / prompt format |
|---|---|---|
| What saves it | The frontend's normal save | The frontend's **Export (API)** item |
| Top level | An object with a `nodes` array and a `links` array (plus `version`, `last_node_id`/`state`, `groups`, `extra`) | An object whose keys are node ids (`"3"`, `"4"`, ...) |
| A node | `{"id": 3, "type": "KSampler", "inputs": [...], "outputs": [...], "widgets_values": [...], "pos": ..., ...}` | `{"class_type": "KSampler", "inputs": {"seed": 5, "model": ["4", 0], ...}, "_meta": {"title": "..."}}` |
| Values | Positional, in `widgets_values` | Named, in `inputs` |
| Links | Listed separately in `links` | Inline: an input value of `["<source node id>", <output index>]` |
| Layout, colours, groups, notes | Kept | Dropped |

Quick test: a top-level `nodes` array means UI format; every top-level value having `class_type` means API format.

Details of the UI format are in [references/ui-format.md](references/ui-format.md). Edit UI-format files only when the user wants to keep editing them in the frontend.

## 2. Which one does each path accept?

- **`POST /prompt`** on a ComfyUI server: API format only, wrapped as `{"prompt": <graph>}`.
- **comfy-mcp `run_workflow` and `comfy run --workflow`**: an API-format file, or a UI export (comfy-cli converts it).
- **Comfy Cloud MCP `submit_workflow`**: API format.
- **comfy-mcp `list_workflow_slots`, `list_workflow_notes`**: UI format only.

Getting the API format:

1. In the ComfyUI frontend, open the workflow and use the workflow menu's **Export (API)** item. The command palette calls it "Export Workflow (API Format)" and docs.comfy.org shows it as File → Export Workflow (API); the label varies a little across frontend versions.
2. To convert a UI-format file, load it in the frontend and export it the same way.
3. From a template: comfy-mcp `fetch_template(name, out_path)` or `comfy templates fetch <name> -o wf.json` writes a runnable workflow, and `run_workflow` accepts it.

## 3. Look up every node before writing it

Use whichever of these you have. All of them read the live install, so custom nodes appear only if they are installed.

- **comfy-mcp:** `nodes(action="search", query="...")` to find a class name by keyword; `nodes(action="get", name="KSampler")` for its full input and output schema. `nodes(action="upstream"|"downstream", name=...)` and `nodes(action="path", from_type="MODEL", to_type="IMAGE")` find nodes that can connect.
- **Comfy Cloud MCP:** `search_nodes`, then `get_node` for the full input spec.
- **HTTP:** `GET /object_info/<ClassName>` (`GET /object_info` returns every class). It returns `{}` when the class does not exist in this install.

Reading an `/object_info` entry:

- `input.required` and `input.optional` map each input name to `[type, options]`. `input.hidden` inputs are filled by the server; never set them.
- `type` is a string such as `"MODEL"`, `"CLIP"`, `"LATENT"`, `"CONDITIONING"`, `"IMAGE"`, `"INT"`, `"FLOAT"`, `"STRING"`, `"BOOLEAN"`. For a dropdown (combo) it is either the list of allowed values itself, or `"COMBO"` with the list under `options.options`.
- `options` carries `default`, `min`, `max`, `step`, and for a seed `control_after_generate: true`.
- `input_order` gives the order inputs appear in the UI.
- `output` is the list of output types; the output index you link from is the position in this list. `output_name` gives their names.
- `output_node: true` marks a node that produces a result (such as `SaveImage`). A graph needs at least one.

## 4. Inputs and links

- Node ids are strings and must be unique. Any id works; the frontend uses numbers.
- Every `required` input must be present, either as a value or as a link.
- A link is exactly `["<node id>", <output index>]`: a two-item list, id as a string, index as an integer. The output's type must match the input's type.
- Inputs of type `MODEL`, `CLIP`, `VAE`, `CONDITIONING`, `LATENT`, `IMAGE` and the like can only be links. `INT`, `FLOAT`, `STRING`, `BOOLEAN`, and combo inputs take a literal value (they can also be fed by a link of the same type).
- Combo values must match one of the allowed values exactly, including file extensions and subfolder prefixes on model names. Take model names from the loader's own list, not from a download page.
- Numbers must be within `min` and `max`.
- No cycles.

## 5. Seeds and widget values

- In API format the seed is a plain integer in `inputs.seed` (on `KSampler`, 0 to 2^64 - 1). The server uses exactly that value; it never changes it.
- `control_after_generate` ("fixed", "increment", "decrement", "randomize") is a frontend behaviour: the UI changes the seed widget after it queues a run. It does not exist in API format. To get a new image through the API, send a different seed yourself; to reproduce one, send the same seed with the same graph and the same model files.
- In UI format the control setting is stored in `widgets_values` as an extra entry right after the seed, so positions there do not line up one-to-one with input names. One more reason not to hand-convert UI format to API format.
- Record the seed you submitted; the report in comfyui-setup-and-verify needs it.

## 6. A minimal text-to-image graph (API format)

Core nodes from ComfyUI's `nodes.py`: `CheckpointLoaderSimple` (outputs 0 `MODEL`, 1 `CLIP`, 2 `VAE`), `CLIPTextEncode` (inputs `text`, `clip`; output 0 `CONDITIONING`), `EmptyLatentImage` (`width`, `height`, `batch_size`; output 0 `LATENT`), `KSampler` (`model`, `seed`, `steps`, `cfg`, `sampler_name`, `scheduler`, `positive`, `negative`, `latent_image`, `denoise`; output 0 `LATENT`), `VAEDecode` (`samples`, `vae`; output 0 `IMAGE`), `SaveImage` (`images`, `filename_prefix`; an output node).

```json
{
  "4": { "class_type": "CheckpointLoaderSimple",
         "inputs": { "ckpt_name": "v1-5-pruned-emaonly-fp16.safetensors" } },
  "6": { "class_type": "CLIPTextEncode",
         "inputs": { "text": "a glass bottle on a beach at sunset", "clip": ["4", 1] } },
  "7": { "class_type": "CLIPTextEncode",
         "inputs": { "text": "text, watermark", "clip": ["4", 1] } },
  "5": { "class_type": "EmptyLatentImage",
         "inputs": { "width": 512, "height": 512, "batch_size": 1 } },
  "3": { "class_type": "KSampler",
         "inputs": { "model": ["4", 0], "positive": ["6", 0], "negative": ["7", 0],
                     "latent_image": ["5", 0], "seed": 156680208700286, "steps": 20,
                     "cfg": 8, "sampler_name": "euler", "scheduler": "normal", "denoise": 1 } },
  "8": { "class_type": "VAEDecode",
         "inputs": { "samples": ["3", 0], "vae": ["4", 2] } },
  "9": { "class_type": "SaveImage",
         "inputs": { "images": ["8", 0], "filename_prefix": "ComfyUI" } }
}
```

Before using it, replace `ckpt_name` with a file from `nodes(action="get", name="CheckpointLoaderSimple")` or `GET /object_info/CheckpointLoaderSimple` on the target install, and confirm `euler` and `normal` are in `KSampler`'s `sampler_name` and `scheduler` lists. This graph suits SD1.5-family checkpoints; other model families need other loaders and text encoders, so start those from a template rather than from this graph.

## 7. Validate before submitting

1. **comfy-mcp:** `validate_workflow(workflow_path)`. Read `valid`; each error names `node_id`, `field`, a `code`, and often `suggestions` or `valid_options` from your install. `valid: false` is a normal return, not an exception; an exception means no verdict (usually ComfyUI is not running). CLI equivalent: `comfy validate --workflow wf.json`.
2. **Missing packs:** `workflow_deps(workflow_path)` lists the node packs a workflow needs and which are not installed (needs ComfyUI-Manager). Installing them is covered in comfyui-setup-and-verify.
3. **The server's own check:** `POST /prompt` validates before queueing. A rejected graph returns HTTP 400:

   ```json
   {"error": {"type": "...", "message": "...", "details": "...", "extra_info": {}},
    "node_errors": {"<node id>": {"errors": [{"type": "...", "message": "...", "details": "...", "extra_info": {}}],
                                  "dependent_outputs": ["..."], "class_type": "..."}}}
   ```

   An accepted graph returns HTTP 200 with `prompt_id`, `number`, and `node_errors`; a non-empty `node_errors` there means some outputs were dropped. That submission also queues the job, so only use it as a check when you mean to run the graph.

| Error `type` | Meaning and fix |
|---|---|
| `missing_node_type` | A `class_type` is not installed, or a node has no `class_type` (a UI-format file sent as API format, or a broken export). Check the spelling with a node search; install the pack; restart ComfyUI. |
| `prompt_no_outputs` | No output node in the graph. Add one such as `SaveImage`. |
| `prompt_outputs_failed_validation` | Top-level summary; the causes are in `node_errors`. |
| `required_input_missing` | A required input is absent. Add it from `input.required`. |
| `bad_linked_input` | A link is not a two-item `[node id, index]` list. |
| `return_type_mismatch` | The linked output's type is not the input's type. Check the output index against `output`. |
| `value_not_in_list` | A combo value is not allowed here: most often a model file that is not installed, or a misspelled sampler or scheduler. Use a listed value, or install the model. |
| `value_smaller_than_min` / `value_bigger_than_max` | A number is out of range. |
| `invalid_input_type` | A value could not be converted to the input's type (for example a string for an `INT`). |
| `custom_validation_failed`, `exception_during_validation`, `exception_during_inner_validation` | The node's own check failed; read `details`. |
| `dependency_cycle` | The graph loops. |
| `invalid_prompt_id` | A `prompt_id` you supplied is not a canonical lowercase UUID. Omit it and let the server assign one. |

A graph that passes validation can still fail while running (for example out of memory, or a model from the wrong family). Running it and checking the output is comfyui-setup-and-verify's job.
