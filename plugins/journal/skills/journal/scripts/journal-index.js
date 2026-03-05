#!/usr/bin/env node
/**
 * Manages the monthly index.json for journal entries.
 *
 * Usage:
 *   journal-index.js upsert <index-path> '<json-entry>'
 *   journal-index.js increment-media <index-path> <file-field>
 *
 * upsert: Add or replace an entry matched by its "file" field.
 * increment-media: Increment media_count for the entry matching <file-field>.
 */

const fs = require("fs");
const path = require("path");

function readIndex(indexPath) {
  if (fs.existsSync(indexPath)) {
    return JSON.parse(fs.readFileSync(indexPath, "utf8"));
  }
  return { version: 1, entries: [] };
}

function writeIndex(indexPath, data) {
  fs.mkdirSync(path.dirname(indexPath), { recursive: true });
  fs.writeFileSync(indexPath, JSON.stringify(data, null, 2) + "\n");
}

const [, , command, indexPath, arg] = process.argv;

if (!command || !indexPath) {
  console.error("Usage: journal-index.js {upsert|increment-media} <index-path> <arg>");
  process.exit(1);
}

if (command === "upsert") {
  const data = readIndex(indexPath);
  const entry = JSON.parse(arg);
  data.entries = data.entries.filter((e) => e.file !== entry.file);
  data.entries.push(entry);
  writeIndex(indexPath, data);
  console.log(`OK: ${entry.file}`);
} else if (command === "increment-media") {
  const data = readIndex(indexPath);
  const entry = data.entries.find((e) => e.file === arg);
  if (!entry) {
    console.error(`ERROR: No entry found matching file: ${arg}`);
    process.exit(1);
  }
  entry.media_count = (entry.media_count || 0) + 1;
  writeIndex(indexPath, data);
  console.log(`OK: ${arg} media_count=${entry.media_count}`);
} else {
  console.error(`ERROR: Unknown command: ${command}`);
  process.exit(1);
}
