---
name: comfyui-api
description: Use when you need to call ComfyUI's HTTP API directly - the comfy MCP server is not connected, or you are writing a script or client (curl, Python, JS) that talks to a running ComfyUI. Covers queueing an API-format workflow with POST /prompt, polling /history, downloading results from /view, uploading input images, listing node schemas with /object_info, listing model files, and interrupting or freeing memory. Triggers include "ComfyUI REST API", "curl ComfyUI", "POST /prompt", "/history", "/object_info", "/upload/image", "call ComfyUI from a script", and "ComfyUI without MCP". For what goes inside the workflow JSON, use comfyui-workflow-json; for installing, starting, or checking a ComfyUI install, use comfyui-setup-and-verify.
---

Adapted from MCKRUZ/ComfyUI-Expert (MIT); see LICENSE.

# ComfyUI HTTP API

## When to use this instead of the MCP server

When the comfy MCP server is connected, use its tools: `server_info`, `run_workflow`, `job`, `fetch_outputs`, `upload_file`, `validate_workflow`, `nodes`, `search_models`, `system_stats`, `free_memory`. They wrap the same endpoints, add validation and spend gates, and need no URL handling.

Use the raw HTTP API below only when that server is not available, or when the deliverable is code that must talk to ComfyUI itself.

The workflow JSON you send is API format (node ids mapped to `class_type` and `inputs`). How to write or convert one is covered in comfyui-workflow-json. Getting a server running and confirming a result is correct is covered in comfyui-setup-and-verify.

## Base URL

ComfyUI listens on `http://127.0.0.1:8188` by default (`--listen` and `--port` change it). Every route below is also served with an `/api` prefix (`/api/prompt`, `/api/history/...`); both forms work.

ComfyUI has no authentication. Do not start it with `--listen` on a non-loopback address unless the user asks for that.

## Check the server

```bash
curl -s http://127.0.0.1:8188/system_stats
```

Returns `system` (including `os`, `ram_total`, `ram_free`, `comfyui_version`, `python_version`, `pytorch_version`, `argv`) and `devices`, a list with the primary device first. Each device has `name`, `type`, `index`, `vram_total`, `vram_free` (bytes). Connection refused means ComfyUI is not running.

## Discover nodes and models

```bash
curl -s http://127.0.0.1:8188/object_info                          # every installed node class
curl -s http://127.0.0.1:8188/object_info/CheckpointLoaderSimple   # one class
curl -s http://127.0.0.1:8188/models                               # model folder names
curl -s http://127.0.0.1:8188/models/checkpoints                   # files in one folder
```

`/object_info` is the source of truth for what this install can run: each class's `input` (with `required` / `optional`, and the allowed values for list inputs such as `ckpt_name`), `input_order`, and outputs. A `class_type` that is not a key here will fail with `missing_node_type`. `/object_info/{class}` returns `{}` for an unknown class. `/models/{folder}` returns 404 for an unknown folder name.

Use these before queueing: confirm every `class_type` exists and every file name you pass (checkpoint, LoRA, VAE) appears in the matching folder list.

## Queue a workflow

```bash
curl -s -X POST http://127.0.0.1:8188/prompt \
  -H "Content-Type: application/json" \
  -d @request.json
```

`request.json`:

```json
{
  "client_id": "my-script",
  "prompt": {
    "4": {"class_type": "CheckpointLoaderSimple",
          "inputs": {"ckpt_name": "your_checkpoint.safetensors"}},
    "6": {"class_type": "CLIPTextEncode",
          "inputs": {"text": "a lighthouse on a cliff at dusk", "clip": ["4", 1]}},
    "7": {"class_type": "CLIPTextEncode",
          "inputs": {"text": "blurry, low quality", "clip": ["4", 1]}},
    "5": {"class_type": "EmptyLatentImage",
          "inputs": {"width": 1024, "height": 1024, "batch_size": 1}},
    "3": {"class_type": "KSampler",
          "inputs": {"model": ["4", 0], "seed": 42, "steps": 20, "cfg": 8.0,
                     "sampler_name": "euler", "scheduler": "normal",
                     "positive": ["6", 0], "negative": ["7", 0],
                     "latent_image": ["5", 0], "denoise": 1.0}},
    "8": {"class_type": "VAEDecode",
          "inputs": {"samples": ["3", 0], "vae": ["4", 2]}},
    "9": {"class_type": "SaveImage",
          "inputs": {"images": ["8", 0], "filename_prefix": "ComfyUI"}}
  }
}
```

