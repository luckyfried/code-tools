---
name: comfyui-setup-and-verify
description: Use to install, launch, and connect ComfyUI to an agent (local ComfyUI through comfy-cli and the comfy-mcp stdio server, or the hosted Comfy Cloud MCP), and to prove a generation actually finished before reporting done - submit, get the prompt id, poll to completion, check for execution errors, fetch the output, look at it, and report what ran. Use when the user says "set up ComfyUI", "install comfy", "connect comfy", "comfy mcp", "launch ComfyUI", "generate an image", "run this workflow", "did it render", "where is my image", "check the queue", "queue", or when ComfyUI will not start or the agent cannot connect to it. For writing or fixing workflow JSON itself, use comfyui-workflow-json; for diagnosing a run that failed or looks wrong, use comfyui-troubleshooter if it is installed.
---

# ComfyUI setup and verify

The loop is: confirm the server is up, submit, get the prompt id, poll until the job is finished, check it for errors, fetch the output, look at it, report. A prompt id means the job was queued. It says nothing about whether anything was generated.

## The rule

You are not done with a generation until:

1. The job has a terminal status, not just a prompt id.
2. That status is success, and there is no execution error on it.
3. You have fetched the output file to a path you can name.
4. You have opened the image (or a frame of the video) and it shows what was asked for.

Then report what ran (workflow or template), the model, the seed, the output path, and what the picture shows. If you could not check something, say so plainly. Never report "done", "generated", or "should be ready" from a queued id.

## 0. Check which tools you actually have

Look at your tool list before planning. Two different MCP servers exist, and running both is normal:

- **comfy-mcp** (local, stdio; github.com/Comfy-Org/comfy-mcp): drives the ComfyUI on this machine through the `comfy` command. Tools include `server_info`, `run_workflow`, `job`, `fetch_outputs`, `nodes`, `validate_workflow`, `launch_comfyui`.
- **Comfy Cloud MCP** (remote HTTP at `https://cloud.comfy.org/mcp`): runs on Comfy Cloud GPUs. Tools include `submit_workflow`, `get_job_status`, `wait_for_job`, `get_output`, `search_nodes`, `get_node`.

The names above are from each server's own README or docs page. Call only tools you can see; if a name differs in your list, use yours. Some pages still show older local names (`job_status`, `wait_for_job`, `search_nodes`, `get_node`); the current comfy-mcp groups those into `job(action=...)` and `nodes(action=...)`.

If neither is connected, use comfy-cli directly (section 3b) or the raw HTTP API ([references/http-api.md](references/http-api.md)).

## 1. Local setup

Needs Python 3.10 or newer. comfy-mcp requires comfy-cli 1.14.0 or newer and refuses to run against an older one. Installing comfy-mcp does not install comfy-cli, so install both:

```bash
pip install comfy-mcp "comfy-cli>=1.14.0"
comfy install        # creates a ComfyUI workspace (~/comfy unless --workspace/--here/--recent is given)
```

`comfy install` also installs ComfyUI-Manager unless you pass `--skip-manager`. Use an existing checkout instead with `comfy set-default <path>`. On macOS, keep ComfyUI out of `~/Documents`, `~/Desktop` and `~/Downloads`; macOS blocks the processes an MCP client launches from reading those folders.

Launch ComfyUI and leave it running. Nothing starts it implicitly.

```bash
comfy launch --background                      # detached; stop it with: comfy stop
comfy launch --background -- --port 8189       # anything after -- goes to ComfyUI itself
comfy env                                      # shows whether the server is running and where
```

Or, from an agent, call `launch_comfyui`. Never add `--listen` on a non-loopback address or `--enable-cors-header` without asking the user: ComfyUI has no authentication, so that publishes its whole API to the network. comfy-mcp asks the user itself before starting with those.

Register comfy-mcp as a stdio server. The command is `comfy-mcp`. MCP clients start servers with their own environment, which often lacks your shell's `PATH`, so if `comfy` lives in a virtualenv set `COMFY_BIN` to its absolute path. Claude Code:

```bash
claude mcp add comfy-mcp -e COMFY_BIN=/path/to/venv/bin/comfy -- comfy-mcp
```

Or a project `.mcp.json` (Cursor uses the same shape in `.cursor/mcp.json`):

```json
{ "mcpServers": { "comfy-mcp": { "command": "comfy-mcp", "env": { "COMFY_BIN": "/path/to/venv/bin/comfy" } } } }
```

