---
name: threejs-visual-check
description: Use after any change to a Three.js or React Three Fiber (R3F) web app - a scene, shader, material, lighting, camera, model or texture loading, animation, or renderer/WebGPU setup - to prove in a real browser that it renders before reporting done. Starts the dev server, opens the page with the Chrome DevTools MCP server, checks the console, takes and inspects a screenshot, and reads the scene back with threejs-devtools-mcp when it is connected. Also use when the user says "check it renders", "is it working", "does it show up", "take a screenshot", "blank canvas", "black screen", or "my model is invisible".
---

# Three.js visual check

The loop is: start the dev server, open the page in a real browser, check the console, look at a screenshot, read the scene back, check more than one frame if anything moves, report. A build or type check passing says nothing about what is on the canvas.

## The rule

After a change to a Three.js or R3F app, you are not done until:

1. The page loads from the running dev server.
2. The console has no new errors and no WebGL/WebGPU warnings.
3. You have taken a screenshot and looked at it, and it shows what the change was meant to show.
4. If threejs-devtools-mcp is connected, the scene read-back matches what you expect (the objects exist, are visible, and the counts make sense).
5. For animated or interactive changes, you have checked more than one moment in time.

Then report exactly what you checked and what each check showed. If you could not check something (no browser tools, server would not start), say so plainly. Never report "done" or "should render" on a change you have not seen render.

## 0. Check which tools you actually have

Look at your tool list before planning. MCP tools are usually listed with the server name in front (in Claude Code, for example, `mcp__chrome-devtools__take_screenshot`). Note which of these are connected:

- **Chrome DevTools MCP** (`chrome-devtools-mcp` on npm, github.com/ChromeDevTools/chrome-devtools-mcp): drives a real Chrome. Needed for steps 2 and 4.
- **threejs-devtools-mcp** (npm, github.com/DmitriyGolub/threejs-devtools-mcp): reads the live Three.js scene. Needed for step 3.

Do not call a tool you cannot see. If neither is connected, go to "Fallback" below. If Chrome DevTools MCP runs in `--slim` mode it only has `navigate`, `evaluate` and `screenshot`; use those in place of the full tools named below.

## 1. Start the dev server

Read `package.json` `scripts`. Use the script the project uses for development, usually `dev` (Vite: `vite`), sometimes `start` or `serve`. Use the project's package manager: `pnpm-lock.yaml` means pnpm, `yarn.lock` yarn, `bun.lock`/`bun.lockb` bun, otherwise npm.

If a dev server is already running for this project, reuse it. Otherwise start it in the background, sending its output to a file, and wait for it to be ready:

```
npm run dev > dev-server.log 2>&1 &
```

For Vite:

- The default port is 5173. If that port is taken, Vite silently moves to the next free port, so never assume 5173. Read the real URL from the output.
- It is ready when the log shows `ready in` and a line like `➜  Local:   http://localhost:5174/`. The output has color codes; strip them or match loosely.
- `--strictPort` makes Vite exit instead of changing port; `--host` exposes it on the network. Do not add `--open`; you will open the page yourself.

For other tools (Next.js, webpack dev server, Parcel), read the URL the same way: from the server's own output, not from a guess.

If the server exits or prints an error, fix that first. A compile error in the overlay is a failed check, not a rendering question.

## 2. Open the page and check the console (Chrome DevTools MCP)

1. Open the URL with `new_page` (or `navigate_page` with `type: "url"` on an existing page). Most tools take a `pageId`; get it from `new_page` or `list_pages`.
2. Give the scene time to load its models and textures. Use `wait_for` if the page shows a known text when ready; otherwise wait briefly and take a second screenshot later to confirm nothing changed.
3. Call `list_console_messages`. Look for:
   - Any error, including failed module imports, `404`s for `.glb`/`.gltf`/`.hdr`/`.ktx2`/texture files, and CORS errors.
   - Three.js warnings (they start with `THREE.`), shader compile or link errors, `WebGLRenderer: Context Lost.`, `WebGPURenderer: ... Device Lost`.
   - Browser WebGL warnings such as `GL_INVALID_OPERATION` or `WebGL: too many errors`.
   Use `get_console_message` for the full text of one message and `includeStackTraces: true` to find where it came from.
