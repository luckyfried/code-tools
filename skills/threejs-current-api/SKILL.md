---
name: threejs-current-api
description: Use whenever writing, reviewing, or upgrading Three.js code, whether vanilla or under React Three Fiber. Also use when fixing Three.js deprecation warnings or "is not exported" / "does not provide an export named" import errors, upgrading the `three` package, choosing between WebGLRenderer and WebGPURenderer, writing TSL or node materials, or setting up color spaces, lights, disposal, or resize handling. Triggers include "three.js", "threejs", "three", "r3f", "WebGPURenderer", "TSL", "outputEncoding", "sRGBEncoding", "THREE.Geometry", "examples/js", "OrbitControls import", "texture looks washed out", and "upgrade three".
---

# Current Three.js API

Coding agents often write Three.js from memory, and that memory is out of date. This skill covers
what current Three.js (the `three` npm package, release r186 at `0.186.x`) expects, and the old
patterns you must not write.

The detailed mapping from old patterns to current ones is in
`references/removed-apis.md`. Each row there gives the release where the change landed.

## Before writing any Three.js code

1. **Check the installed version.** Read `three` in `package.json` (or the lockfile). The npm
   version `0.NNN.x` is release rNNN. Write code for that version, not the version you remember.
2. **When unsure an API exists, look it up** at <https://threejs.org/docs/llms.txt> (short, with
   official instructions for LLMs) or <https://threejs.org/docs/llms-full.txt> (full, includes the
   TSL reference). The API docs are at <https://threejs.org/docs/>.
3. **When upgrading across releases**, read the relevant sections of the
   [Migration Guide](https://github.com/mrdoob/three.js/wiki/Migration-Guide). Deprecation
   warnings last about ten releases, so upgrade in steps of about ten releases, not in one jump.
4. **Never guess an import path or class name.** If it is not in the docs or in
   `node_modules/three`, it does not exist.
5. **When another skill's example disagrees with this one about whether an API is current**
   (an import path, a class name, a renamed method), follow this skill and the installed version.
   Other skills are often written against an older release.

## Imports: ES modules only

`three` ships only ES modules (plus a CJS build of the core for `require`). There is no global
`THREE` script build. `build/three.js` and `build/three.min.js` were removed in r161, and the
`examples/js` folder was removed in r148.

```js
import * as THREE from 'three';                                   // core + WebGLRenderer
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

import * as THREE from 'three/webgpu';                            // core + WebGPURenderer + node materials
import { texture, uv, color } from 'three/tsl';                   // TSL functions
```

The package's `exports` map defines these entry points: `three`, `three/addons/*` (the same files
as `three/examples/jsm/*`), `three/addons` (one barrel of every addon), `three/webgpu`, and
`three/tsl`. Keep the `.js` extension on addon paths.

Never write:

- `<script src=".../three.min.js">` or code that relies on a global `THREE`
- `THREE.OrbitControls`, `THREE.GLTFLoader`, or any addon on the `THREE` namespace. Addons are
  separate imports.
- `three/examples/js/...` paths
- `import { WebGLRenderer } from 'three/webgpu'`. That entry point exports `WebGPURenderer`, not
  `WebGLRenderer`.

### Pages without a bundler: use an import map

This is the pattern from the official llms.txt. Pin the version to the one the project uses:

```html
<script type="importmap">
{
  "imports": {
    "three": "https://cdn.jsdelivr.net/npm/three@0.186.1/build/three.module.js",
    "three/addons/": "https://cdn.jsdelivr.net/npm/three@0.186.1/examples/jsm/"
  }
}
</script>
<script type="module">
  import * as THREE from 'three';
  import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
</script>
```

For WebGPURenderer, the manual maps `"three"` and `"three/webgpu"` to `build/three.webgpu.js`, and
`"three/tsl"` to `build/three.tsl.js`.

## Color management (defaults since r152)

- `THREE.ColorManagement.enabled` is `true` by default. Leave it on. Hex and CSS colors passed to
  `Color` are treated as sRGB and converted to the Linear-sRGB working space automatically.
- `renderer.outputColorSpace` defaults to `THREE.SRGBColorSpace`. You do not need to set it.
- A new `Texture` has `colorSpace = THREE.NoColorSpace`. **You set it yourself on textures you load
  by hand:**
  - Color textures (`map`, `emissiveMap`, and 8-bit images holding color):
    `tex.colorSpace = THREE.SRGBColorSpace`
  - Data textures (`normalMap`, `roughnessMap`, `metalnessMap`, `aoMap`, and similar): leave the
    default `NoColorSpace`
  - Linear HDR color (for example OpenEXR for `envMap` or `lightMap`): `THREE.LinearSRGBColorSpace`
- `GLTFLoader` already assigns sRGB to base color textures, and `CubeTextureLoader` loads cube
  maps as sRGB. Do not set these again.
- Tone mapping and color space conversion apply only when rendering to the screen. With
  `EffectComposer`, add `OutputPass` at the end of the chain.
- A texture that looks washed out or too dark usually has the wrong `colorSpace`.

