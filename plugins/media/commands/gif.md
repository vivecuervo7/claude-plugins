---
description: Convert a video file to a PR-suitable GIF using ffmpeg
argument-hint: [file path | hint like "last screen recording" | empty for newest video]
allowed-tools: Bash, Glob
---

Convert a video to a GIF optimised for GitHub PRs (12fps, lanczos scaling, native aspect ratio).

## Input

`$ARGUMENTS` is either:
- A direct file path (e.g. `/tmp/demo.mov`, `~/Desktop/recording.mov`)
- A natural language hint (e.g. `last screen recording`, `latest recording`)
- Empty — treat as "latest recording" (the newest video file across the search directories below)

## Steps

### 1. Preflight: confirm ffmpeg is installed

Run `command -v ffmpeg` via Bash. If it exits non-zero, stop and report that `ffmpeg` is not on the PATH. Do not proceed.

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

### 3. Convert with ffmpeg

**Always** drive ffmpeg from a shell glob. Never construct the source path by hand and pass it as a quoted/escaped string — macOS `Screen Recording` filenames contain non-breaking spaces (Unicode U+00A0), which look identical to regular spaces but won't match literal `0x20` in a quoted path, and the call will fail with "No such file or directory". Globbing sidesteps the issue by letting the shell expand against the real filename:

```bash
cd <source-directory>
for f in <pattern-matching-the-source>*; do
  OUT="${f%.*}.gif"   # or your chosen context-derived name
  ffmpeg -y -i "$f" -vf "fps=12,scale='if(gt(iw,ih),min(iw,800),-2)':'if(gt(iw,ih),-2,min(ih,800))':flags=lanczos" -loop 0 "$OUT"
done
```

ffmpeg requires even dimensions. The filter caps the **larger** dimension at 800 (landscape caps width, portrait caps height) and lets the smaller dimension scale proportionally. `-2` ensures even pixel counts. Source dimensions smaller than 800 are preserved as-is.

**Output path**: Place the GIF in the same directory as the source file. Name it based on context (e.g. `geo-chat-flow.gif`, `demo-recording.gif`). If no meaningful context is available, fall back to the source filename's stem with a `.gif` extension (`demo.mov` → `demo.gif`).

**Collision guard**: For *context-derived* names, if the path already exists append `-2`, `-3`, etc. until free (`geo-chat-flow.gif` → `geo-chat-flow-2.gif`) — those names aren't tied to a specific source, so an existing file is likely unrelated. For *source-stem fallback* names (`demo.mov` → `demo.gif`), overwrite without guarding — re-running on the same source should replace the prior conversion, not clutter the directory.

### 4. Report

Output the path and file size. If over 10MB, warn that GitHub may reject it and suggest reducing fps or scale.