Drop `COMFY_BIN` if `comfy` is already on the client's `PATH`. If ComfyUI on this machine is not on `127.0.0.1:8188`, add `"COMFY_LOCAL_URL": "http://127.0.0.1:8189"` to that `env` block (comfy-cli reads it). `COMFYUI_URL` is a different variable, for a ComfyUI on another machine; set one, not both. Restart the client after any change so the tools load.

`comfy-mcp --version` confirms the install. Do not run bare `comfy-mcp` in a terminal to test it: it is a stdio server and just waits.

## 2. Cloud setup

Comfy Cloud MCP needs a Comfy Cloud account. Searching templates, models, and nodes is free; running a generation needs an active Comfy Cloud subscription (credits alone are not enough).

- **Claude Code:** `claude mcp add --transport http comfy-cloud https://cloud.comfy.org/mcp`, then run `/mcp`, select **comfy-cloud**, choose **Authenticate**, and finish the OAuth sign-in in the browser. Or install the plugin: `/plugin marketplace add Comfy-Org/comfy-skills` then `/plugin install comfy-cloud@comfy-skills`.
- **Clients without MCP OAuth (Cursor today, headless, CI):** a Comfy Cloud API key (created at platform.comfy.org/profile/api-keys) sent as an `X-API-Key` header, read from the environment:

  ```json
  { "mcpServers": { "comfy-cloud": { "url": "https://cloud.comfy.org/mcp", "headers": { "X-API-Key": "${env:COMFY_API_KEY}" } } } }
  ```

**API keys never go into the chat or into a file.** Do not ask the user to paste a key to you, do not echo one, and do not write one into a config that could be committed. Point the config at an environment variable and let the user set that variable themselves. The same applies to `COMFY_API_KEY` for comfy-mcp, which is only needed for partner-API nodes.

## 3. Check the connection before relying on it

1. The client shows the server as connected (in Claude Code, `/mcp` or `claude mcp list`). A server that failed to start has no tools, even if it is configured.
2. **Local:** call `server_info` first. It reports whether ComfyUI is running, its address, the workspace, the comfy-cli version, a `hardware` block, and a `freshness` block for stale installs. If it says ComfyUI is not running, launch it; do not submit.
3. **Cloud:** call `get_server_info` to confirm the server and auth state, and `get_billing_status` before a first paid run.
4. Read the `hardware` block before the first local generation. comfy-mcp's own guidance: with less than 8 GB of VRAM, or Apple Silicon with under 32 GB of unified memory, do not run local diffusion; offer Comfy Cloud or partner models instead. A missing VRAM figure means unknown; ask the user rather than assume there is no GPU.

## 4. The verify loop

### 4a. With comfy-mcp

1. Validate first: `validate_workflow(workflow_path)`. Read the `valid` field; a call that returned is not a pass.
2. Submit: `run_workflow(workflow_path, wait=False)` returns a `prompt_id`. (`wait=True` blocks up to `timeout_seconds`; an expired wait returns `timed_out: true` with the id, and the job keeps running.) `run_workflow` accepts an API-format file or a UI export.
3. Poll: `job(action="wait", prompt_id=...)` until the status is terminal. It is bounded; on `timed_out: true`, call it again. `job(action="status", ...)` is a one-shot check; `job(action="queue")` lists jobs.
4. Check for errors: `job(action="error", prompt_id=...)`. `error: None` means healthy; otherwise it names the failing node, `exception_type`, `exception_message`, and a traceback tail.
5. Fetch: `fetch_outputs(prompt_id, out_dir)` copies the outputs to `out_dir`; `inline_images=True` also returns images as inline content you can see.
6. Look at the file (section 5).

`generate_image(prompt)` and `run_template(name, params)` are one-call shortcuts that return the same `prompt_id` shape. Verify them the same way.

Workflows or templates with partner-API (paid) nodes spend Comfy credits. They fail closed unless `confirm_spend=True`, and you may pass that only after the user has agreed to spend.

### 4b. With comfy-cli only

```bash
comfy run --workflow wf.json            # submits, prints a prompt_id, returns
comfy jobs status <prompt_id>           # one-shot state
comfy jobs watch <prompt_id>            # live progress until it finishes
comfy download <prompt_id> -o ./outputs # save the outputs
```

`comfy run --wait` blocks inline instead. `comfy validate --workflow wf.json` pre-flights against the running server.

### 4c. With Comfy Cloud MCP

`submit_workflow` (API format) or `run_template` → `wait_for_job` (or `get_job_status`) → `get_output`. `get_output` does not write to your machine; it returns a short-lived signed URL and a ready-made download command. Run that command exactly as given: editing the URL breaks its signature. If you cannot run shell commands, give the command to the user.

