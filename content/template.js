// Writes out/RevUp content.xlsx from the decks in assets/decks, to upload to
// Google Drive and open as the content sheet. Run once to start the sheet;
// after that the sheet is the source and `npm run export` writes the decks.

import { mkdirSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { columns, decksToTabs } from './decks.js';
import { writeXlsx } from './xlsx.js';

const here = dirname(fileURLToPath(import.meta.url));
const deckDir = join(here, '..', 'assets', 'decks');

// The app's built-in subject colours (lib/theme/tokens.dart), so the sheet
// starts with them filled in.
const styles = {
  english: { colour: '#DBEAFE', ink: '#1E40AF', glyph: 'Ab' },
  maths: { colour: '#EDE9FE', ink: '#5B21B6', glyph: '12+' },
  evs: { colour: '#CCFBF1', ink: '#115E59', glyph: 'EVS' },
  science: { colour: '#CFFAFE', ink: '#155E75', glyph: 'Sc' },
  social: { colour: '#FEF3C7', ink: '#92400E', glyph: 'SS' },
};

const readMe = [
  ['RevUp content sheet'],
  [''],
  ['Each tab has its column names in row 1. Do not rename or move the tabs Subjects, Chapters, Cards and Pairs. Extra tabs (like this one) are ignored.'],
  ['IDs (subject_id, chapter_id, card_id) are how the app remembers a student\'s progress. Never change or reuse one. New rows need new IDs.'],
  ['To hide a chapter or card without deleting it, set status to draft.'],
  ['Every column is plain text, so 1/2 stays 1/2. If you add a column, set it to Format → Number → Plain text first.'],
  [''],
  ['Subjects'],
  ['subject_id', 'Short and lowercase: maths, english, evs, science, social, hindi'],
  ['name', 'Shown in the app: Social Science'],
  ['order', 'Position on the Subjects screen: 1 comes first'],
  ['colour, ink', 'Card background and text colour, like #DBEAFE and #1E40AF. Optional'],
  ['glyph', '1–3 characters on the subject badge: Ab, 12+, Sc. Optional'],
  [''],
  ['Chapters'],
  ['class', '1 to 10'],
  ['subject_id', 'From the Subjects tab'],
  ['number, title', 'As in the NCERT book'],
  ['chapter_id', 'Unique, like c8-sci-01 (class 8, science, chapter 1)'],
  ['status', 'Empty means live; draft hides the whole chapter'],
  [''],
  ['Cards'],
  ['chapter_id', 'From the Chapters tab'],
  ['card_id', 'Unique, like c8s1-07'],
  ['front, back', 'The question and its answer. A flashcard shows only the front, so don\'t write "Which of these…?" unless the options are in the question'],
  ['wrong_1 … wrong_3', 'Wrong answers for multiple choice. Optional: the quiz borrows answers from other cards when empty'],
  ['explain', 'Shown with the answer: why it is right'],
  ['hint', 'Shown under the question (Classes 1–5)'],
  ['back_word', 'Short word beside the answer, like six for 6'],
  ['tf_statement, tf_answer', 'A true-or-false sentence and TRUE or FALSE. Optional'],
  ['blank_sentence, blank_answer', 'A sentence with ___ for the gap, and the word that fills it. Optional'],
  ['source', 'NCERT page or reference. Optional'],
  ['level', '1 remember, 2 understand, 3 apply. Not used by the app yet'],
  ['concept', 'A short topic tag, like photosynthesis. Not used by the app yet'],
  ['status', 'Empty means live; draft hides the card'],
  ['reviewed_by, notes', 'For the content team; not sent to the app'],
  [''],
  ['Pairs'],
  ['chapter_id, left, right', 'Pairs for "Match the pairs", like Yeast ↔ Bread. Short words work best'],
];

const decks = readdirSync(deckDir)
  .filter((f) => /^class_\d+\.json$/.test(f))
  .map((f) => JSON.parse(readFileSync(join(deckDir, f), 'utf8')))
  .sort((a, b) => a.classLevel - b.classLevel);

const tabs = { 'Read me': readMe, ...decksToTabs(decks, styles) };
const widths = {
  'Read me': [30, 110],
  Subjects: [14, 20, 8, 12, 12, 8],
  Chapters: [7, 12, 8, 40, 14, 10],
  Cards: columns.Cards.map((c) => ({ front: 50, back: 36, explain: 50, tf_statement: 40, blank_sentence: 40 }[c] ?? 16)),
  Pairs: [14, 30, 30],
};

const out = join(here, 'out', 'RevUp content.xlsx');
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, writeXlsx(tabs, { widths }));
const count = (t) => tabs[t].length - 1;
console.log(`Wrote ${out}`);
console.log(`${count('Subjects')} subjects, ${count('Chapters')} chapters, ${count('Cards')} cards, ${count('Pairs')} pairs`);