## Lighting: physical units only

Physically based lighting is the only mode. `renderer.physicallyCorrectLights` and
`renderer.useLegacyLights` no longer exist. Do not set them. `PointLight` and `SpotLight`
`intensity` is in candela, their `power` is in lumens, and `decay` defaults to `2`. Intensities
tuned for the old lighting mode usually need to be raised a lot.

## Choosing a renderer

| Use | When |
| --- | --- |
| `WebGLRenderer` from `'three'` | The default for WebGL 2 apps. It is mature, and most examples and tutorials use it. It is still maintained but gets no large new features. It needs WebGL 2 (WebGL 1 support was removed in r163). |
| `WebGPURenderer` from `'three/webgpu'` | You need TSL or node materials, compute shaders, or the new post-processing stack. It uses WebGPU and falls back to a WebGL 2 backend automatically when WebGPU is not available. `forceWebGL: true` always uses the WebGL 2 backend. |

Setting up WebGPURenderer:

```js
import * as THREE from 'three/webgpu';

const renderer = new THREE.WebGPURenderer( { antialias: true } );
renderer.setPixelRatio( window.devicePixelRatio );
renderer.setSize( window.innerWidth, window.innerHeight );
document.body.appendChild( renderer.domElement );
renderer.setAnimationLoop( render );   // initializes the renderer before the first frame
```

- Initialization is asynchronous. `setAnimationLoop()` handles it for you. If you render on demand,
  use `requestAnimationFrame`, or touch the renderer during setup, call `await renderer.init()`
  first. Calling `render()` before initialization throws.
- Once the renderer is initialized, call the normal synchronous methods. `renderAsync()`,
  `computeAsync()`, `clearAsync()`, `initTextureAsync()`, and `hasFeatureAsync()` are deprecated
  (r181).
- **WebGPURenderer does not support** `ShaderMaterial`, `RawShaderMaterial`, `onBeforeCompile()`,
  or `EffectComposer` and its passes. Port that code to node materials
  (`MeshStandardNodeMaterial` and so on) and TSL, and use `RenderPipeline` for post-processing.
  `PostProcessing` was renamed `RenderPipeline` in r183.
- Node materials and TSL work only with WebGPURenderer, not with WebGLRenderer.
- TSL (`import { ... } from 'three/tsl'`) compiles to WGSL or GLSL depending on the backend. Look
  up TSL function names in llms-full.txt, because many were renamed between r167 and r185.

## Disposal

Three.js does not free GPU memory on its own. Removing a mesh from the scene frees nothing.

- `geometry.dispose()`, `material.dispose()`, and `texture.dispose()`. Disposing a material does
  **not** dispose its textures. Dispose shared resources only when nothing uses them any more.
- Render targets: `renderTarget.dispose()`. Skeletons you no longer need: `skeleton.dispose()`.
- Controls, passes, and other addons with a `dispose()` method: call it (it removes listeners).
- `renderer.dispose()` when the whole view is torn down, for example when a component unmounts.
  A disposed renderer or controls object cannot be used again, so create a new one.
- `ImageBitmap` sources also need `bitmap.close()`.
- `Object3D` has had a `dispose()` method since r186. It does not free that object's geometry,
  material, or textures. A custom `Object3D` subclass that defines `dispose()` must call
  `super.dispose()`.
- To find leaks, check `renderer.info.memory`.

## Resize and pixel ratio

```js
function resizeToDisplaySize( renderer, camera ) {
  const canvas = renderer.domElement;
  const w = canvas.clientWidth, h = canvas.clientHeight;
  if ( canvas.width !== Math.floor( w * renderer.getPixelRatio() ) ||
       canvas.height !== Math.floor( h * renderer.getPixelRatio() ) ) {
    renderer.setSize( w, h, false );   // false: leave the CSS size alone
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
  }
}
```

Call `renderer.setPixelRatio( window.devicePixelRatio )` once, before `setSize`. After changing
`camera.aspect`, always call `camera.updateProjectionMatrix()`. Size the canvas with CSS and pass
`false` as the third argument to `setSize`.

## React Three Fiber

R3F creates the renderer, scene, and camera for you, but everything below them is plain `three`.
The same rules apply: current imports, `colorSpace` on textures you load by hand, physical light
units, and no removed classes. Check the installed `three` version as well as the R3F version.

## Quick "never write" list

`THREE.Geometry`, `THREE.Face3`, `renderer.outputEncoding`, `THREE.sRGBEncoding`,
`THREE.LinearEncoding`, `texture.encoding`, `renderer.physicallyCorrectLights`,
`renderer.useLegacyLights`, `renderer.gammaFactor`, `THREE.WebGL1Renderer`,
`ColorManagement.legacyMode`, `examples/js/...`, `three.min.js`, and `THREE.OrbitControls`. Avoid
the deprecated `RGBELoader` (use `HDRLoader`) and `Clock` (use `Timer`). `ContactShadows` is a
React Three Fiber Drei component, not a `three/addons` class. See
`references/removed-apis.md` for what to write instead.
