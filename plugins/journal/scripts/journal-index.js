#!/usr/bin/env node
/**
 * Manages the monthly index.json and tag registry for journal entries.
 *
 * Usage:
 *   journal-index.js upsert <index-path>              (entry JSON read from stdin)
 *   journal-index.js increment-media <index-path> <file-field>
 *   journal-index.js tags <journal-root>              (output tag registry as JSON)
 *   journal-index.js sync-tags <journal-root>         (rebuild tag registry from all indexes; recovery tool)
 *   journal-index.js sync-index <journal-root> [YYYY/MM]  (rebuild monthly index.json from entry files; recovery tool)
 *
 * upsert: Add or replace an entry matched by its "file" field. Reading from
 *   stdin avoids shell-quoting issues with summaries containing single quotes,
 *   backslashes, or other shell-special characters.
 * increment-media: Increment media_count for the entry matching <file-field>.
 * tags: Output the tag registry (frequency map) for the journal root.
 * sync-tags: Rebuild the tag registry by scanning every monthly index. Useful
 *   if the registry has drifted (e.g. after manual entry deletion).
 * sync-index: Rebuild monthly index.json files by scanning entry markdown on
 *   disk (all months, or just YYYY/MM). Entries on disk are authoritative —
 *   recovers an index row clobbered by a concurrent session.
 */

const fs = require("fs");
const path = require("path");

function readTags(tagsPath) {
  if (fs.existsSync(tagsPath)) {
    try {
      return JSON.parse(fs.readFileSync(tagsPath, "utf8"));
    } catch (e) {
      return {};
    }
  }
  return {};
}

function writeTags(tagsPath, tags) {
  // Sort by count descending for easy consumption
  const sorted = Object.fromEntries(
    Object.entries(tags).sort(([, a], [, b]) => b - a)
  );
  fs.writeFileSync(tagsPath, JSON.stringify(sorted, null, 2) + "\n");
}

function updateTagRegistry(indexPath, oldTags, newTags) {
  // Derive tags.json path from index: entries/YYYY/MM/index.json -> entries/../../../tags.json
  const entriesDir = path.dirname(path.dirname(path.dirname(indexPath)));
  const journalRoot = path.dirname(entriesDir);
  const tagsPath = path.join(journalRoot, "tags.json");
  const tags = readTags(tagsPath);

  for (const tag of oldTags) {
    if (tags[tag]) {
      tags[tag]--;
      if (tags[tag] <= 0) delete tags[tag];
    }
  }
  for (const tag of newTags) {
    tags[tag] = (tags[tag] || 0) + 1;
  }

  writeTags(tagsPath, tags);
}

function readIndex(indexPath, { strict = true } = {}) {
  if (fs.existsSync(indexPath)) {
    try {
      return JSON.parse(fs.readFileSync(indexPath, "utf8"));
    } catch (e) {
      if (strict) {
        console.error(`ERROR: Corrupt index file at ${indexPath}: ${e.message}`);
        process.exit(1);
      }
      console.error(`WARN: Skipping corrupt index ${indexPath}: ${e.message}`);
      return null;
    }
  }
  return { version: 1, entries: [] };
}

function writeIndex(indexPath, data) {
  fs.mkdirSync(path.dirname(indexPath), { recursive: true });
  fs.writeFileSync(indexPath, JSON.stringify(data, null, 2) + "\n");
}

function readStdin() {
  return fs.readFileSync(0, "utf8");
}

function unquote(s) {
  const t = s.trim();
  if (
    (t.startsWith('"') && t.endsWith('"')) ||
    (t.startsWith("'") && t.endsWith("'"))
  ) {
    return t.slice(1, -1);
  }
  return t;
}

function parseInlineArray(s) {
  const t = s.trim();
  const inner = t.replace(/^\[/, "").replace(/\]$/, "");
  if (!inner.trim()) return [];
  return inner
    .split(",")
    .map((x) => unquote(x))
    .filter((x) => x.length > 0);
}

