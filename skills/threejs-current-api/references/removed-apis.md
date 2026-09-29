# Old pattern to current pattern

"Changed in" is the release where the Migration Guide lists the change. The guide heading
`N → N+1` means the change shipped in r(N+1). Where the old name kept working for a while as a
deprecated alias, "Gone by" is the first npm release whose `src/` no longer has it. Nothing in this
table exists in r186 unless a note says it is only deprecated.

## Core API

| Old pattern | Current pattern | Changed in | Gone by |
| --- | --- | --- | --- |
| `new THREE.Geometry()`, `geometry.vertices`, `geometry.faces` | `THREE.BufferGeometry` with `setAttribute('position', new THREE.Float32BufferAttribute(arr, 3))`. Built-in generators like `BoxGeometry` return `BufferGeometry`. | r125 (moved out of core) | not shipped in r186 |
| `new THREE.Face3(a, b, c)` | An index buffer: `geometry.setIndex([a, b, c, ...])` | r126 (moved out of core) | not shipped in r186 |
| `renderer.outputEncoding = THREE.sRGBEncoding` | `renderer.outputColorSpace = THREE.SRGBColorSpace` (already the default) | r152 | r162 |
| `texture.encoding = THREE.sRGBEncoding` | `texture.colorSpace = THREE.SRGBColorSpace` | r152 | r162 |
| `THREE.LinearEncoding` | `THREE.LinearSRGBColorSpace` | r152 | r162 |
| `ColorManagement.legacyMode = false` | `ColorManagement.enabled = true` (the default since r152) | r150 | |
| `renderer.physicallyCorrectLights = true` | Nothing. Physical lighting is the only mode. | r150 (renamed to `useLegacyLights`) | r160 |
| `renderer.useLegacyLights = false` | Nothing. Remove the line. | r155 (deprecated, default `false`) | r165 |
| `renderer.gammaFactor`, `THREE.GammaEncoding` | A gamma correction post-processing pass if you really need one | r136 | |
| `THREE.WebGL1Renderer` or WebGL 1 contexts | `THREE.WebGLRenderer` (WebGL 2 only) or `WebGPURenderer` | r163 | r163 |
| Stencil operations without asking for a stencil buffer | Pass `stencil: true` to the renderer. It now defaults to `false`. | r163 | |
| `new CapsuleGeometry(radius, length, ...)` | `new CapsuleGeometry(radius, height, ...)` (parameter renamed) | r176 | |
| `new THREE.Clock()` | `new THREE.Timer()`. It is in core since r179, so call `timer.update()` each frame. | r183 (deprecated) | still ships, deprecated |
| `BufferGeometryUtils.mergeBufferGeometries()` | `BufferGeometryUtils.mergeGeometries()` | r151 | |
| `attribute.updateRange` | `attribute.addUpdateRange(start, count)` / `clearUpdateRanges()` | r159 | |
| Geometry attributes `uv2` (for `aoMap` / `lightMap`) | Attributes are `uv`, `uv1`, `uv2`, `uv3`. Choose the one a texture uses with `texture.channel`. | r151 / r152 | |
| `scene.add(transformControls)` | `scene.add(transformControls.getHelper())` | r169 | |
| `TextGeometry` option `height` | `depth` | r163 | |
| `envMapIntensity` to scale `scene.environment` | `scene.environmentIntensity` | r163 | |

## Scripts, files, and loaders

| Old pattern | Current pattern | Changed in | Gone by |
| --- | --- | --- | --- |
| `<script src=".../examples/js/controls/OrbitControls.js">` | `import { OrbitControls } from 'three/addons/controls/OrbitControls.js'` | r148 | r148 |
| `<script src=".../build/three.min.js">` and a global `THREE` | An ES module import, with an import map when there is no bundler | r150 (deprecated) | r161 |
| `examples/js/libs/draco/` decoder path | `examples/jsm/libs/draco/` | r148 | |
| `new RGBELoader()` | `new HDRLoader()` | r180 | still ships, deprecated |
| `RGBMLoader` | `EXRLoader`, `HDRLoader`, `HDRCubeTextureLoader`, or `UltraHDRLoader` | r180 | r180 |
| `FileLoader.load()` / `ImageBitmapLoader.load()` return value | Use the `onLoad` callback | r184 | |

## WebGPURenderer and TSL

| Old pattern | Current pattern | Changed in |
| --- | --- | --- |
| Importing WebGPURenderer or node classes from `three/examples/jsm/...` or `three/nodes` | `import * as THREE from 'three/webgpu'` and `import { ... } from 'three/tsl'` | r171 (r167 changed them first) |
| `await renderer.renderAsync(scene, camera)` | `renderer.render(scene, camera)` after `setAnimationLoop()` or `await renderer.init()` | r181 (async methods deprecated) |
| `renderer.waitForGPU()` | Removed, no replacement | r181 |
| `new PostProcessing(renderer)` | `new RenderPipeline(renderer)` | r183 |
| `KTX2Loader.detectSupportAsync(renderer)` | `detectSupport(renderer)` after `await renderer.init()` | r181 |
| Node materials used with `WebGLRenderer` | Node materials need `WebGPURenderer` (which has a WebGL 2 fallback) | r164 |
| `ShaderMaterial` / `onBeforeCompile` / `EffectComposer` under WebGPURenderer | Node materials + TSL, `RenderPipeline` passes | not supported (WebGPURenderer manual) |
| `PCFSoftShadowMap` | `PCFShadowMap` (now soft) | r182 deprecated on WebGL; r186 removed on WebGPU |

TSL renames happen almost every release, for example `PI2` became `TWO_PI` (r181), `label()` became
`setName()` (r179), and `varying()` became `toVarying()` (r173). Check the TSL section of
<https://threejs.org/docs/llms-full.txt> and the Migration Guide instead of relying on memory.

## Sources

- Migration Guide: <https://github.com/mrdoob/three.js/wiki/Migration-Guide>
- Docs and LLM instructions: <https://threejs.org/docs/llms.txt>, <https://threejs.org/docs/llms-full.txt>
- Manual: <https://threejs.org/manual/#en/color-management>,
  <https://threejs.org/manual/#en/webgpurenderer>,
  <https://threejs.org/manual/#en/how-to-dispose-of-objects>,
  <https://threejs.org/manual/#en/responsive>
- Releases: <https://github.com/mrdoob/three.js/releases>
