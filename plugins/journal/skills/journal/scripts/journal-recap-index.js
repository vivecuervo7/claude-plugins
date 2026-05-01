#!/usr/bin/env node
/**
 * Generates a recap dashboard (index.html) from all recap files and entry indexes.
 *
 * Usage:
 *   journal-recap-index.js <journal-root> [--open]
 *
 * Scans recaps/ for .md files, reads entry indexes for flagged items
 * (including full entry content), and generates recaps/index.html.
 * With --open, launches in the default browser.
 */

const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

const journalRoot = process.argv[2];
const shouldOpen = process.argv.includes("--open");

if (!journalRoot) {
  console.error("Usage: journal-recap-index.js <journal-root> [--open]");
  process.exit(1);
}

const recapsDir = path.join(journalRoot, "recaps");
const entriesDir = path.join(journalRoot, "entries");

// ── Helpers ──

function esc(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function parseFrontmatter(filePath) {
  const raw = fs.readFileSync(filePath, "utf8");
  const m = raw.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!m) return { meta: {}, body: raw };
  const meta = {};
  for (const line of m[1].split("\n")) {
    const kv = line.match(/^(\w+):\s*"?([^"]*)"?$/);
    if (kv) meta[kv[1]] = kv[2];
  }
  return { meta, body: m[2] };
}