### 4d. With the raw HTTP API

`POST /prompt` → `GET /history/{prompt_id}` until it is non-empty → check `status.status_str` → `GET /view` for each output file. Exact shapes are in [references/http-api.md](references/http-api.md).

## 5. Look at the output

- **Image:** open the saved file with your image-reading tool and describe what you see. Wrong or not done if: it is black, flat grey, pure noise, or a single colour; the subject is missing; it is a different size than requested; or it is the same image as the previous run when you changed the seed.
- **Video:** if `ffmpeg` is installed, extract a frame and look at it: `ffmpeg -ss 1 -i out.mp4 -frames:v 1 frame.png`. Check at least two moments if motion matters. Without ffmpeg, say you could not view the video and give the path.
- **Several outputs:** check each output node you expected; one image from one output node proves nothing about another.

## 6. Report

- What ran: the workflow file or template name, and local or cloud.
- Model: the checkpoint or model file names from the graph (for example the loader's `ckpt_name`).
- Seed, steps, sampler: read from the graph you actually submitted, not from memory.
- The prompt id and final status.
- Output path(s), and what the image or frame shows.
- Anything you could not check, and why.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `Value not in list: ckpt_name: '...' not in [...]` (or any loader input) | The model file is not installed where ComfyUI looks. Models go under the workspace's `models/` folder by type: `models/checkpoints`, `models/vae`, `models/loras`, `models/controlnet`, `models/embeddings`. Download with `download_model(url, relative_path="models/checkpoints")` then `download(action="wait", download_id=...)`, or `comfy model download --url <URL> --relative-path models/checkpoints`. `search_models` lists what is on disk. If you copied files in by hand while ComfyUI was running, restart it so the lists update. `extra_model_paths.yaml` in the ComfyUI root adds other model folders. |
| `missing_node_type` / "Node '...' not found. The custom node may not be installed." | A custom node pack is missing. Local MCP: `workflow_deps(workflow_path)` names the packs (needs ComfyUI-Manager), `install_node([...])` installs registry packs (the user confirms each install, since it runs third-party code), then `restart_comfyui`, then `nodes(action="search", query=...)` to confirm the class exists. CLI: `comfy node install <registry-id>`, then restart ComfyUI. New nodes are invisible until ComfyUI restarts. |
| Out of memory, very slow, or the machine freezes | Lower the resolution or batch size first. `free_memory()` (or `comfy free`) unloads models from VRAM; `system_stats()` (or `comfy system-stats`) shows free VRAM. ComfyUI launch flags, passed after `--` (for example `comfy launch --background -- --lowvram`): `--lowvram` (runs text encoders on the CPU; no effect when dynamic VRAM is enabled), `--novram` (when lowvram is not enough), `--reserve-vram <GB>`, `--disable-smart-memory`, and `--cpu` as a very slow last resort. Or run it on Comfy Cloud. |
| Connection refused, or tools report nothing running | ComfyUI is not running, or it is on another port. Check `server_info` / `comfy env` for the address it reports. The default is `127.0.0.1:8188`; a server on another port on this machine needs `COMFY_LOCAL_URL` in the MCP `env` block, and a client restart. If `server_info` still shows `:8188`, the variable did not reach comfy-cli (wrong `env` block, no restart) or is malformed (only `http://` is accepted). |
| Startup log: `Installed comfyui-frontend-package version X is lower than the recommended version Y`, or the UI misbehaves after an update | The frontend ships as a pip package and is updated separately from ComfyUI's code. Reinstall ComfyUI's `requirements.txt` in ComfyUI's own Python environment (the warning prints the exact command), or run `comfy update comfy`, which reinstalls it. Then restart. `get_logs()` or `comfy logs` shows the startup log of a background server. `GET /system_stats` lists installed against required versions under `system.comfy_package_versions`. |
| `PermissionError: [Errno 1] Operation not permitted` naming a file under `~/Documents`, `~/Desktop` or `~/Downloads` (macOS) | macOS privacy protection. Move the ComfyUI folder elsewhere and re-point with `comfy set-default <path>` (and update `COMFY_BIN`), or grant the MCP client Full Disk Access and reopen it. |
| Every tool fails with "`comfy` not found on PATH" | comfy-cli is not installed, or the client cannot see it. Install it, or set `COMFY_BIN` to its absolute path. |
| Cloud run refused although credits remain | Cloud generation needs an active subscription; credits alone do not grant it. Check `get_billing_status`. |
| `spend_consent_required` | The graph or template uses paid partner nodes. Ask the user; pass `confirm_spend=True` only after they agree. |
