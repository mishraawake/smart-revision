// Checks the content sheet and writes the app's decks.
//
//   npm run export -- --file "RevUp content.xlsx"   a downloaded copy
//   npm run export -- --sheet <link or ID>          a sheet shared as
//                                                   "Anyone with the link"
//   add --check to only check, without writing anything.

import { readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArgs } from 'node:util';

import { buildDecks, formatDeck } from './decks.js';
import { readXlsx } from './xlsx.js';

const here = dirname(fileURLToPath(import.meta.url));
const { values: args } = parseArgs({
  options: {
    file: { type: 'string' },
    sheet: { type: 'string' },
    out: { type: 'string', default: join(here, '..', 'assets', 'decks') },
    check: { type: 'boolean', default: false },
  },
});

if (!args.file === !args.sheet) {
  console.error('Give either --file <downloaded .xlsx> or --sheet <Google Sheets link or ID>.');
  process.exit(2);
}

const workbook = args.file ? readFileSync(args.file) : await download(args.sheet);
const { tabs, dates } = readXlsx(workbook);
const { decks, errors, warnings } = buildDecks(tabs, { dates });

for (const w of warnings) console.warn(`warning: ${w}`);
for (const e of errors) console.error(`error:   ${e}`);

const summary = Object.values(decks).map((d) => {
  const cards = d.subjects.flatMap((s) => s.chapters).reduce((n, ch) => n + ch.cards.length, 0);
  return `Class ${d.classLevel}: ${d.subjects.length} subjects, ${cards} cards`;
});
console.log(summary.join('\n') || 'No live chapters.');

if (errors.length > 0) {
  console.error(`\n${errors.length} error${errors.length > 1 ? 's' : ''}: nothing was written. Fix them in the sheet and run again.`);
  process.exit(1);
}
if (args.check) {
  console.log(`\nAll good${warnings.length ? ` (${warnings.length} warnings)` : ''}. Nothing written (--check).`);
  process.exit(0);
}

// Replace the deck files, removing those of classes no longer in the sheet.
for (const f of readdirSync(args.out)) {
  if (/^class_\d+\.json$/.test(f)) rmSync(join(args.out, f));
}
for (const d of Object.values(decks)) {
  writeFileSync(join(args.out, `class_${d.classLevel}.json`), formatDeck(d));
}
console.log(`\nWrote ${Object.keys(decks).length} deck files to ${args.out}`);

async function download(sheet) {
  const id = /\/d\/([\w-]+)/.exec(sheet)?.[1] ?? sheet;
  const res = await fetch(`https://docs.google.com/spreadsheets/d/${id}/export?format=xlsx`);
  const body = Buffer.from(await res.arrayBuffer());
  // A private sheet answers with a sign-in page instead of a file.
  if (!res.ok || body.readUInt32LE(0) !== 0x04034b50) {
    console.error('Could not download the sheet. Share it as "Anyone with the link: Viewer", ' +
      'or use File → Download → Microsoft Excel and pass --file.');
    process.exit(1);
  }
  return body;
}
