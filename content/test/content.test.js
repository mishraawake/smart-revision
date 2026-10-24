import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import { buildDecks, columns, decksToTabs, formatDeck } from '../decks.js';
import { readXlsx, unzip, writeXlsx, zip } from '../xlsx.js';

const deckDir = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'assets', 'decks');
const appDecks = readdirSync(deckDir)
  .filter((f) => /^class_\d+\.json$/.test(f))
  .map((f) => JSON.parse(readFileSync(join(deckDir, f), 'utf8')))
  .sort((a, b) => a.classLevel - b.classLevel);

const withoutLooks = (deck) => ({
  ...deck,
  subjects: deck.subjects.map(({ colour, ink, glyph, ...s }) => s),
});

test('the app decks survive a trip through a workbook unchanged', () => {
  const xlsx = writeXlsx(decksToTabs(appDecks));
  const { tabs, dates } = readXlsx(xlsx);
  const { decks, errors } = buildDecks(tabs, { dates });
  assert.deepEqual(errors, []);
  assert.deepEqual(Object.values(decks).map(withoutLooks), appDecks.map(withoutLooks));
});

test('deck files are valid JSON with one line per card', () => {
  for (const deck of appDecks) {
    const text = formatDeck(deck);
    assert.deepEqual(JSON.parse(text), deck);
    const cards = deck.subjects.flatMap((s) => s.chapters).flatMap((ch) => ch.cards);
    for (const c of cards) assert.ok(text.includes(`{"id": ${JSON.stringify(c.id)}, `));
  }
});

test('text with quotes, commas and symbols is kept exactly', () => {
  const tricky = 'He said, "Wait"… 3 < 5 & ½ — ठीक है';
  const { tabs } = readXlsx(writeXlsx({ T: [['a'], [tricky]] }));
  assert.equal(tabs.T[1][0], tricky);
});

/** A minimal sheet; `edit` changes the rows before building. */
function sheet(edit = (t) => t) {
  const row = (tab, values) => columns[tab].map((c) => values[c] ?? '');
  return edit({
    Subjects: [columns.Subjects, row('Subjects', { subject_id: 'maths', name: 'Maths', order: '1', colour: '#ede9fe', ink: '#5B21B6', glyph: '12+' })],
    Chapters: [columns.Chapters, row('Chapters', { class: '2', subject_id: 'maths', number: '1', title: 'Counting', chapter_id: 'c2-m-01' })],
    Cards: [
      columns.Cards,
      row('Cards', { chapter_id: 'c2-m-01', card_id: 'a', front: 'Two plus two?', back: '4', wrong_1: '3', wrong_2: '5' }),
      row('Cards', { chapter_id: 'c2-m-01', card_id: 'b', front: 'Is 3 odd?', back: 'Yes', tf_statement: '3 is odd.', tf_answer: 'TRUE', level: '1' }),
    ],
    Pairs: [columns.Pairs, row('Pairs', { chapter_id: 'c2-m-01', left: 'Two', right: '2' })],
  });
}

test('builds a deck with subject looks, pairs and card extras', () => {
  const { decks, errors } = buildDecks(sheet());
  assert.deepEqual(errors, []);
  const s = decks[2].subjects[0];
  assert.deepEqual([s.colour, s.ink, s.glyph], ['#EDE9FE', '#5B21B6', '12+']);
  assert.deepEqual(s.chapters[0].pairs, [['Two', '2']]);
  assert.deepEqual(s.chapters[0].cards[1], {
    id: 'b', front: 'Is 3 odd?', back: 'Yes', tf: { text: '3 is odd.', answer: true }, level: 1,
  });
});

test('draft cards and chapters are left out', () => {
  const { decks } = buildDecks(sheet((t) => {
    t.Cards[1][columns.Cards.indexOf('status')] = 'Draft';
    return t;
  }));
  assert.deepEqual(decks[2].subjects[0].chapters[0].cards.map((c) => c.id), ['b']);

  const hidden = buildDecks(sheet((t) => {
    t.Chapters[1][columns.Chapters.indexOf('status')] = 'draft';
    return t;
  }));
  assert.deepEqual(hidden.decks, {});
});

test('mistakes are reported with their row', () => {
  const { errors } = buildDecks(sheet((t) => {
    t.Cards[2][columns.Cards.indexOf('card_id')] = 'a'; // duplicate
    t.Cards.push(columns.Cards.map((c) => ({ chapter_id: 'nope', card_id: 'c', front: 'Q', back: 'A' }[c] ?? '')));
    t.Cards.push(columns.Cards.map((c) => ({ chapter_id: 'c2-m-01', card_id: 'd', front: 'Q', back: 'A', wrong_1: 'a' }[c] ?? '')));
    t.Cards.push(columns.Cards.map((c) => ({ chapter_id: 'c2-m-01', card_id: 'e', front: 'Q', back: 'A', blank_sentence: 'No gap', blank_answer: 'x' }[c] ?? '')));
    return t;
  }));
  assert.deepEqual(errors, [
    'Cards row 3: card_id "a" is used twice',
    'Cards row 4: chapter_id "nope" is not on the Chapters tab',
    'Cards row 5: a wrong answer is the same as the right answer "A"',
    'Cards row 6: blank_sentence needs a gap written as ___ (three underscores)',
  ]);
});

test('warns about flashcards that ask to choose from unseen options', () => {
  const { warnings } = buildDecks(sheet((t) => {
    t.Cards[1][columns.Cards.indexOf('front')] = 'Which of these is even?';
    t.Cards[2][columns.Cards.indexOf('front')] = 'Which one is a vowel: b, e or t?';
    return t;
  }));
  assert.deepEqual(warnings, ['Cards row 2: "Which of these is even?" asks to choose from options a flashcard doesn\'t show']);
});

test('cells Sheets turned into dates are errors', () => {
  const { errors } = buildDecks(sheet(), { dates: [{ tab: 'Cards', row: 1, col: 3 }] });
  assert.match(errors[0], /^Cards row 2, column D: Sheets turned this into a date/);
});

test('a date-formatted number cell in a downloaded workbook is detected', () => {
  // A workbook as Google writes it: a numeric cell with a date style.
  const plain = writeXlsx({ Cards: [['back'], ['x']] });
  const { tabs } = readXlsx(plain);
  assert.equal(tabs.Cards[1][0], 'x');
  const dated = patchFirstCellToDate(plain);
  assert.deepEqual(readXlsx(dated).dates, [{ tab: 'Cards', row: 1, col: 0 }]);
});

/** Rewrites the workbook so cell A2 is the number 45293 in date format 14. */
function patchFirstCellToDate(xlsx) {
  const files = unzip(xlsx);
  const edit = (path, fn) => files.set(path, Buffer.from(fn(files.get(path).toString())));
  edit('xl/styles.xml', (s) => s
    .replace('<cellXfs count="3">', '<cellXfs count="4">')
    .replace('</cellXfs>', '<xf numFmtId="14" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/></cellXfs>'));
  edit('xl/worksheets/sheet1.xml', (s) => s.replace(/<c r="A2"[\s\S]*?<\/c>/,'<c r="A2" s="3"><v>45293</v></c>'));
  return zip([...files]);
}
