#!/usr/bin/env node
/**
 * Manages the monthly index.json for journal entries.
 *
 * Usage:
 *   journal-index.js upsert <index-path> '<json-entry>'
 *   journal-index.js increment-media <index-path> <file-field>
 *   journal-index.js list <index-path> [--from YYYY-MM-DD] [--to YYYY-MM-DD] [--project name] [--tag name]
 *
 * upsert: Add or replace an entry matched by its "file" field.
 * increment-media: Increment media_count for the entry matching <file-field>.
 * list: Filter and return entries as JSON. Accepts multiple index paths (comma-separated).
 */

const fs = require("fs");
const path = require("path");

function readIndex(indexPath) {
  if (fs.existsSync(indexPath)) {
    try {
      return JSON.parse(fs.readFileSync(indexPath, "utf8"));
    } catch (e) {
      console.error(`ERROR: Corrupt index file at ${indexPath}: ${e.message}`);
      process.exit(1);
    }
  }
  return { version: 1, entries: [] };
}

function writeIndex(indexPath, data) {
  fs.mkdirSync(path.dirname(indexPath), { recursive: true });
  fs.writeFileSync(indexPath, JSON.stringify(data, null, 2) + "\n");
}

const [, , command, indexPath, arg] = process.argv;

if (!command || !indexPath) {
  console.error("Usage: journal-index.js {upsert|increment-media|list} <index-path> <arg>");
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
} else if (command === "list") {
  // indexPath can be comma-separated for multiple index files
  const paths = indexPath.split(",").map((p) => p.trim());
  const args = process.argv.slice(4);
  const filters = {};
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--from" && args[i + 1]) filters.from = args[++i];
    else if (args[i] === "--to" && args[i + 1]) filters.to = args[++i];
    else if (args[i] === "--project" && args[i + 1]) filters.project = args[++i];
    else if (args[i] === "--tag" && args[i + 1]) filters.tag = args[++i];
  }
  let entries = [];
  for (const p of paths) {
    if (fs.existsSync(p)) {
      let data;
      try {
        data = JSON.parse(fs.readFileSync(p, "utf8"));
      } catch (e) {
        console.error(`WARNING: Skipping corrupt index file ${p}: ${e.message}`);
        continue;
      }
      const dir = path.basename(path.dirname(p));
      const month = path.basename(path.dirname(path.dirname(p)));
      const indexDir = path.dirname(p);
      entries.push(
        ...(data.entries || []).map((e) => ({
          ...e,
          _index: p,
          _month: `${month}/${dir}`,
          _path: path.join(indexDir, e.file),
        }))
      );
    }
  }
  if (filters.from) entries = entries.filter((e) => e.date >= filters.from);
  if (filters.to) entries = entries.filter((e) => e.date <= filters.to);
  if (filters.project)
    entries = entries.filter(
      (e) => e.project.toLowerCase() === filters.project.toLowerCase()
    );
  if (filters.tag)
    entries = entries.filter(
      (e) => Array.isArray(e.tags) && e.tags.includes(filters.tag)
    );
  entries.sort((a, b) => (a.date + a.time).localeCompare(b.date + b.time));
  console.log(JSON.stringify(entries, null, 2));
} else {
  console.error(`ERROR: Unknown command: ${command}`);
  process.exit(1);
}
