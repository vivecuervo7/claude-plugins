---
name: pad
description: "Hold the last frame of a video or gif for a few seconds before it loops or ends. Triggers on `/pad ...` slash invocations and natural phrases like 'make the last frame linger', 'pad the end of this gif', 'hold the final frame'."
argument-hint: "[file path | hint like 'last gif' | empty for newest] [--hold N]"
allowed-tools: Bash, Glob
---

Extend the final frame of a video or animated gif so the proof-of-fix frame (or whatever the recording ends on) holds long enough for a reader to take it in. For gifs this delays the loop restart; for videos it just extends the runtime before playback ends. Uses ffmpeg's `tpad` filter to clone the last frame — the held frames compress to essentially nothing, so file size barely moves.

## Input

`$ARGUMENTS` may contain:
- A direct file path (`.gif`, `.mov`, `.mp4`, `.webm`, `.mkv`)
- A natural-language hint (`last gif`, `latest recording`)
- A `--hold N` flag in seconds (default `1.5`). Accepts fractional values (`--hold 0.75`).
- Empty — pick the newest gif/video file across `~/Desktop/`, `~/Downloads/`, `~/Movies/`.

Parse `--hold` out of `$ARGUMENTS` before resolving the source file.

## Steps

### 1. Preflight: confirm ffmpeg

Run `command -v ffmpeg` via Bash. If it exits non-zero, stop and report.

### 2. Resolve the source file

Same resolution logic as `/gif` and `/trim`:
- File path: verify it exists, fall back to `Glob` if needed, stop if still missing.
- Hint/empty: search `~/Desktop/`, `~/Downloads/`, `~/Movies/` by mtime; match the hint against filenames or pick the most recent overall.
- Always drive ffmpeg from a shell glob — macOS `Screen Recording` filenames contain non-breaking spaces (U+00A0) that won't match literal `0x20` in a quoted path.

### 3. Apply the hold

The filter is `tpad=stop_mode=clone:stop_duration=${HOLD:-1.5}`. It works the same way on video and gif input.

**Gif input:**

```bash
cd <source-directory>
for f in <pattern-matching-the-source>*; do
  OUT="${f%.*}-padded.gif"
  ffmpeg -y -i "$f" \
    -vf "tpad=stop_mode=clone:stop_duration=${HOLD:-1.5}" \
    -loop 0 "$OUT"
done
```

**Video input** (`.mov`/`.mp4`/`.webm`/`.mkv`):

```bash
cd <source-directory>
for f in <pattern-matching-the-source>*; do
  EXT="${f##*.}"
  OUT="${f%.*}-padded.${EXT}"
  ffmpeg -y -i "$f" \
    -vf "tpad=stop_mode=clone:stop_duration=${HOLD:-1.5}" \
    -c:v libx264 -crf 18 -pix_fmt yuv420p \
    "$OUT"
done
```

**Output naming**: alongside the source, with `-padded` inserted before the extension (`demo.gif` → `demo-padded.gif`). If `-padded` already exists, overwrite — re-running on the same source should replace the prior pad, not pile up suffixes.

### 4. Report

Output the padded file's path, its new duration, and the size delta. Cloned frames compress well, so size should barely change for gifs — flag it if the delta is more than a few percent (something unusual happened).
