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
  if (!arg) {
    console.error("ERROR: Missing JSON entry argument for upsert");
    console.error("Usage: journal-index.js upsert <index-path> '<json-entry>'");
    process.exit(1);
  }
  let entry;
  try {
    entry = JSON.parse(arg);
  } catch (e) {
    console.error(`ERROR: Invalid JSON entry: ${e.message}`);
    console.error(`Received: ${arg}`);
    process.exit(1);
  }
  const required = ["date", "time", "project", "tags", "summary", "file"];
  const missing = required.filter((f) => !(f in entry));
  if (missing.length > 0) {
    console.error(`ERROR: Missing required fields: ${missing.join(", ")}`);
    console.error(`Required fields: ${required.join(", ")}`);
    process.exit(1);
  }
  const data = readIndex(indexPath);
  data.entries = data.entries.filter((e) => e.file !== entry.file);
  data.entries.push(entry);
  writeIndex(indexPath, data);
  console.log(`OK: ${entry.file}`);
} else if (command === "increment-media") {
  if (!arg) {
    console.error("ERROR: Missing file-field argument for increment-media");
    console.error("Usage: journal-index.js increment-media <index-path> <file-field>");
    process.exit(1);
  }
  const data = readIndex(indexPath);
  const entry = data.entries.find((e) => e.file === arg);
  if (!entry) {
    const available = data.entries.map((e) => e.file).join(", ") || "(none)";
    console.error(`ERROR: No entry found matching file: ${arg}`);
    console.error(`Available entries: ${available}`);
    process.exit(1);
  }
  entry.media_count = (entry.media_count || 0) + 1;
  writeIndex(indexPath, data);
  console.log(`OK: ${arg} media_count=${entry.media_count}`);
} else {
  console.error(`ERROR: Unknown command: ${command}`);
  process.exit(1);
}
