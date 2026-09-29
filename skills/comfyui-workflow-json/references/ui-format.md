# The UI / workflow format

This is what the ComfyUI frontend saves and loads. The schema is published on docs.comfy.org under "Workflow JSON" (version 1.0, with the older 0.4 kept for reference). The server's `POST /prompt` does not accept it; export API format instead (see the main skill).

## Top level

| Field | Version 1.0 | Version 0.4 |
|---|---|---|
| `version` | `1` (required) | a number (required) |
| Counters | `state`: `lastNodeId`, `lastLinkId`, `lastGroupid`, `lastRerouteId` (required) | `last_node_id`, `last_link_id` (required) |
| `nodes` | array (required) | array (required) |
| `links` | array of objects | array of 6-item arrays (required) |
| Also | `groups`, `config`, `extra`, `models`, `reroutes` | `groups`, `config`, `extra`, `models` |

## A node

Required: `id`, `type`, `pos`, `size`, `flags`, `order`, `mode`, `properties`. Optional: `inputs`, `outputs`, `widgets_values`, `color`, `bgcolor`.

- `type` is the node class name, the same string as `class_type` in API format.
- `inputs` lists the node's input sockets; each has a `link` (a link id, or null).
- `outputs` lists output sockets in output-index order; each has `links` (the link ids leaving it) and `slot_index`.
- `widgets_values` holds widget values by position, in the order the widgets appear on the node. It is not keyed by name. A seed widget is followed by an extra entry for its control-after-generate setting ("fixed", "increment", "decrement", "randomize"), so later values sit one position further along than the input list suggests.

## A link

Version 0.4 stores each link as `[link_id, origin_id, origin_slot, target_id, target_slot, type]`. Version 1.0 stores the same fields as an object: `{"id", "origin_id", "origin_slot", "target_id", "target_slot", "type"}`.

Example from the frontend's default graph: `[1, 4, 0, 3, 0, "MODEL"]` is link 1, from node 4's output 0 (the checkpoint loader's `MODEL`) to node 3's input 0 (the sampler's `model`). In API format that same connection is written on node 3 as `"model": ["4", 0]`.

## Why not convert it by hand

- `widgets_values` is positional and includes UI-only entries such as the seed control, so mapping values to input names needs the node definition and knowledge of which inputs are widgets.
- Nodes with `mode` set to muted or bypassed, reroutes, group nodes, subgraphs, and note nodes all need special handling that the frontend does on export.

Use the frontend's **Export (API)**, or a tool that converts for you (comfy-cli's `comfy run` and comfy-mcp's `run_workflow` accept a UI export directly). Hand-edit a UI-format file only to change values the user will keep editing in the frontend, and look the node up first so you change the right position.
