# ComfyUI HTTP API: submit, poll, fetch

For when no MCP server is connected and comfy-cli is not available. Shapes below are from ComfyUI's `server.py` and `execution.py` and the server routes page on docs.comfy.org. The default address is `http://127.0.0.1:8188`; use the address the server printed at startup if it differs.

## Is it up?

```bash
curl -s http://127.0.0.1:8188/system_stats
```

Returns `system` (including `comfyui_version`, `required_frontend_version`, and `comfy_package_versions`, which lists each `comfy*` package's installed and required version) and a `devices` list with `vram_total` / `vram_free`. A refused connection means ComfyUI is not running there.

## Submit: `POST /prompt`

Body: `{"prompt": <API-format graph>}`. Optional keys: `client_id` (to match WebSocket messages to you), `prompt_id` (your own id; it must be a canonical lowercase hyphenated UUID, otherwise the request is rejected with `invalid_prompt_id`), `front: true` (put it at the front of the queue).

```bash
curl -s -X POST http://127.0.0.1:8188/prompt \
  -H 'Content-Type: application/json' \
  -d "{\"prompt\": $(cat workflow_api.json)}"
```

- **Accepted (HTTP 200):** `{"prompt_id": "...", "number": <queue position>, "node_errors": {...}}`. `node_errors` can be non-empty even on 200: an output whose branch failed validation is dropped and the rest are queued. Treat any entry there as a failure of that output.
- **Rejected (HTTP 400):** `{"error": {"type", "message", "details", "extra_info"}, "node_errors": {<node_id>: {"errors": [...], "dependent_outputs": [...], "class_type": "..."}}}`. See comfyui-workflow-json for the error types and how to fix them.

The graph must be API format. A UI-format save (the one with `nodes` and `links` arrays) is not accepted here.

## Wait: `GET /history/{prompt_id}`

```bash
curl -s http://127.0.0.1:8188/history/<prompt_id>
```

- `{}` means the job is not finished yet (still pending or running). It is not an error and not a success. Poll again after a few seconds.
- When finished: `{"<prompt_id>": {"prompt": [...], "outputs": {...}, "status": {...}}}`.
  - `status.status_str` is `"success"` or `"error"`; `status.completed` is a boolean.
  - `status.messages` is a list of `[event, data]` pairs. An `execution_error` entry carries `node_id`, `node_type`, `exception_type`, `exception_message`, and `traceback`. An `execution_interrupted` entry means it was cancelled.
  - `outputs` is keyed by output node id. An image output node gives `{"images": [{"filename", "subfolder", "type"}]}`.
  - `prompt` is the queued item; its third element is the exact graph that ran. Read the seed, steps, and model names from there for your report.

`GET /history` (all entries, with `max_items` and `offset` query parameters) also works.

## Queue: `GET /queue`

Returns `queue_running` and `queue_pending`. Each item is a list whose second element is the prompt id. If your id is in neither list and `/history/{id}` is still `{}`, something is wrong: check the server log.

- `POST /queue` with `{"delete": ["<prompt_id>"]}` removes pending items; `{"clear": true}` clears the pending queue.
- `POST /interrupt` stops the running job.
- `GET /prompt` returns the queue status (`exec_info.queue_remaining`).

## Fetch: `GET /view`

For each entry in `outputs[<node_id>].images`:

```bash
curl -s -o out.png "http://127.0.0.1:8188/view?filename=<filename>&subfolder=<subfolder>&type=<type>"
```

`type` defaults to `output`. URL-encode the values. Then open the file and look at it.

## Live progress: WebSocket `/ws`

Connect to `ws://127.0.0.1:8188/ws?clientId=<client_id>` and send that same `client_id` in the `/prompt` body. JSON messages include `status`, `execution_start`, `execution_cached`, `executing`, `progress`, `executed`, `execution_error`, and `execution_success`. An `executing` message whose `data.node` is `null` and whose `data.prompt_id` is yours means the job finished; then read `/history/{prompt_id}` for the result and the status. Binary frames are preview images.

## Node definitions: `GET /object_info/{class}`

Used when writing a graph; see comfyui-workflow-json. An unknown class returns `{}`.