// Simple markdown to HTML
function md(text) {
  let html = text
    .replace(/```(\w*)\n([\s\S]*?)```/g, '<pre><code class="lang-$1">$2</code></pre>')
    .replace(/^#### (.+)$/gm, "<h4>$1</h4>")
    .replace(/^### (.+)$/gm, "<h3>$1</h3>")
    .replace(/^## (.+)$/gm, "<h2>$1</h2>")
    .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
    .replace(/\*(.+?)\*/g, "<em>$1</em>")
    .replace(/`([^`]+)`/g, "<code>$1</code>")
    .replace(/^- \[x\] (.+)$/gm, '<li class="checked">$1</li>')
    .replace(/^- \[ \] (.+)$/gm, '<li class="unchecked">$1</li>')
    .replace(/^- (.+)$/gm, "<li>$1</li>")
    .replace(/^(?!<[hluop]|<li|<pre|<code)(.+)$/gm, "<p>$1</p>");
  html = html.replace(/((?:<li[^>]*>.*<\/li>\n?)+)/g, "<ul>$1</ul>");
  return html;
}

function formatDateRange(from, to) {
  const f = new Date(from + "T00:00:00");
  const t = new Date(to + "T00:00:00");
  const months = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
  ];
  if (f.getMonth() === t.getMonth()) {
    return `${months[f.getMonth()]} ${f.getDate()}–${t.getDate()}`;
  }
  return `${months[f.getMonth()]} ${f.getDate()} – ${months[t.getMonth()]} ${t.getDate()}`;
}

function daysAgo(dateStr) {
  const d = new Date(dateStr + "T00:00:00");
  const now = new Date();
  now.setHours(0, 0, 0, 0);
  return Math.floor((now - d) / 86400000);
}

function relativeDate(dateStr) {
  const d = daysAgo(dateStr);
  if (d === 0) return "today";
  if (d === 1) return "yesterday";
  if (d < 7) return `${d} days ago`;
  if (d < 14) return "last week";
  if (d < 30) return `${Math.floor(d / 7)} weeks ago`;
  if (d < 60) return "last month";
  return `${Math.floor(d / 30)} months ago`;
}

// Extract sections from entry body for blog-worthy display
function extractBlogSections(body) {
  const sections = {};
  const sectionRegex = /### (Blog Angle|Key Code|Context|Media Needed)\n([\s\S]*?)(?=\n### |\n## |$)/g;
  let match;
  while ((match = sectionRegex.exec(body)) !== null) {
    sections[match[1]] = match[2].trim();
  }
  // Also get the first paragraph as the main summary
  const firstPara = body.split("\n\n")[0];
  if (firstPara && !firstPara.startsWith("#")) {
    sections._summary = firstPara.trim();
  }
  return sections;
}

function extractHighlights(body) {
  const m = body.match(/### Highlights\n([\s\S]*?)(?=\n### |\n## |$)/);
  if (m) {
    return m[1]
      .split("\n")
      .filter((l) => l.startsWith("- "))
      .map((l) => l.slice(2).trim());
  }
  return [];
}

function extractProjects(body) {
  return [...body.matchAll(/#### (.+)/g)].map((m) => m[1].trim());
}

// ── Data Collection ──

// Collect all recaps with full bodies
const recaps = [];
if (fs.existsSync(recapsDir)) {
  const files = fs
    .readdirSync(recapsDir)
    .filter((f) => f.endsWith(".md"))
    .sort()
    .reverse();
  for (const file of files) {
    const filePath = path.join(recapsDir, file);
    const { meta, body } = parseFrontmatter(filePath);
    const htmlFile = file.replace(/\.md$/, ".html");
    const hasHtml = fs.existsSync(path.join(recapsDir, htmlFile));
    recaps.push({
      file,
      htmlFile: hasHtml ? htmlFile : null,
      from: meta.from || "?",
      to: meta.to || "?",
      generated: meta.generated || "?",
      project: meta.project || "all",
      entryCount: meta.entry_count || "?",
      highlights: extractHighlights(body),
      projects: extractProjects(body),
      body,
    });
  }
}

// Collect flagged entries with full content from entry files
const flaggedEntries = [];
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
      if (!fs.existsSync(idxPath)) continue;
      let data;
      try {
        data = JSON.parse(fs.readFileSync(idxPath, "utf8"));
      } catch (e) {
        continue;
      }
      for (const entry of data.entries || []) {
        const tags = entry.tags || [];
        const flags = tags.filter((t) =>
          ["blog-worthy", "demo-worthy", "reusable"].includes(t)
        );
        if (flags.length === 0) continue;

        // Read the full entry file for rich content
        const entryPath = path.join(yearDir, month, entry.file);
        let blogSections = {};
        let fullBody = "";
        if (fs.existsSync(entryPath)) {
          const { body } = parseFrontmatter(entryPath);
          fullBody = body;
          blogSections = extractBlogSections(body);
        }

        flaggedEntries.push({
          date: entry.date,
          project: entry.project,
          summary: entry.summary,
          flags,
          allTags: tags.filter(
            (t) => !["blog-worthy", "demo-worthy", "reusable"].includes(t)
          ),
          mediaCount: entry.media_count || 0,
          hasMediaHints: entry.has_media_hints || false,
          blogSections,
          fullBody,
        });
      }
    }
  }
}
flaggedEntries.sort((a, b) => b.date.localeCompare(a.date));

// ── HTML Generation ──

const latest = recaps[0];

const latestHtml = latest
  ? `
  <section class="current">
    <h2>Latest Recap</h2>
    <div class="recap-card featured">
      <div class="card-header">
        <span class="date-range">${esc(formatDateRange(latest.from, latest.to))}</span>
        <span class="meta-pill">${esc(latest.entryCount)} entries</span>
        ${latest.projects.map((p) => `<span class="meta-pill project">${esc(p)}</span>`).join("")}
      </div>
      <ul class="highlights">
        ${latest.highlights.map((h) => `<li>${esc(h)}</li>`).join("\n        ")}
      </ul>
      <details class="recap-expand">
        <summary>Show full recap</summary>
        <div class="recap-body">
          ${md(latest.body)}
        </div>
      </details>
      ${latest.htmlFile ? `<a class="view-link" href="${esc(latest.htmlFile)}">Open standalone view &rarr;</a>` : ""}
    </div>
  </section>`
  : "";

// Group flagged entries by type for better organization
const blogWorthy = flaggedEntries.filter((e) =>
  e.flags.includes("blog-worthy")
);
const demoWorthy = flaggedEntries.filter(
  (e) => e.flags.includes("demo-worthy") && !e.flags.includes("blog-worthy")
);
const reusable = flaggedEntries.filter(
  (e) =>
    e.flags.includes("reusable") &&
    !e.flags.includes("blog-worthy") &&
    !e.flags.includes("demo-worthy")
);

function renderFlaggedGroup(entries, label, description) {
  if (entries.length === 0) return "";
  return `
    <div class="flagged-group">
      <h3>${label} <span class="group-count">${entries.length}</span></h3>
      <p class="section-desc">${description}</p>
      ${entries
        .map((e) => {
          const age = relativeDate(e.date);
          const hasBlogAngle = e.blogSections["Blog Angle"];
          const hasKeyCode = e.blogSections["Key Code"];
          const hasContext = e.blogSections["Context"];
          const hasMediaNeeded = e.blogSections["Media Needed"];
          const mainSummary =
            e.blogSections._summary || e.summary;

          const detailSections = [];
          if (hasBlogAngle)
            detailSections.push(
              `<div class="detail-section"><h4>Blog Angle</h4>${md(hasBlogAngle)}</div>`
            );
          if (hasKeyCode)
            detailSections.push(
              `<div class="detail-section"><h4>Key Code</h4>${md(hasKeyCode)}</div>`
            );
          if (hasContext)
            detailSections.push(
              `<div class="detail-section"><h4>Context</h4>${md(hasContext)}</div>`
            );
          if (hasMediaNeeded)
            detailSections.push(
              `<div class="detail-section"><h4>Media Needed</h4>${md(hasMediaNeeded)}</div>`
            );
          // If no structured blog sections, show the full body
          if (detailSections.length === 0 && e.fullBody) {
            detailSections.push(
              `<div class="detail-section">${md(e.fullBody)}</div>`
            );
          }

          return `
      <div class="flagged-item">
        <div class="flagged-header">
          <span class="flagged-date">${esc(e.date)}</span>
          <span class="flagged-age">${esc(age)}</span>
          <span class="flagged-project">${esc(e.project)}</span>
          ${e.flags.map((f) => `<span class="tag tag-${f === "blog-worthy" ? "blog" : f === "demo-worthy" ? "demo" : "reusable"}">${esc(f)}</span>`).join("")}
          ${e.allTags.slice(0, 3).map((t) => `<span class="tag tag-topic">${esc(t)}</span>`).join("")}
          ${e.hasMediaHints && e.mediaCount === 0 ? '<span class="media-pending">needs media</span>' : ""}
        </div>
        <div class="flagged-summary">${esc(mainSummary)}</div>
        ${
          detailSections.length > 0
            ? `<details class="entry-expand">
          <summary>View details</summary>
          <div class="entry-details">
            ${detailSections.join("\n")}
          </div>
        </details>`
            : ""
        }
      </div>`;
        })
        .join("\n")}
    </div>`;
}

const writeAboutHtml =
  flaggedEntries.length > 0
    ? `
  <section class="write-about">
    <h2>Write About</h2>
    ${renderFlaggedGroup(blogWorthy, "Blog-worthy", "Entries with insights, patterns, or stories worth publishing")}
    ${renderFlaggedGroup(demoWorthy, "Demo-worthy", "Visually impressive or user-facing work worth showing off")}
    ${renderFlaggedGroup(reusable, "Reusable", "Patterns and techniques extractable for other projects")}
  </section>`
    : "";

const archiveRecaps = recaps.slice(1);
const archiveHtml =
  archiveRecaps.length > 0
    ? `
  <section class="archive">
    <h2>Previous Weeks</h2>
    <div class="archive-grid">
      ${archiveRecaps
        .map(
          (r) => `
      <div class="recap-card">
        <div class="card-header">
          <span class="date-range">${esc(formatDateRange(r.from, r.to))}</span>
          <span class="meta-pill">${esc(r.entryCount)} entries</span>
        </div>
        <div class="card-projects">${r.projects.map((p) => esc(p)).join(", ") || ""}</div>
        <ul class="highlights compact">
          ${r.highlights
            .slice(0, 2)
            .map((h) => `<li>${esc(h)}</li>`)
            .join("\n          ")}
        </ul>
        <details class="recap-expand compact">
          <summary>Expand</summary>
          <div class="recap-body compact">
            ${md(r.body)}
          </div>
        </details>
        ${r.htmlFile ? `<a class="view-link" href="${esc(r.htmlFile)}">Standalone &rarr;</a>` : ""}
      </div>`
        )
        .join("\n")}
    </div>
  </section>`
    : "";

const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Journal Recaps</title>
<style>
  :root {
    --bg: #0d1117;
    --surface: #161b22;
    --surface-raised: #1c2129;
    --border: #30363d;
    --text: #e6edf3;
    --text-muted: #8b949e;
    --accent: #58a6ff;
    --accent-subtle: rgba(88, 166, 255, 0.1);
    --green: #3fb950;
    --green-subtle: rgba(63, 185, 80, 0.1);
    --orange: #d29922;
    --orange-subtle: rgba(210, 153, 34, 0.1);
    --purple: #bc8cff;
    --purple-subtle: rgba(188, 140, 255, 0.1);
    --red: #f85149;
    --red-subtle: rgba(248, 81, 73, 0.1);
    --cyan: #39d2c0;
    --cyan-subtle: rgba(57, 210, 192, 0.1);
  }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
    background: var(--bg);
    color: var(--text);
    line-height: 1.6;
    padding: 2rem;
    max-width: 960px;
    margin: 0 auto;
  }
  header { margin-bottom: 2rem; padding-bottom: 1.5rem; border-bottom: 1px solid var(--border); }
  header h1 { font-size: 1.75rem; font-weight: 600; }
  header .subtitle { color: var(--text-muted); font-size: 0.9rem; margin-top: 0.25rem; }

  section { margin-bottom: 2.5rem; }
  section > h2 {
    font-size: 1.25rem; font-weight: 600; color: var(--accent);
    margin-bottom: 1rem; padding-bottom: 0.5rem; border-bottom: 1px solid var(--border);
  }
  h3 { font-size: 1rem; font-weight: 600; color: var(--text); margin: 1.25rem 0 0.25rem 0; }
  h4 { font-size: 0.9rem; font-weight: 600; color: var(--purple); margin: 0.75rem 0 0.35rem 0; }
  .section-desc { color: var(--text-muted); font-size: 0.825rem; margin-bottom: 0.75rem; }
  .group-count {
    font-size: 0.75rem; color: var(--text-muted); font-weight: 400;
    background: var(--surface-raised); padding: 0.1rem 0.5rem; border-radius: 10px;
    border: 1px solid var(--border); vertical-align: middle;
  }

  /* Cards */
  .recap-card {
    background: var(--surface); border: 1px solid var(--border);
    border-radius: 8px; padding: 1.25rem; margin-bottom: 0.75rem;
    transition: border-color 0.15s;
  }
  .recap-card:hover { border-color: var(--accent); }
  .recap-card.featured {
    border-color: var(--accent);
    background: linear-gradient(135deg, var(--surface) 0%, var(--accent-subtle) 100%);
  }
  .card-header {
    display: flex; align-items: center; gap: 0.5rem;
    flex-wrap: wrap; margin-bottom: 0.75rem;
  }
  .date-range { font-weight: 600; font-size: 1.05rem; color: var(--text); }
  .meta-pill {
    font-size: 0.75rem; padding: 0.15rem 0.5rem; border-radius: 12px;
    background: var(--surface-raised); color: var(--text-muted); border: 1px solid var(--border);
  }
  .meta-pill.project { color: var(--purple); border-color: var(--purple); background: var(--purple-subtle); }
  .card-projects { color: var(--text-muted); font-size: 0.85rem; margin-bottom: 0.5rem; }

  .highlights { list-style: none; margin-bottom: 0.75rem; }
  .highlights li {
    padding: 0.35rem 0.75rem; margin-bottom: 0.25rem;
    border-left: 2px solid var(--border); color: var(--text); font-size: 0.9rem;
  }
  .highlights.compact li { font-size: 0.85rem; color: var(--text-muted); }

  .view-link {
    color: var(--accent); text-decoration: none;
    font-size: 0.85rem; font-weight: 500; display: inline-block; margin-top: 0.5rem;
  }
  .view-link:hover { text-decoration: underline; }

  /* Expandable sections */
  details { margin-top: 0.75rem; }
  details summary {
    cursor: pointer; color: var(--accent); font-size: 0.85rem;
    font-weight: 500; padding: 0.35rem 0; user-select: none;
    list-style: none;
  }
  details summary::before {
    content: '\\25B6'; display: inline-block; margin-right: 0.4rem;
    font-size: 0.65rem; transition: transform 0.15s; vertical-align: middle;
  }
  details[open] summary::before { transform: rotate(90deg); }
  details summary::-webkit-details-marker { display: none; }

  .recap-body, .entry-details {
    margin-top: 0.75rem; padding: 1rem; background: var(--surface-raised);
    border: 1px solid var(--border); border-radius: 6px;
  }
  .recap-body.compact { font-size: 0.875rem; }
  .recap-body p, .entry-details p { margin-bottom: 0.5rem; font-size: 0.9rem; }
  .recap-body h2, .entry-details h2 {
    font-size: 1rem; color: var(--accent); margin: 1rem 0 0.5rem; padding: 0; border: 0;
  }
  .recap-body h3, .entry-details h3 { font-size: 0.925rem; margin: 0.75rem 0 0.35rem; }
  .recap-body h4, .entry-details h4 { font-size: 0.875rem; margin: 0.5rem 0 0.25rem; }
  .recap-body ul, .entry-details ul { list-style: none; margin-bottom: 0.5rem; }
  .recap-body li, .entry-details li {
    padding: 0.3rem 0.6rem; margin-bottom: 0.2rem; font-size: 0.875rem;
    border-left: 2px solid var(--border); background: transparent;
    border-radius: 0;
  }
  .recap-body strong, .entry-details strong { color: var(--accent); }
  .recap-body code, .entry-details code {
    background: var(--bg); padding: 0.1rem 0.35rem; border-radius: 3px;
    font-size: 0.8em; color: var(--orange); font-family: 'SF Mono', 'Fira Code', monospace;
  }
  .recap-body pre, .entry-details pre {
    background: var(--bg); border: 1px solid var(--border); border-radius: 6px;
    padding: 0.75rem; overflow-x: auto; margin-bottom: 0.75rem;
  }
  .recap-body pre code, .entry-details pre code {
    background: none; padding: 0; color: var(--text);
  }
  .detail-section { margin-bottom: 1rem; }
  .detail-section:last-child { margin-bottom: 0; }
  li.checked { border-left-color: var(--green); }
  li.checked::after { content: ' ✓'; color: var(--green); font-size: 0.75rem; }
  li.unchecked { border-left-color: var(--orange); opacity: 0.8; }

  /* Archive grid */
  .archive-grid {
    display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 0.75rem;
  }

  /* Flagged items */
  .flagged-group { margin-bottom: 1.5rem; }
  .flagged-item {
    background: var(--surface); border: 1px solid var(--border);
    border-radius: 8px; padding: 1rem; margin-bottom: 0.5rem;
    transition: border-color 0.15s;
  }
  .flagged-item:hover { border-color: var(--accent); }
  .flagged-header {
    display: flex; align-items: center; gap: 0.4rem;
    flex-wrap: wrap; margin-bottom: 0.5rem;
  }
  .flagged-date { font-size: 0.8rem; color: var(--text-muted); font-family: 'SF Mono', monospace; }
  .flagged-age { font-size: 0.75rem; color: var(--text-muted); }
  .flagged-project { font-size: 0.8rem; color: var(--purple); font-weight: 500; }
  .flagged-summary { font-size: 0.875rem; color: var(--text); line-height: 1.5; }
  .media-pending {
    font-size: 0.7rem; padding: 0.1rem 0.4rem; border-radius: 8px;
    background: var(--red-subtle); color: var(--red);
  }
  .tag {
    display: inline-block; padding: 0.1rem 0.45rem;
    border-radius: 10px; font-size: 0.7rem; font-weight: 500;
  }
  .tag-blog { background: var(--orange-subtle); color: var(--orange); }
  .tag-demo { background: var(--purple-subtle); color: var(--purple); }
  .tag-reusable { background: var(--green-subtle); color: var(--green); }
  .tag-topic { background: var(--cyan-subtle); color: var(--cyan); }

  footer {
    margin-top: 3rem; padding-top: 1rem; border-top: 1px solid var(--border);
    color: var(--text-muted); font-size: 0.8rem; text-align: center;
  }
  .empty { text-align: center; padding: 2rem; color: var(--text-muted); }
</style>
</head>
<body>
<header>
  <h1>Journal Recaps</h1>
  <div class="subtitle">${recaps.length} recap${recaps.length !== 1 ? "s" : ""} &middot; ${flaggedEntries.length} flagged entries</div>
</header>

${latestHtml || '<section class="empty"><p>No recaps yet. Run <code>/journal recap</code> to generate your first one.</p></section>'}

${writeAboutHtml}

${archiveHtml}

<footer>Generated by journal plugin</footer>
</body>
</html>
`;

const indexPath = path.join(recapsDir, "index.html");
fs.mkdirSync(recapsDir, { recursive: true });
fs.writeFileSync(indexPath, html);

if (shouldOpen) {
  try {
    if (process.platform === "darwin") {
      execSync(`open "${indexPath}"`);
    } else if (process.platform === "linux") {
      execSync(`xdg-open "${indexPath}"`);
    } else {
      execSync(`start "" "${indexPath}"`);
    }
  } catch (e) {
    /* browser launch failed, file still written */
  }
}

console.log(`OK: ${indexPath}`);
