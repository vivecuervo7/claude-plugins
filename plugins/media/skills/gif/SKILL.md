---
name: gif
description: "Convert a recording to a PR-suitable GIF — trims dead air, encodes at 12fps/lanczos/≤800px, holds the last frame. Triggers on `/gif ...` slash invocations and natural phrases like 'make a gif of the recording', 'convert this video to a gif', 'gif the last screen recording'."
argument-hint: "[file path | hint like 'last screen recording' | empty for newest video] [--no-trim] [--no-pad] [--threshold N%] [--hold N]"
allowed-tools: Bash, Glob
---

Convert a video to a GIF optimised for GitHub PRs (12fps, lanczos scaling, native aspect ratio). The full pipeline is `trim → encode → pad`:
- **Trim** — auto-editor cuts loading-spinner dead air (skip with `--no-trim`).
- **Encode** — ffmpeg writes the gif at 12fps, lanczos-scaled.
- **Pad** — tpad holds the last frame for ~0.5s so the loop boundary is visible (skip with `--no-pad`, extend with `--hold N`).

The default pad is intentionally short — just enough to break the loop visually. For meaningful proof-frame holds (1–2s), run `/pad` on the output afterwards rather than baking it into every gif.

## Input

`$ARGUMENTS` is either:
- A direct file path (e.g. `/tmp/demo.mov`, `~/Desktop/recording.mov`)
- A natural language hint (e.g. `last screen recording`, `latest recording`)
- Empty — treat as "latest recording" (the newest video file across the search directories below)

Plus optional flags:
- `--no-trim` — skip the auto-editor preprocess and encode the raw recording.
- `--no-pad` — skip the last-frame hold; loop point is the natural last frame.
- `--threshold N%` — forwarded to the trim step (default `2%`).
- `--hold N` — last-frame hold in seconds (default `0.5`). Accepts fractional values.

Parse the flags out of `$ARGUMENTS` before resolving the source file.

## Steps

### 1. Preflight: confirm dependencies

Run `command -v ffmpeg` via Bash. If it exits non-zero, stop and report that `ffmpeg` is not on the PATH. Do not proceed.

Unless `--no-trim` was passed, also run `command -v uvx`. If missing, either fall back to `--no-trim` behaviour with a warning, or stop and suggest `brew install uv` — pick whichever the user is more likely to want; default to falling back so the command stays useful.

### 2. Resolve the source file

**If `$ARGUMENTS` looks like a file path** (contains `/` or a video extension like `.mov`/`.mp4`/`.webm`/`.mkv`):
- Verify it exists. If not found, try Glob to find it.
- If still not found, stop and report. Do not invent a path.

**If `$ARGUMENTS` is a hint, or empty**:
- Search these directories for video files (`.mov`, `.mp4`, `.webm`, `.mkv`), sorted by modification time (newest first):
  - `~/Desktop/`
  - `~/Downloads/`
  - `~/Movies/`
- If empty, pick the most recent video file across all three directories.
- Otherwise, match the hint against filenames. "last screen recording" → most recent `Screen Recording*` file. "latest recording" → most recent video file overall.
- If multiple matches, pick the most recent.
- If no video files exist in any of the search directories (or none match the hint), stop and report that no recordings were found. Do not invent a path.

### 3. Trim dead air (unless `--no-trim`)

Run auto-editor as a preprocess step. Use `uvx` so nothing lands in the system Python; the first invocation downloads the platform binary, subsequent ones are cached.

```bash
cd <source-directory>
TRIMMED=$(mktemp -t gif-trimmed-XXXXXX).mov
for f in <pattern-matching-the-source>*; do
  uvx --from auto-editor auto-editor "$f" \
    --edit motion:threshold=${THRESHOLD:-2%} \
    --no-open \
    -o "$TRIMMED"
done
```

The encode step (next) reads from `$TRIMMED` instead of the original. If `--no-trim` was passed (or `uvx` was unavailable and you fell back), point the encode step at the original source instead.

`motion:threshold=2%` is the empirically-tuned default — cuts loading spinners and idle waits, preserves cursor movement and form input. Bump higher to cut more aggressively.

### 4. Convert with ffmpeg

**Always** drive ffmpeg from a shell glob. Never construct the source path by hand and pass it as a quoted/escaped string — macOS `Screen Recording` filenames contain non-breaking spaces (Unicode U+00A0), which look identical to regular spaces but won't match literal `0x20` in a quoted path, and the call will fail with "No such file or directory". Globbing sidesteps the issue by letting the shell expand against the real filename:

Build the filter chain — `fps,scale,lanczos` always; append `tpad` unless `--no-pad` was passed:

```bash
cd <source-directory>
HOLD="${HOLD:-0.5}"
FILTER="fps=12,scale='if(gt(iw,ih),min(iw,800),-2)':'if(gt(iw,ih),-2,min(ih,800))':flags=lanczos"
[ -z "$NO_PAD" ] && FILTER="${FILTER},tpad=stop_mode=clone:stop_duration=${HOLD}"

for f in <pattern-matching-the-source>*; do
  OUT="${f%.*}.gif"   # or your chosen context-derived name
  INPUT="${TRIMMED:-$f}"
  ffmpeg -y -i "$INPUT" -vf "$FILTER" -loop 0 "$OUT"
done
[ -n "$TRIMMED" ] && rm -f "$TRIMMED"
```

The `tpad` filter clones the final frame for `$HOLD` seconds before the loop restarts. Cloned frames compress to almost nothing in gif, so file size barely changes.

ffmpeg requires even dimensions. The filter caps the **larger** dimension at 800 (landscape caps width, portrait caps height) and lets the smaller dimension scale proportionally. `-2` ensures even pixel counts. Source dimensions smaller than 800 are preserved as-is.

**Output path**: Place the GIF in the same directory as the source file. Name it based on context (e.g. `geo-chat-flow.gif`, `demo-recording.gif`). If no meaningful context is available, fall back to the source filename's stem with a `.gif` extension (`demo.mov` → `demo.gif`).

**Collision guard**: For *context-derived* names, if the path already exists append `-2`, `-3`, etc. until free (`geo-chat-flow.gif` → `geo-chat-flow-2.gif`) — those names aren't tied to a specific source, so an existing file is likely unrelated. For *source-stem fallback* names (`demo.mov` → `demo.gif`), overwrite without guarding — re-running on the same source should replace the prior conversion, not clutter the directory.

### 5. Report

Output the path and file size. If over 10MB, warn that GitHub may reject it and suggest reducing fps or scale. If trim was applied, also note the duration reduction vs. source (e.g. "33.8s → 17.7s after trim").
