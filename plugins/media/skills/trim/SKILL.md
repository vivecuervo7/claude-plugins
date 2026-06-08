---
name: trim
description: "Trim static/loading segments out of a video or gif using auto-editor motion detection. Triggers on `/trim ...` slash invocations and natural phrases like 'cut the dead air from this recording', 'trim the loading spinners', 'shrink this gif'."
argument-hint: "[file path | hint like 'last recording' or 'last gif' | empty for newest] [--threshold N%]"
allowed-tools: Bash, Glob
---

Cut dead air (loading spinners, waits for backend, anything that isn't moving) out of a recording. Uses [auto-editor](https://github.com/WyattBlue/auto-editor)'s motion-based editor, run through `uvx` so nothing lands in the system Python.

## Input

`$ARGUMENTS` may contain:
- A direct file path (`.mov`/`.mp4`/`.webm`/`.mkv`/`.gif`)
- A natural-language hint (`last screen recording`, `latest recording`)
- A `--threshold N%` flag (default `2%`). Lower = keep more frames; higher = cut more aggressively.
- Empty — pick the newest video file across `~/Desktop/`, `~/Downloads/`, `~/Movies/`.

Parse `--threshold` out of `$ARGUMENTS` before resolving the source file.

## Steps

### 1. Preflight: confirm dependencies

Run these via Bash:
- `command -v ffmpeg` — stop and report if missing.
- `command -v uvx` — stop and report if missing (suggest `brew install uv`).

Don't pre-install auto-editor; `uvx --from auto-editor` will fetch it (and the platform binary it downloads on first run) on demand.

### 2. Resolve the source file

Follow the same resolution logic as `/gif`:
- If `$ARGUMENTS` looks like a file path (contains `/` or a known extension), verify it exists. If missing, try `Glob`; if still missing, stop and report.
- Otherwise, search `~/Desktop/`, `~/Downloads/`, `~/Movies/` (by modification time, newest first) for `.mov`/`.mp4`/`.webm`/`.mkv`/`.gif`. Match the hint against filenames, or pick the most recent overall.
- Always drive ffmpeg from a shell glob — never construct the source path by hand. macOS `Screen Recording` filenames contain non-breaking spaces (U+00A0) that look like regular spaces but won't match a literal `0x20` in a quoted path.

### 3. Run auto-editor

**Video input** (`.mov`/`.mp4`/`.webm`/`.mkv`):

```bash
cd <source-directory>
for f in <pattern-matching-the-source>*; do
  EXT="${f##*.}"
  OUT="${f%.*}-trimmed.${EXT}"
  uvx --from auto-editor auto-editor "$f" \
    --edit motion:threshold=${THRESHOLD:-2%} \
    --no-open \
    -o "$OUT"
done
```

**Gif input** (auto-editor doesn't read gifs directly — round-trip through mp4):

Preserve the source gif's framerate so trimming doesn't silently downsample it. Dimensions ride through the round-trip naturally (no scale filter applied). If you wanted resizing, you'd use `/gif`, not `/trim`.

```bash
cd <source-directory>
for f in <pattern-matching-the-source>*; do
  STEM="${f%.*}"
  TMP_IN=$(mktemp -t trim-in-XXXXXX).mp4
  TMP_OUT=$(mktemp -t trim-out-XXXXXX).mp4
  # Probe source fps (ffprobe returns "num/den" like "12/1" — ffmpeg accepts it directly)
  SRC_FPS=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$f")
  # Decode gif → mp4 (lossless-ish)
  ffmpeg -y -i "$f" -movflags +faststart -pix_fmt yuv420p -c:v libx264 -crf 18 "$TMP_IN"
  # Trim
  uvx --from auto-editor auto-editor "$TMP_IN" \
    --edit motion:threshold=${THRESHOLD:-2%} \
    --no-open \
    -o "$TMP_OUT"
  # Re-encode to gif, preserving the source's framerate (no scale — keep original dimensions)
  ffmpeg -y -i "$TMP_OUT" -vf "fps=${SRC_FPS}" -loop 0 "${STEM}-trimmed.gif"
  rm -f "$TMP_IN" "$TMP_OUT"
done
```

**Threshold meaning**: `motion:threshold=N%` keeps frames where ≥N% of the picture is moving. `2%` is the sweet spot for screen recordings — cuts loading spinners and idle waits while preserving cursor movement and form input. Push to `4%`–`6%` if you want tighter cuts (mouse-only motion gets dropped); drop to `1%` if anything important is being cut.

**Output naming**: alongside the source, with a `-trimmed` suffix before the extension (`geo-76.mov` → `geo-76-trimmed.mov`, `demo.gif` → `demo-trimmed.gif`). If `-trimmed` already exists, overwrite — re-running on the same source should replace the prior trim, not pile up `-trimmed-2.mov` files.

### 4. Report

Output the trimmed file's path, its duration, and the percentage reduction vs. source. If the reduction is under 5%, note that the recording was already tight and the trim added little — useful signal for when not to bother next time.
