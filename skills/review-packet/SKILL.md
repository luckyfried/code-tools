---
name: review-packet
description: This skill should be used when the user asks to "create a review packet", "review packet", "concat files for review", "bundle for review", "make a review doc", or wants to concatenate project files into a single document for external review.
---

# Review Packet Generator

Generate a single concatenated file from project files for external review. The output file lands at the project root, ready to send to reviewers.

## Usage

```
/review-packet <target>
```

**Target** can be:
- A short name: `review-packet work-tracking-backlog`
- A directory path: `review-packet src/services/`
- A description: `review-packet the broker config code and its tests`

## Process

### 1. Resolve the Target

Determine what files to include. **Never assume a fixed path.** Search dynamically.

**If the target looks like a path and exists:**
- Use the path directly
- Default to recursive search for `md,py,txt` files
- Output filename derived from the last path segment

**If the target is a short name (no slashes, no description):**
- Search the project for directories matching the name: `find . -type d -name "<target>" 2>/dev/null | head -20`
- If exactly one match, use it
- If multiple matches, present them and ask the user which one
- If no matches, try partial/fuzzy: `find . -type d -name "*<target>*" 2>/dev/null | head -20`
- If still nothing, treat it as a descriptive target (below)

**If the target is descriptive** (e.g., "the broker config and tests"):
- Search the codebase to identify relevant files using Glob/Grep
- Present the proposed file list to the user for confirmation
- Ask if any files should be added or removed

### 2. Confirm with User (when needed)

Once the target directory/files are resolved, show what will be included:

```
Found: thoughts/shared/plans/work-tracking-backlog/ (7 files)
  00-overview.md, 01-work-item-schema.md, ...

Proceed with these files?
```

**Skip confirmation** only when:
- The target resolved to exactly one directory with an obvious set of files
- The file count is reasonable (<20 files)

**Always confirm** when:
- Multiple directories matched
- The target was descriptive/ambiguous
- More than 20 files would be included

### 3. Check for Related Context

Before concatenating, search for related files that reviewers might need:

- Search for handoff/review documents near the target (e.g., sibling directories, parent directories)
- Look for files like `*REVIEW*`, `*handoff*`, `*report*` related to the target name
- Check if the target references other files that should be included

If relevant files are found outside the main target, ask:
> "Found related files: `<path>`. Include them in the packet?"

### 4. Run Concatenation

Use the bundled `concat_files.sh` script from the skill directory. Pass `$CLAUDE_CONFIG_DIR` **literally** as written — do not resolve or substitute it. The shell expands it at runtime:

```bash
"$CLAUDE_CONFIG_DIR/skills/review-packet/concat_files.sh" -p <resolved-path> -r -t "md,py,txt" -o review-<target-name>.txt
```

For mixed sources (specific files + directories), combine `-f` and `-p` flags:

```bash
"$CLAUDE_CONFIG_DIR/skills/review-packet/concat_files.sh" \
  -f path/to/specific-file.md \
  -p path/to/directory \
  -r -t "md,py,txt" \
  -o review-target.txt
```

Adjust file types based on content:
- Plan docs: `md,py,txt`
- Source code: `py,md` (or `ts,tsx,md` for frontend)
- Mixed: whatever types are present in the target

### 5. Report Results

After generating the packet, report:
- Output file path and size
- Number of files included
- List of included files (abbreviated if >10)

Example:
```
Review packet created: review-work-tracking-backlog.txt
  7 files, 42KB
```

## When Unsure

If the target is ambiguous or involves mixed file types (code + docs + tests), always ask the user to confirm the file list before concatenating. Present a proposed list and let them add/remove files.

## Important

- Output always goes to the **project root** directory
- Output filename: `review-<target-name>.txt`
- Use recursive mode (`-r`) by default for directories
- Adjust file types to match the content (don't blindly use `md,py,txt` for a TypeScript project)
- Never include binary files, `__pycache__`, `.pyc`, `node_modules`, or `.git/` directories
