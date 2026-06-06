# media

Media utilities for Claude Code. Each command bundles a recurring screen-recording or video chore into a single slash command with sensible defaults and a friendly input layer — natural-language file hints, preflight checks, and helpful failure modes — so these tasks stop being a trip to the man page.

Today the plugin ships one command (`/gif`). It will grow as more recurring recipes earn their keep.

## Install

```bash
claude plugin marketplace add vivecuervo7/claude-plugins
claude plugin install media@vive-claude
```

## Requirements

This plugin is macOS-only. Commands rely on `Screen Recording` filename conventions, Desktop/Downloads/Movies search paths, and Homebrew for installing dependencies.

Individual commands may depend on external tools. Each command checks its own dependencies before doing any work and stops with install hints if anything is missing.

`/gif` requires `ffmpeg`:

```bash
brew install ffmpeg
```

## Commands

| Command | Description |
|---------|-------------|
| `/gif [file or hint]` | Convert a video to a PR-suitable GIF (12fps, lanczos, max 800px on the long edge). With no argument, picks the newest recording. |

### `/gif`

Converts `.mov`/`.mp4`/`.webm`/`.mkv` to an animated `.gif` tuned for embedding in GitHub pull requests — small enough to upload, sharp enough to read.

Accepts a path, a natural-language hint, or no argument at all. With no argument, `/gif` picks the newest video file across `~/Desktop/`, `~/Downloads/`, and `~/Movies/` — usually the recording you just made.

```
/gif                          # newest video across Desktop / Downloads / Movies
/gif ~/Desktop/demo.mov
/gif last screen recording
/gif latest recording on desktop
```

Output lands beside the source file with a context-derived name (e.g. `geo-chat-flow.gif`). Files over 10MB get a warning — GitHub's upload limit will reject them, and you'll want to either drop the framerate or crop the recording.

## License

MIT
