#!/usr/bin/env node
/**
 * Generates a self-contained HTML recap report and opens it in the browser.
 *
 * Usage:
 *   journal-recap-html.js <recap-file.md>
 *
 * Reads the recap markdown file (with YAML frontmatter), converts it to
 * a styled HTML page, writes it alongside the .md file as .html, and
 * opens it in the default browser.
 */

const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

const recapPath = process.argv[2];
if (!recapPath || !fs.existsSync(recapPath)) {
  console.error("Usage: journal-recap-html.js <recap-file.md>");
  process.exit(1);
}

const raw = fs.readFileSync(recapPath, "utf8");

// Parse frontmatter
let meta = {};
let body = raw;
const fmMatch = raw.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
if (fmMatch) {
  const fmLines = fmMatch[1].split("\n");
  for (const line of fmLines) {
    const m = line.match(/^(\w+):\s*"?([^"]*)"?$/);
    if (m) meta[m[1]] = m[2];
  }
  body = fmMatch[2];
}

// Convert markdown to HTML (simple but sufficient)
function md(text) {
  let html = text
    // Code blocks
    .replace(/```(\w*)\n([\s\S]*?)```/g, '<pre><code class="lang-$1">$2</code></pre>')
    // Headers
    .replace(/^#### (.+)$/gm, '<h4>$1</h4>')
    .replace(/^### (.+)$/gm, '<h3>$1</h3>')
    .replace(/^## (.+)$/gm, '<h2>$1</h2>')
    // Bold
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    // Italic
    .replace(/\*(.+?)\*/g, '<em>$1</em>')
    // Inline code
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    // Unordered lists (handle nested)
    .replace(/^- (.+)$/gm, '<li>$1</li>')
    // Paragraphs (non-empty lines that aren't already tags)
    .replace(/^(?!<[hluop]|<li|<pre|<code)(.+)$/gm, '<p>$1</p>');

  // Wrap consecutive <li> in <ul>
  html = html.replace(/((?:<li>.*<\/li>\n?)+)/g, '<ul>$1</ul>');

  return html;
}

const from = meta.from || "?";
const to = meta.to || "?";
const generated = meta.generated || "?";
const project = meta.project || "all";
const entryCount = meta.entry_count || "?";

const htmlContent = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Recap: ${from} to ${to}</title>
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
  }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
    background: var(--bg);
    color: var(--text);
    line-height: 1.6;
    padding: 2rem;
    max-width: 900px;
    margin: 0 auto;
  }
  header {
    border-bottom: 1px solid var(--border);
    padding-bottom: 1.5rem;
    margin-bottom: 2rem;
  }
  header h1 {
    font-size: 1.75rem;
    font-weight: 600;
    color: var(--text);
    margin-bottom: 0.5rem;
  }
  .meta {
    display: flex;
    gap: 1.5rem;
    flex-wrap: wrap;
  }
  .meta-item {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    color: var(--text-muted);
    font-size: 0.875rem;
  }
  .meta-item .label { color: var(--text-muted); }
  .meta-item .value { color: var(--text); font-weight: 500; }
  h2 {
    font-size: 1.25rem;
    font-weight: 600;
    color: var(--accent);
    margin: 2rem 0 1rem 0;
    padding-bottom: 0.5rem;
    border-bottom: 1px solid var(--border);
  }
  h3 {
    font-size: 1.05rem;
    font-weight: 600;
    color: var(--text);
    margin: 1.25rem 0 0.5rem 0;
  }
  h4 {
    font-size: 0.95rem;
    font-weight: 600;
    color: var(--purple);
    margin: 1rem 0 0.5rem 0;
  }
  p {
    margin-bottom: 0.75rem;
    color: var(--text);
  }
  ul {
    list-style: none;
    margin-bottom: 1rem;
  }
  li {
    position: relative;
    padding: 0.5rem 0.75rem 0.5rem 1.5rem;
    margin-bottom: 0.25rem;
    background: var(--surface);
    border-radius: 6px;
    border-left: 3px solid var(--border);
  }
  li::before { display: none; }
  li:has(strong:first-child) {
    border-left-color: var(--accent);
  }
  strong { color: var(--accent); font-weight: 600; }
  em { color: var(--text-muted); font-style: italic; }
  code {
    background: var(--surface-raised);
    padding: 0.15rem 0.4rem;
    border-radius: 4px;
    font-size: 0.85em;
    font-family: 'SF Mono', 'Fira Code', monospace;
    color: var(--orange);
  }
  pre {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 1rem;
    overflow-x: auto;
    margin-bottom: 1rem;
  }
  pre code {
    background: none;
    padding: 0;
    color: var(--text);
  }
  .tag {
    display: inline-block;
    padding: 0.15rem 0.5rem;
    border-radius: 12px;
    font-size: 0.75rem;
    font-weight: 500;
    margin-right: 0.25rem;
  }
  .tag-blog { background: var(--orange-subtle); color: var(--orange); }
  .tag-demo { background: var(--purple-subtle); color: var(--purple); }
  .tag-reusable { background: var(--green-subtle); color: var(--green); }
  footer {
    margin-top: 3rem;
    padding-top: 1rem;
    border-top: 1px solid var(--border);
    color: var(--text-muted);
    font-size: 0.8rem;
    text-align: center;
  }
</style>
</head>
<body>
<header>
  <nav><a href="index.html" style="color:var(--accent);text-decoration:none;font-size:0.85rem">&larr; All recaps</a></nav>
  <h1>Journal Recap</h1>
  <div class="meta">
    <div class="meta-item"><span class="label">Period:</span> <span class="value">${from} &rarr; ${to}</span></div>
    <div class="meta-item"><span class="label">Entries:</span> <span class="value">${entryCount}</span></div>
    <div class="meta-item"><span class="label">Scope:</span> <span class="value">${project === "all" ? "All projects" : project}</span></div>
    <div class="meta-item"><span class="label">Generated:</span> <span class="value">${generated}</span></div>
  </div>
</header>
<main>
${md(body)}
</main>
<footer>
  Generated by journal plugin
</footer>
</body>
</html>
`;

const htmlPath = recapPath.replace(/\.md$/, ".html");
fs.writeFileSync(htmlPath, htmlContent);

// Open in browser
try {
  if (process.platform === "darwin") {
    execSync(`open "${htmlPath}"`);
  } else if (process.platform === "linux") {
    execSync(`xdg-open "${htmlPath}"`);
  } else {
    execSync(`start "" "${htmlPath}"`);
  }
  console.log(`OK: ${htmlPath}`);
} catch (e) {
  console.log(`OK: ${htmlPath} (open manually — browser launch failed)`);
}