4. If an asset is suspected missing, `list_network_requests` shows each request and status; `get_network_request` shows one in detail.
5. Check the canvas has a real size. Run `evaluate_script` with:
   ```js
   () => [...document.querySelectorAll('canvas')].map(c => ({ width: c.width, height: c.height, cssWidth: c.clientWidth, cssHeight: c.clientHeight }))
   ```
   No canvas, or a width or height of 0, is a failure.

## 3. Take a screenshot and look at it

Call `take_screenshot` and actually look at the image. Compare it with what the change was supposed to produce. Not done if:

- The canvas is blank, black, or a single flat color.
- The model, object, or effect you changed is missing, cut off, tiny, or off-screen.
- Colors are wrong: washed out, too dark, or inverted.
- Something that used to be in the scene has disappeared.
- An error overlay or fallback message is showing.

If the result is ambiguous, move the camera or trigger the state in the page and take another screenshot. Use `resize_page` or `emulate` with a `viewport` if the change is about resizing.

## 4. Read the scene back (threejs-devtools-mcp, if connected)

How it connects: the server proxies the dev server (default proxy port 9222, dev port detected from `package.json`) and injects a bridge script into the page. Only a page loaded through that proxy is visible to it, and the tab must stay open. It opens a browser there itself unless `BROWSER=none` is set; `DEV_PORT` overrides the detected dev port, and `set_dev_port` changes it at run time. Pointing Chrome DevTools MCP at the proxy URL puts both tools on the same page.

1. `bridge_status`: confirm the bridge is connected. If not, fix that before trusting any other result.
2. `scene_tree` (compact by default): the objects you added or changed exist, sit where you expect in the hierarchy, and are visible. Name objects in code (`mesh.name`, or `name=` in R3F) so they are findable. Use `find_objects` to search by type, name pattern, or `visible`.
3. `object_details`, `material_details`, `geometry_details`: check the specific thing you changed (transform, material type and color, maps, vertex count, bounding box).
4. `renderer_info`: draw calls, triangles, geometries, textures. Compare with expectations: a mesh you added should add draw calls; an instancing change should cut them; a model should bring roughly the triangle count you expect; a number that is 0 or wildly off is a bug.
5. `renderer_settings`: tone mapping, shadows, pixel ratio, if the change touched renderer setup.
6. For shader work, `shader_list` and `shader_source` confirm the program compiled and the uniforms are what you set.
7. For performance-sensitive changes, `performance_snapshot` or `perf_monitor` (records FPS over a few seconds, with p95/p99 and spikes). For resource changes or scenes that rebuild, `memory_stats` and `dispose_check` catch leaked geometries and textures.
8. `console_capture` and `take_screenshot` also exist on this server. `annotated_screenshot` labels objects on the image, which helps when checking what is where.

`renderer_info` reports WebGL stats. The bridge finds the renderer through the `__THREE_DEVTOOLS__` hook, which `WebGLRenderer` announces itself on; if the app uses `WebGPURenderer` and the renderer tools come back empty, read `renderer.info` through `run_js` or `evaluate_script` from wherever the app exposes the renderer, and say in the report that you did.

Most other tools on this server change the scene (`set_*`, `toggle_wireframe`, `add_helper`). Use them only to diagnose, and never report a fix made that way as done: the change has to be in the source code, verified after a reload.

## 5. Animated and interactive changes

One frame proves little when something moves.

