// Adds the Class 5 Hindi reader (संगीत संकलन) chapters to the Collins Class 5
// content sheet. The whole reader was photographed (Google Photos album,
// 2026-10-28); each chapter's cards were written from its pages and live in
// hindi5_reader/chNN.json. Ch 4 (c5-hin-05) and Ch 10 (c5-hin-10) stay in
// collins5_lang.mjs. Safe to re-run: these chapters are replaced.
// Usage: node hindi5_reader.mjs <content dir> <in.xlsx> <out.xlsx>
import { readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { join, dirname } from 'node:path';

const [dir, inFile, outFile] = process.argv.slice(2);
const { readXlsx, writeXlsx } = await import(pathToFileURL(join(dir, 'xlsx.js')));
const { columns } = await import(pathToFileURL(join(dir, 'decks.js')));
const { tabs } = readXlsx(readFileSync(inFile));

const dataDir = join(dirname(fileURLToPath(import.meta.url)), 'hindi5_reader');
const book = 'Class 5 Hindi reader (संगीत संकलन)';

// Each file: { number, title, pages, pairs: [[left, right]], cards: [[level, front, back, [wrong],
// explain, tf_statement, tf_answer, blank_sentence, blank_answer]] }
const chapters = readdirSync(dataDir).filter((f) => /^ch\d+\.json$/.test(f)).sort()
  .map((f) => JSON.parse(readFileSync(join(dataDir, f), 'utf8')));

const ix = Object.fromEntries(columns.Cards.map((c, i) => [c, i]));
const ids = new Set();
const newChapters = [];
const cardRows = [];
const pairRows = [];
let total = 0;
for (const ch of chapters) {
  const id = `c5-hin-c${String(ch.number).padStart(2, '0')}`;
  ids.add(id);
  newChapters.push(['5', 'hindi', String(ch.number), ch.title, id, '']);
  ch.cards.forEach(([level, front, back, wrong, explain = '', tfS = '', tfA = '', blS = '', blA = ''], j) => {
    const row = columns.Cards.map(() => '');
    Object.assign(row, {
      [ix.chapter_id]: id, [ix.card_id]: `${id}-${String(j + 1).padStart(2, '0')}`, [ix.front]: front, [ix.back]: back,
      [ix.wrong_1]: wrong[0] ?? '', [ix.wrong_2]: wrong[1] ?? '', [ix.wrong_3]: wrong[2] ?? '',
      [ix.explain]: explain, [ix.tf_statement]: tfS, [ix.tf_answer]: tfA,
      [ix.blank_sentence]: blS, [ix.blank_answer]: blA, [ix.level]: String(level),
      [ix.source]: `${book}, Ch ${ch.number} (${ch.pages})`,
    });
    cardRows.push(row);
  });
  for (const [l, r] of ch.pairs) pairRows.push([id, l, r]);
  total += ch.cards.length;
  const levels = [1, 2, 3].map((n) => ch.cards.filter((c) => c[0] === n).length).join('/');
  console.log(`${id}  Ch ${ch.number} ${ch.title}: ${ch.cards.length} cards (${levels})`);
}

const subjects = tabs.Subjects;
const head = tabs.Chapters[0];
const subjectOrder = Object.fromEntries(subjects.slice(1).map((r) => [r[0], Number(r[2])]));
const chapterRows = [...tabs.Chapters.slice(1).filter((r) => !ids.has(r[4])), ...newChapters];
chapterRows.sort((a, b) => Number(a[0]) - Number(b[0]) ||
  (subjectOrder[a[1]] ?? 99) - (subjectOrder[b[1]] ?? 99) || Number(a[2]) - Number(b[2]));

const out = {
  'Read me': tabs['Read me'], Subjects: subjects, Chapters: [head, ...chapterRows],
  Cards: [...tabs.Cards.filter((r) => !ids.has(r[0])), ...cardRows],
  Pairs: [...tabs.Pairs.filter((r) => !ids.has(r[0])), ...pairRows],
};
const widths = {
  'Read me': [30, 110], Subjects: [14, 20, 8, 12, 12, 8], Chapters: [7, 12, 8, 40, 14, 10],
  Cards: columns.Cards.map((c) => ({ front: 50, back: 36, explain: 50, tf_statement: 40, blank_sentence: 40 }[c] ?? 16)),
  Pairs: [14, 30, 30],
};
writeFileSync(outFile, writeXlsx(out, { widths }));
console.log(`Total ${total} cards in ${newChapters.length} chapters`);
