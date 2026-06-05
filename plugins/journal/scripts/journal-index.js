#!/usr/bin/env node
/**
 * Manages the monthly index.json and tag registry for journal entries.
 *
 * Usage:
 *   journal-index.js upsert <index-path>          (entry JSON read from stdin)
 *   journal-index.js increment-media <index-path> <file-field>
 *   journal-index.js tags <journal-root>          (output tag registry as JSON)
 *   journal-index.js sync-tags <journal-root>     (rebuild tag registry from all indexes; recovery tool)
 *
 * upsert: Add or replace an entry matched by its "file" field. Reading from
 *   stdin avoids shell-quoting issues with summaries containing single quotes,
 *   backslashes, or other shell-special characters.
 * increment-media: Increment media_count for the entry matching <file-field>.
 * tags: Output the tag registry (frequency map) for the journal root.
 * sync-tags: Rebuild the tag registry by scanning every monthly index. Useful
 *   if the registry has drifted (e.g. after manual entry deletion).
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

const [, , command, ...rest] = process.argv;

if (!command) {
  console.error("Usage: journal-index.js {upsert|increment-media|tags|sync-tags} ...");
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
} else {
  console.error(`ERROR: Unknown command: ${command}`);
  process.exit(1);
}
