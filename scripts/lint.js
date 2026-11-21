'use strict';

/**
 * Zero-dependency lint gate.
 *
 * The project intentionally keeps the existing stack and does not ship an
 * ESLint/TypeScript toolchain, so this script performs the checks that require
 * no new dependency:
 *   1. syntax check every first-party JavaScript file with `node --check`
 *   2. fail if any banned token (emoji or AI attribution) is found in source
 *
 * Run with: npm run lint
 */

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..');
const SCAN_DIRS = ['api', 'lib', 'test', 'scripts', 'src/app'];
const SKIP_DIRS = new Set(['node_modules', '.git', '.terraform']);

/** Recursively collect files matching the predicate. */
function walk(dir, predicate, acc) {
  acc = acc || [];
  if (!fs.existsSync(dir)) return acc;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (SKIP_DIRS.has(entry.name)) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, predicate, acc);
    else if (predicate(full)) acc.push(full);
  }
  return acc;
}

// Emoji / decorative symbol ranges that must never appear in source.
const BANNED = /[\u2600-\u27BF\u2B00-\u2BFF\uFE0F\u{1F300}-\u{1FAFF}]/u;
// Built from fragments so this file does not match its own pattern.
const AI_ATTRIBUTION = new RegExp(
  ['co-' + 'authored-by', 'generated with', 'claude', 'chatgpt', 'copilot'].join('|'),
  'i'
);

let failed = false;

const jsFiles = [];
for (const dir of SCAN_DIRS) {
  walk(path.join(ROOT, dir), function (file) { return file.endsWith('.js'); }, jsFiles);
}

for (const file of jsFiles) {
  try {
    execFileSync(process.execPath, ['--check', file], { stdio: 'pipe' });
  } catch (err) {
    failed = true;
    console.error('[syntax] ' + path.relative(ROOT, file));
    console.error(String(err.stderr || err.message));
  }
}

const textFiles = walk(ROOT, function (file) { return /\.(js|json|html|md|tpl|sh|ya?ml)$/.test(file); });
// Avoid scanning dependency trees; walk() already skips node_modules.
for (const file of textFiles) {
  const rel = path.relative(ROOT, file);
  if (rel.startsWith('.git')) continue;
  // This gate defines the banned patterns, so it is exempt from itself.
  if (rel === path.join('scripts', 'lint.js')) continue;
  const content = fs.readFileSync(file, 'utf8');
  content.split('\n').forEach(function (line, index) {
    if (BANNED.test(line)) {
      failed = true;
      console.error('[emoji] ' + rel + ':' + (index + 1) + ': ' + line.trim());
    }
    if (AI_ATTRIBUTION.test(line)) {
      failed = true;
      console.error('[attribution] ' + rel + ':' + (index + 1) + ': ' + line.trim());
    }
  });
}

if (failed) {
  console.error('\nlint failed');
  process.exit(1);
}
console.log('lint passed: ' + jsFiles.length + ' JS files syntax-checked, ' + textFiles.length + ' files scanned');