// Parse a single entry markdown file into an index row. The frontmatter format
// is the plugin's own (see references/append.md Step 1), so a hand-rolled parser
// avoids a YAML dependency. Returns null if the file has no frontmatter block.
function parseEntryFile(filePath) {
  const raw = fs.readFileSync(filePath, "utf8");
  const lines = raw.split(/\r?\n/);
  if (lines[0].trim() !== "---") return null;
  let end = -1;
  for (let i = 1; i < lines.length; i++) {
    if (lines[i].trim() === "---") {
      end = i;
      break;
    }
  }
  if (end === -1) return null;

  const fm = lines.slice(1, end);
  const body = lines.slice(end + 1);

  let date = "";
  let time = "";
  let project = "";
  let tags = [];
  let hasMediaHints = false;
  let mediaCount = 0;
  let currentKey = null;

  for (const line of fm) {
    const topLevel = !/^\s/.test(line) && /^([\w-]+):\s?(.*)$/.exec(line);
    if (topLevel) {
      currentKey = topLevel[1];
      const val = topLevel[2];
      switch (currentKey) {
        case "date":
          date = unquote(val);
          break;
        case "time":
          time = unquote(val);
          break;
        case "project":
          project = unquote(val);
          break;
        case "tags":
          tags = parseInlineArray(val);
          break;
        case "media_hints":
          hasMediaHints = true;
          break;
      }
    } else if (currentKey === "media" && /^\s+-\s+/.test(line)) {
      mediaCount++;
    }
  }

  // Summary = first non-empty body paragraph, flattened to one line.
  let summary = "";
  let started = false;
  const para = [];
  for (const line of body) {
    if (line.trim() === "") {
      if (started) break;
      continue;
    }
    started = true;
    para.push(line.trim());
  }
  summary = para.join(" ").replace(/\s+/g, " ").trim();
  if (summary.length > 120) summary = summary.slice(0, 117).trimEnd() + "...";

  return {
    date,
    time,
    project,
    tags,
    summary,
    has_media_hints: hasMediaHints,
    media_count: mediaCount,
  };
}

function rebuildMonthIndex(journalRoot, ym) {
  const [year, month] = ym.split("/");
  const monthDir = path.join(journalRoot, "entries", year, month);
  if (!fs.existsSync(monthDir)) return null;
  const entries = [];
  const days = fs
    .readdirSync(monthDir)
    .filter(
      (d) =>
        /^\d{2}$/.test(d) && fs.statSync(path.join(monthDir, d)).isDirectory()
    );
  for (const dd of days) {
    const dayDir = path.join(monthDir, dd);
    const files = fs
      .readdirSync(dayDir)
      .filter(
        (f) =>
          f.endsWith(".md") && fs.statSync(path.join(dayDir, f)).isFile()
      );
    for (const f of files) {
      const parsed = parseEntryFile(path.join(dayDir, f));
      if (!parsed) continue;
      parsed.file = `${dd}/${f}`;
      entries.push(parsed);
    }
  }
  entries.sort((a, b) =>
    `${a.date} ${a.time}`.localeCompare(`${b.date} ${b.time}`)
  );
  writeIndex(path.join(monthDir, "index.json"), { version: 1, entries });
  return entries.length;
}

function discoverMonths(journalRoot) {
  const entriesDir = path.join(journalRoot, "entries");
  const months = [];
  if (!fs.existsSync(entriesDir)) return months;
  const years = fs
    .readdirSync(entriesDir)
    .filter(
      (d) =>
        /^\d{4}$/.test(d) && fs.statSync(path.join(entriesDir, d)).isDirectory()
    );
  for (const year of years) {
    const yearDir = path.join(entriesDir, year);
    const mDirs = fs
      .readdirSync(yearDir)
      .filter(
        (d) =>
          /^\d{2}$/.test(d) && fs.statSync(path.join(yearDir, d)).isDirectory()
      );
    for (const m of mDirs) months.push(`${year}/${m}`);
  }
  return months.sort();
}

const [, , command, ...rest] = process.argv;

if (!command) {
  console.error("Usage: journal-index.js {upsert|increment-media|tags|sync-tags|sync-index} ...");
  process.exit(1);
}

