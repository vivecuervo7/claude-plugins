# media

Media utilities for Claude Code. Each command bundles a recurring screen-recording or video chore into a single slash command with sensible defaults and a friendly input layer — natural-language file hints, preflight checks, and helpful failure modes — so these tasks stop being a trip to the man page.

Today the plugin ships three commands: `/gif` (encode), `/trim` (cut dead air), and `/pad` (hold the last frame). They compose — `/gif` chains through `/trim` and `/pad` by default — but each is useful on its own.

## Install

```bash
claude plugin marketplace add vivecuervo7/claude-plugins
claude plugin install media@vive-claude
```

## Requirements

This plugin is macOS-only. Commands rely on `Screen Recording` filename conventions, Desktop/Downloads/Movies search paths, and Homebrew for installing dependencies.

Individual commands check their own dependencies before doing any work and stop with install hints if anything is missing.

```bash
brew install ffmpeg uv
```

- `ffmpeg` — used by both `/gif` and `/trim` for encode/decode.
- `uv` — provides `uvx`, which runs [auto-editor](https://github.com/WyattBlue/auto-editor) in an isolated environment. No system Python required; the auto-editor binary is fetched on first run and cached.

## Commands

| Command | Description |
|---------|-------------|
| `/gif [file or hint] [--no-trim] [--no-pad] [--threshold N%] [--hold N]` | Convert a video to a PR-suitable GIF (12fps, lanczos, max 800px on the long edge), trimming dead air first and adding a small last-frame hold. With no argument, picks the newest recording. |
| `/trim [file or hint] [--threshold N%]` | Cut loading-spinner / idle-wait segments out of a video or gif using motion detection. Output sits beside the source with a `-trimmed` suffix. |
| `/pad [file or hint] [--hold N]` | Hold the last frame of a video or gif for N seconds (default 1.5) so the proof-of-fix frame lingers before the loop restarts. Output sits beside the source with a `-padded` suffix. |

### `/gif`

Converts `.mov`/`.mp4`/`.webm`/`.mkv` to an animated `.gif` tuned for embedding in GitHub pull requests — small enough to upload, sharp enough to read.

The full pipeline is `trim → encode → pad`:
- `/trim` cuts loading spinners and idle waits so they don't eat the GIF's frame budget (skip with `--no-trim`).
- ffmpeg encodes at 12fps, lanczos-scaled, capped at 800px on the long edge.
- A short `--hold` (default `0.5s`) clones the last frame so the loop boundary is visible (skip with `--no-pad`).

The default pad is intentionally tiny. When the recording ends on a proof-of-fix frame and you want it to linger, run `/pad` on the output afterwards rather than re-encoding with a larger `--hold` — `/pad` works directly on the gif, no source video needed.

Accepts a path, a natural-language hint, or no argument at all. With no argument, `/gif` picks the newest video file across `~/Desktop/`, `~/Downloads/`, and `~/Movies/` — usually the recording you just made.

```
/gif                              # newest video across Desktop / Downloads / Movies
/gif ~/Desktop/demo.mov
/gif last screen recording
/gif latest recording on desktop
/gif --no-trim                    # skip the auto-editor step
/gif --no-pad                     # no last-frame hold
/gif --threshold 4%               # cut more aggressively
/gif --hold 1                     # bump the built-in pad to 1s
```

Output lands beside the source file with a context-derived name (e.g. `geo-chat-flow.gif`). Files over 10MB get a warning — GitHub's upload limit will reject them, and you'll want to either drop the framerate or crop the recording.

### `/trim`

Strips static segments out of a recording using motion analysis. Auto-editor scores each frame's motion against the previous frame and drops anything below the threshold — so loading spinners, network waits, and idle screens get cut, while cursor movement, typing, and animation are preserved.

Works on both video files (`.mov`/`.mp4`/`.webm`/`.mkv`) and existing `.gif` files. Output keeps the input's extension, with `-trimmed` inserted before the suffix (`demo.mov` → `demo-trimmed.mov`).

```
/trim                             # newest video, default 2% threshold
/trim ~/Desktop/long-repro.mov
/trim --threshold 4%              # more aggressive — cuts mouse-only motion too
/trim demo.gif                    # round-trips through mp4, re-encodes to gif
```

The default `2%` motion threshold is what we landed on after comparing approaches — it's tight enough to cut waits and loose enough to keep meaningful UI feedback. Tune up for tighter cuts, down if you find something useful is missing.

### `/pad`

Holds the last frame of a video or gif for N seconds before the loop restarts. Useful when the recording ends on a proof-of-fix frame (a green checkmark, a final form state, the bug not happening) and you want the reader to register it.

Works on both gif and video input. Output keeps the input's extension with `-padded` inserted before the suffix.

```
/pad                              # newest file, default 1.5s hold
/pad ~/Desktop/AE-1759-after.gif
/pad --hold 2                     # longer pause
/pad demo.mov --hold 0.75         # fractional values OK
```

Cloned frames compress to almost nothing in gif, so the size delta is negligible — `/pad` is essentially free.

## License

MIT
