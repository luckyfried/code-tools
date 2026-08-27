# statusline/

`README.md` is user-facing install docs. This file is for agents editing the directory — keep the two
separate.

The preset is consumed by [ccstatusline](https://www.npmjs.com/package/ccstatusline), so the schema
isn't ours to change. Keep it valid JSON with `version` intact:

```bash
python3 -c "import json; json.load(open('statusline/ccstatusline.json'))"
```

**Any widget change must update the README's widget table and example line in the same commit** — the
table is the only explanation of what the preset renders.

Adding a second option means restoring "pick one" framing in the README, which is currently written
for a single choice. State dependencies plainly; `npx` on every render is a real cost.