if (command === "upsert") {
  const [indexPath] = rest;
  if (!indexPath) {
    console.error("Usage: journal-index.js upsert <index-path>   (entry JSON read from stdin)");
    process.exit(1);
  }
  const input = readStdin();
  if (!input.trim()) {
    console.error("ERROR: No JSON entry received on stdin");
    process.exit(1);
  }
  let entry;
  try {
    entry = JSON.parse(input);
  } catch (e) {
    console.error(`ERROR: Invalid JSON on stdin: ${e.message}`);
    process.exit(1);
  }
  const required = ["date", "time", "project", "tags", "summary", "file"];
  const missing = required.filter((f) => !(f in entry));
  if (missing.length > 0) {
    console.error(`ERROR: Missing required fields: ${missing.join(", ")}`);
    process.exit(1);
  }
  const data = readIndex(indexPath);
  const existing = data.entries.find((e) => e.file === entry.file);
  const oldTags = existing ? existing.tags || [] : [];
  data.entries = data.entries.filter((e) => e.file !== entry.file);
  data.entries.push(entry);
  writeIndex(indexPath, data);
  updateTagRegistry(indexPath, oldTags, entry.tags || []);
  console.log(`OK: ${entry.file}`);
} else if (command === "increment-media") {
  const [indexPath, fileField] = rest;
  if (!indexPath || !fileField) {
    console.error("Usage: journal-index.js increment-media <index-path> <file-field>");
    process.exit(1);
  }
  const data = readIndex(indexPath);
  const entry = data.entries.find((e) => e.file === fileField);
  if (!entry) {
    const available = data.entries.map((e) => e.file).join(", ") || "(none)";
    console.error(`ERROR: No entry found matching file: ${fileField}`);
    console.error(`Available entries: ${available}`);
    process.exit(1);
  }
  entry.media_count = (entry.media_count || 0) + 1;
  writeIndex(indexPath, data);
  console.log(`OK: ${fileField} media_count=${entry.media_count}`);
} else if (command === "tags") {
  const [journalRoot] = rest;
  if (!journalRoot) {
    console.error("Usage: journal-index.js tags <journal-root>");
    process.exit(1);
  }
  const tagsPath = path.join(journalRoot, "tags.json");
  console.log(JSON.stringify(readTags(tagsPath), null, 2));
} else if (command === "sync-tags") {
  const [journalRoot] = rest;
  if (!journalRoot) {
    console.error("Usage: journal-index.js sync-tags <journal-root>");
    process.exit(1);
  }
  const entriesDir = path.join(journalRoot, "entries");
  const tags = {};
  if (fs.existsSync(entriesDir)) {
    const years = fs
      .readdirSync(entriesDir)
      .filter((d) => fs.statSync(path.join(entriesDir, d)).isDirectory());
    for (const year of years) {
      const yearDir = path.join(entriesDir, year);
      const months = fs
        .readdirSync(yearDir)
        .filter((d) => fs.statSync(path.join(yearDir, d)).isDirectory());
      for (const month of months) {
        const idxPath = path.join(yearDir, month, "index.json");
        if (fs.existsSync(idxPath)) {
          const data = readIndex(idxPath, { strict: false });
          if (!data) continue;
          for (const entry of data.entries || []) {
            for (const tag of entry.tags || []) {
              tags[tag] = (tags[tag] || 0) + 1;
            }
          }
        }
      }
    }
  }
  writeTags(path.join(journalRoot, "tags.json"), tags);
  console.log(`OK: ${Object.keys(tags).length} tags synced`);
} else if (command === "sync-index") {
  const [journalRoot, ym] = rest;
  if (!journalRoot) {
    console.error("Usage: journal-index.js sync-index <journal-root> [YYYY/MM]");
    process.exit(1);
  }
  let months;
  if (ym) {
    if (!/^\d{4}\/\d{2}$/.test(ym)) {
      console.error(`ERROR: Month must be YYYY/MM, got: ${ym}`);
      process.exit(1);
    }
    months = [ym];
  } else {
    months = discoverMonths(journalRoot);
  }
  if (months.length === 0) {
    console.error(`WARN: No months found under ${path.join(journalRoot, "entries")}`);
  }
  for (const month of months) {
    const count = rebuildMonthIndex(journalRoot, month);
    if (count === null) {
      console.error(`WARN: No entries directory for ${month}`);
      continue;
    }
    console.log(`OK: ${count} entries indexed for ${month}`);
  }
} else {
  console.error(`ERROR: Unknown command: ${command}`);
  process.exit(1);
}