- Take two or more screenshots a moment apart and confirm they differ the way they should (object moved, animation advanced).
- With threejs-devtools-mcp, `animation_details` shows clips, mixer state and actions; `scene_diff` (snapshot, then diff) shows what changed between two moments. R3F `useAnimations` mixers are only visible to it if the app assigns them to `window.__THREE_ANIMATION_MIXERS__`.
- For interaction, drive the page: `click`, `hover` and `drag` work on elements from `take_snapshot`; `click_at` clicks canvas coordinates; `press_key` sends keys. Screenshot after each step.
- R3F with `frameloop="demand"` only renders when invalidated; a still frame there is not a bug by itself.
- `performance_start_trace` / `performance_stop_trace` record a Chrome trace if the change is about smoothness or load time.

## 6. After a hot reload

HMR can leave old objects, listeners, or a second renderer in the page. Before your final check, reload the page (`navigate_page` with `type: "reload"`, `ignoreCache: true`) and run steps 2 to 4 again on the fresh load.

## 7. Report

List each check and its result, for example:

- Dev server: command, URL it reported.
- Console: number of errors and warnings, and the text of any you could not fix.
- Canvas size.
- Screenshot: what it shows, and whether that matches the intended change.
- Scene read-back: the objects found, draw calls, triangles, anything unexpected.
- Frames or interactions checked.
- Anything you could not check, and why.

## Fallback: no browser MCP server

Say so first: "I cannot see the page from here." Then, in order:

1. If the project already has Playwright (`@playwright/test` or `playwright` in `package.json`), take a headless screenshot and read the image:
   ```
   npx playwright screenshot --wait-for-timeout 3000 <url> check.png
   ```
   Or run the project's own visual or end-to-end tests if they cover the scene. Headless Chrome may render WebGL in software and may not offer WebGPU, so an odd result there is a hint, not proof.
2. Otherwise ask the user to open the URL, look at the canvas, and paste any console errors. Tell them exactly what they should see.

Do not add Playwright or any other dependency to the project just for this check without asking.

## Troubleshooting

| Symptom | Likely causes and what to check |
|---|---|
| Black or empty canvas, no errors | Camera inside or behind the object, or pointing away (check `camera_details`, object bounding box, near/far planes). Lit material (`MeshStandardMaterial`, `MeshPhysicalMaterial`, `MeshLambertMaterial`, `MeshPhongMaterial`) with no lights and no environment map. Object scale tiny or huge. Renderer or canvas size 0 (container with no height; an R3F `<Canvas>` fills its parent, so the parent needs a height). Render loop never running. |
| Colors washed out or too dark | Color textures need `texture.colorSpace = THREE.SRGBColorSpace`; data textures (normal, roughness, metalness) must stay linear. Check `renderer.outputColorSpace` and tone mapping in `renderer_settings`. Also check light intensity and exposure. |
| WebGPU unavailable | `navigator.gpu` is missing (unsupported browser, not a secure context, or a headless browser without it). `WebGPURenderer` falls back to a WebGL 2 backend on its own unless the app requires WebGPU; `forceWebGL: true` forces that backend. The fallback logs `WebGPURenderer: WebGPU is not available, running under WebGL2 backend.`; report it, and confirm the changed feature still works under the WebGL 2 backend. |
| Context lost / device lost | Too much GPU memory, too many contexts (one renderer per page, not one per component or per hot reload), or a driver reset. Check `memory_stats` and `dispose_check`, and count canvases. |
| Model or texture missing, CORS error | Asset path wrong for the dev server (files in Vite's `public/` are served from `/`), a 404 in `list_network_requests`, or a cross-origin host without CORS headers. Serve it from the same origin or fix the headers; set `crossOrigin` on the loader where the host supports CORS. |
| Scene doubled, stale, or ignores the edit | HMR kept the old scene or renderer. Reload fully (section 6). If it persists, the app creates a renderer or adds objects without cleaning up on module reload or component unmount. |
| threejs-devtools-mcp tools return nothing | Page not loaded through its proxy, tab closed, wrong dev port (`set_dev_port`), or port 9222 already in use (set `BRIDGE_PORT`). Check `bridge_status`. |