A link is `["<source node id>", <output index>]`. `CheckpointLoaderSimple` outputs `MODEL` (0), `CLIP` (1), `VAE` (2). Replace `ckpt_name` with a file from `/models/checkpoints`, and take `sampler_name` / `scheduler` values from `/object_info/KSampler`.

Other top-level fields: `prompt_id` (optional; must be a lowercase hyphenated UUID, otherwise the server mints one), `extra_data`, and `front: true` to jump the queue.

Success:

```json
{"prompt_id": "…", "number": 1, "node_errors": {}}
```

A workflow that fails validation returns HTTP 400 with `{"error": {"type", "message", "details", "extra_info"}, "node_errors": {…}}`. `node_errors` is keyed by node id and names the input that failed. Common `error.type` values: `missing_node_type` (class not installed), `prompt_no_outputs` (no output node such as `SaveImage`), `invalid_prompt_id`. Per-input failures in `node_errors` include `value_not_in_list` (for example a checkpoint file name the install does not have), `required_input_missing`, and `return_type_mismatch`.

## Wait for the result

```bash
curl -s http://127.0.0.1:8188/history/<prompt_id>
```

- `{}` means the prompt is still queued or running. Poll every few seconds.
- Once finished it returns `{"<prompt_id>": {"prompt": …, "outputs": {…}, "status": {"status_str", "completed", "messages"}}}`.
- `status.status_str` is `"success"` or `"error"`; `completed` is true only on success. On error, `status.messages` carries the `execution_error` event with the failing node and exception text. Hand that to comfyui-troubleshooter.

`GET /queue` returns `queue_running` and `queue_pending` if you need to know whether it has started.

Polling `/history` is the simplest client. For live progress, ComfyUI also serves a WebSocket at `/ws?clientId=<client_id>`; `script_examples/websockets_api_example.py` in the ComfyUI repository shows the pattern.

Large video models can run for many minutes. Tell the user before polling a long job rather than stopping early.

## Download outputs

Each entry under `outputs.<node id>` lists files like `{"filename": "ComfyUI_00001_.png", "subfolder": "", "type": "output"}`. Fetch each with those three values:

```bash
curl -s "http://127.0.0.1:8188/view?filename=ComfyUI_00001_.png&subfolder=&type=output" -o out.png
```

URL-encode the values. `type` is `output`, `input`, or `temp`.

## Upload an input image

```bash
curl -s -X POST http://127.0.0.1:8188/upload/image \
  -F "image=@reference.png" \
  -F "type=input" \
  -F "subfolder=" \
  -F "overwrite=false"
```

Form fields: `image` (the file, required), `type` (`input` default, `temp`, or `output`), `subfolder` (optional, relative to that directory), `overwrite` (`true` or `1` replaces a same-named file; otherwise a byte-identical file is reused and a different one is renamed `name (1).png`). The response is `{"name", "subfolder", "type"}`. Put `name` (prefixed with `subfolder/` when you used one) in a `LoadImage` node's `image` input. Always read `name` back from the response, because the server may have renamed the file.

`POST /upload/mask` takes the same fields plus `original_ref` (JSON naming the image the mask applies to).

## Stop work and free memory

```bash
curl -s -X POST http://127.0.0.1:8188/interrupt                       # stop whatever is running
curl -s -X POST http://127.0.0.1:8188/interrupt \
  -H "Content-Type: application/json" -d '{"prompt_id": "<id>"}'      # stop only if that prompt is running
curl -s -X POST http://127.0.0.1:8188/queue \
  -H "Content-Type: application/json" -d '{"delete": ["<id>"]}'       # remove pending prompts ({"clear": true} empties the queue)
curl -s -X POST http://127.0.0.1:8188/free \
  -H "Content-Type: application/json" -d '{"unload_models": true, "free_memory": true}'
```

`/free` sets flags the worker applies before its next job; it does not interrupt a running one.

## Errors

| Symptom | Meaning | Next step |
|---|---|---|
| Connection refused | ComfyUI is not running at that address | Start it (comfyui-setup-and-verify), or confirm `--listen` / `--port` |
| 400 from `/prompt` | Validation failed | Read `error.type` and `node_errors`; fix class names and values against `/object_info` |
| `/history` has `status_str: "error"` | A node raised during execution | Read `status.messages`, then comfyui-troubleshooter |
| `/history` stays `{}` for a long time | Still queued behind other work, or running a slow model | Check `/queue` before assuming it hung |
