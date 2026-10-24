// The content sheet <-> the app's deck files (assets/decks/class_N.json).
//
// Tabs: Subjects, Chapters, Cards and Pairs (any other tab, such as Read me,
// is ignored). Row 1 of each tab holds the column names below.

export const columns = {
  Subjects: ['subject_id', 'name', 'order', 'colour', 'ink', 'glyph'],
  Chapters: ['class', 'subject_id', 'number', 'title', 'chapter_id', 'status'],
  Cards: [
    'chapter_id', 'card_id', 'front', 'back', 'wrong_1', 'wrong_2', 'wrong_3',
    'explain', 'hint', 'back_word', 'tf_statement', 'tf_answer',
    'blank_sentence', 'blank_answer', 'source', 'level', 'concept', 'status',
    'reviewed_by', 'notes',
  ],
  Pairs: ['chapter_id', 'left', 'right'],
};

/** Columns a tab can't do without; the others may be left out. */
const required = {
  Subjects: ['subject_id', 'name'],
  Chapters: ['class', 'subject_id', 'number', 'title', 'chapter_id'],
  Cards: ['chapter_id', 'card_id', 'front', 'back'],
  Pairs: ['chapter_id', 'left', 'right'],
};

/** Rows with one of these statuses are left out of the app. */
const hiddenStatuses = new Set(['draft', 'hidden', 'hide', 'off']);

/**
 * Builds every class's deck from the sheet's tabs.
 * Returns { decks: {classLevel: deck}, errors: [], warnings: [] }; when
 * `errors` is non-empty the decks must not be published.
 */
export function buildDecks(tabs, { dates = [] } = {}) {
  const errors = [];
  const warnings = [];
  const tab = (name) => readTab(tabs, name, errors);

  for (const d of dates) {
    if (!columns[d.tab]) continue;
    errors.push(`${d.tab} row ${d.row + 1}, column ${columnName(d.col)}: Sheets turned this into a date. ` +
      'Set the column to Format → Number → Plain text and type it again.');
  }

  // Subjects
  const subjects = new Map();
  for (const r of tab('Subjects')) {
    const at = `Subjects row ${r.row}`;
    if (!need(r, required.Subjects, at, errors)) continue;
    if (subjects.has(r.subject_id)) {
      errors.push(`${at}: subject_id "${r.subject_id}" is used twice`);
      continue;
    }
    for (const k of ['colour', 'ink']) {
      if (r[k] && !/^#[0-9a-f]{6}$/i.test(r[k])) {
        errors.push(`${at}: ${k} "${r[k]}" should look like #1E40AF`);
      }
    }
    const order = r.order === '' ? subjects.size + 1 : Number(r.order);
    if (Number.isNaN(order)) errors.push(`${at}: order "${r.order}" is not a number`);
    subjects.set(r.subject_id, { ...r, order, at });
  }

  // Chapters
  const chapters = new Map();
  const numbers = new Set();
  for (const r of tab('Chapters')) {
    const at = `Chapters row ${r.row}`;
    if (!need(r, required.Chapters, at, errors)) continue;
    const classLevel = Number(r.class);
    const number = Number(r.number);
    if (!Number.isInteger(classLevel) || classLevel < 1 || classLevel > 12) {
      errors.push(`${at}: class "${r.class}" should be a number from 1 to 12`);
      continue;
    }
    if (!Number.isInteger(number) || number < 1) {
      errors.push(`${at}: number "${r.number}" should be a whole number`);
      continue;
    }
    if (!subjects.has(r.subject_id)) {
      errors.push(`${at}: subject_id "${r.subject_id}" is not on the Subjects tab`);
      continue;
    }
    if (chapters.has(r.chapter_id)) {
      errors.push(`${at}: chapter_id "${r.chapter_id}" is used twice`);
      continue;
    }
    const key = `${classLevel}/${r.subject_id}/${number}`;
    if (numbers.has(key)) {
      errors.push(`${at}: Class ${classLevel} ${r.subject_id} already has a chapter ${number}`);
    }
    numbers.add(key);
    chapters.set(r.chapter_id, {
      ...r, classLevel, number, at,
      hidden: hiddenStatuses.has(r.status.toLowerCase()),
      cards: [], pairs: [],
    });
  }

  // Cards
  const cardIds = new Set();
  for (const r of tab('Cards')) {
    const at = `Cards row ${r.row}`;
    if (!need(r, required.Cards, at, errors)) continue;
    if (cardIds.has(r.card_id)) {
      errors.push(`${at}: card_id "${r.card_id}" is used twice`);
      continue;
    }
    cardIds.add(r.card_id);
    const chapter = chapters.get(r.chapter_id);
    if (!chapter) {
      errors.push(`${at}: chapter_id "${r.chapter_id}" is not on the Chapters tab`);
      continue;
    }
    const card = cardFrom(r, at, errors, warnings);
    if (card && !hiddenStatuses.has(r.status.toLowerCase())) chapter.cards.push(card);
  }

  // Pairs
  for (const r of tab('Pairs')) {
    const at = `Pairs row ${r.row}`;
    if (!need(r, required.Pairs, at, errors)) continue;
    const chapter = chapters.get(r.chapter_id);
    if (!chapter) {
      errors.push(`${at}: chapter_id "${r.chapter_id}" is not on the Chapters tab`);
      continue;
    }
    chapter.pairs.push([r.left, r.right]);
  }

  // Assemble: class → subjects (by order) → chapters (by number) → cards
  // (in sheet order).
  const decks = {};
  const live = [...chapters.values()].filter((ch) => !ch.hidden);
  for (const ch of live) {
    if (ch.cards.length === 0) {
      warnings.push(`${ch.at}: chapter "${ch.title}" has no cards yet, so it is left out`);
    }
  }
  const classes = [...new Set(live.map((ch) => ch.classLevel))].sort((a, b) => a - b);
  for (const classLevel of classes) {
    const own = live.filter((ch) => ch.classLevel === classLevel && ch.cards.length > 0);
    const subjectIds = [...new Set(own.map((ch) => ch.subject_id))]
      .sort((a, b) => subjects.get(a).order - subjects.get(b).order);
    if (subjectIds.length === 0) continue;
    decks[classLevel] = {
      classLevel,
      subjects: subjectIds.map((id) => {
        const s = subjects.get(id);
        return {
          id,
          name: s.name,
          ...(s.colour && { colour: s.colour.toUpperCase() }),
          ...(s.ink && { ink: s.ink.toUpperCase() }),
          ...(s.glyph && { glyph: s.glyph }),
          chapters: own
            .filter((ch) => ch.subject_id === id)
            .sort((a, b) => a.number - b.number)
            .map((ch) => ({
              id: ch.chapter_id,
              number: ch.number,
              title: ch.title,
              ...(ch.pairs.length > 0 && { pairs: ch.pairs }),
              cards: ch.cards,
            })),
        };
      }),
    };
  }
  return { decks, errors, warnings };
}

function cardFrom(r, at, errors, warnings) {
  let ok = true;
  const wrong = Object.keys(r)
    .filter((k) => /^wrong_\d+$/.test(k) && r[k] !== '')
    .sort((a, b) => Number(a.slice(6)) - Number(b.slice(6)))
    .map((k) => r[k]);
  const norm = (s) => s.trim().toLowerCase();
  if (wrong.some((w) => norm(w) === norm(r.back))) {
    errors.push(`${at}: a wrong answer is the same as the right answer "${r.back}"`);
    ok = false;
  }
  if (new Set(wrong.map(norm)).size < wrong.length) {
    errors.push(`${at}: two wrong answers are the same`);
    ok = false;
  }

  let tf;
  if (r.tf_statement || r.tf_answer) {
    const answer = { true: true, yes: true, false: false, no: false }[norm(r.tf_answer)];
    if (!r.tf_statement || answer === undefined) {
      errors.push(`${at}: true/false needs both tf_statement and tf_answer (TRUE or FALSE)`);
      ok = false;
    } else {
      tf = { text: r.tf_statement, answer };
    }
  }

  let blank;
  if (r.blank_sentence || r.blank_answer) {
    if (!r.blank_sentence || !r.blank_answer) {
      errors.push(`${at}: fill-the-blank needs both blank_sentence and blank_answer`);
      ok = false;
    } else if (!r.blank_sentence.includes('___')) {
      errors.push(`${at}: blank_sentence needs a gap written as ___ (three underscores)`);
      ok = false;
    } else {
      blank = { text: r.blank_sentence, answer: r.blank_answer };
    }
  }

  let level;
  if (r.level) {
    level = Number(r.level);
    if (![1, 2, 3].includes(level)) {
      errors.push(`${at}: level "${r.level}" should be 1, 2 or 3`);
      ok = false;
    }
  }

  // A flashcard shows only the front, so it can't ask the student to pick
  // from options it doesn't list ("Which of these…?").
  if (/\b(which of these|which of the following|which sentence|which (word|one) is)\b/i.test(r.front) &&
      !/:|\bor\b/i.test(r.front)) {
    warnings.push(`${at}: "${r.front}" asks to choose from options a flashcard doesn't show`);
  }

  if (!ok) return null;
  return {
    id: r.card_id,
    front: r.front,
    back: r.back,
    ...(r.back_word && { backWord: r.back_word }),
    ...(r.hint && { hint: r.hint }),
    ...(r.explain && { explain: r.explain }),
    ...(r.source && { source: r.source }),
    ...(wrong.length > 0 && { wrong }),
    ...(tf && { tf }),
    ...(blank && { blank }),
    ...(level && { level }),
    ...(r.concept && { concept: r.concept }),
  };
}

/** The tab's rows as objects keyed by column name, with 1-based row numbers. */
function readTab(tabs, name, errors) {
  const found = Object.keys(tabs).find((t) => t.trim().toLowerCase() === name.toLowerCase());
  if (!found) {
    errors.push(`The sheet has no "${name}" tab`);
    return [];
  }
  const [header = [], ...rows] = tabs[found];
  const keys = header.map((h) => String(h).trim().toLowerCase().replace(/\s+/g, '_'));
  const missing = required[name].filter((c) => !keys.includes(c));
  if (missing.length > 0) {
    errors.push(`${name} tab is missing column${missing.length > 1 ? 's' : ''}: ${missing.join(', ')}`);
    return [];
  }
  const out = [];
  rows.forEach((cells, i) => {
    if (!cells || cells.every((c) => String(c ?? '').trim() === '')) return;
    const r = { row: i + 2 };
    for (const c of columns[name]) r[c] = '';
    keys.forEach((k, j) => {
      if (k) r[k] = String(cells[j] ?? '').trim();
    });
    out.push(r);
  });
  return out;
}

function need(r, keys, at, errors) {
  const missing = keys.filter((k) => r[k] === '');
  if (missing.length > 0) errors.push(`${at}: ${missing.join(', ')} ${missing.length > 1 ? 'are' : 'is'} empty`);
  return missing.length === 0;
}

function columnName(i) {
  let s = '';
  for (let n = i + 1; n > 0; n = Math.floor((n - 1) / 26)) s = String.fromCharCode(65 + ((n - 1) % 26)) + s;
  return s;
}

/**
 * The reverse, for starting the sheet from the decks already in the app.
 * `styles` gives each subject's { colour, ink, glyph } when the decks don't.
 */
export function decksToTabs(decks, styles = {}) {
  const subjects = new Map();
  const chapters = [];
  const cards = [];
  const pairs = [];
  // Subject order comes from the highest classes first: they have the most
  // subjects, and lower classes' subjects fit around them.
  for (const deck of [...decks].sort((a, b) => b.classLevel - a.classLevel)) {
    for (const s of deck.subjects) {
      if (subjects.has(s.id)) continue;
      const st = { ...styles[s.id], ...pick(s, ['colour', 'ink', 'glyph']) };
      subjects.set(s.id, [s.id, s.name, String(subjects.size + 1), st.colour ?? '', st.ink ?? '', st.glyph ?? '']);
    }
  }
  for (const deck of decks) {
    for (const s of deck.subjects) {
      for (const ch of s.chapters) {
        chapters.push([String(deck.classLevel), s.id, String(ch.number), ch.title, ch.id, '']);
        for (const [left, right] of ch.pairs ?? []) pairs.push([ch.id, left, right]);
        for (const c of ch.cards) {
          const w = c.wrong ?? [];
          cards.push([
            ch.id, c.id, c.front, c.back, w[0] ?? '', w[1] ?? '', w[2] ?? '',
            c.explain ?? '', c.hint ?? '', c.backWord ?? '',
            c.tf?.text ?? '', c.tf ? (c.tf.answer ? 'TRUE' : 'FALSE') : '',
            c.blank?.text ?? '', c.blank?.answer ?? '', c.source ?? '',
            c.level ? String(c.level) : '', c.concept ?? '', '', '', '',
          ]);
        }
      }
    }
  }
  return {
    Subjects: [columns.Subjects, ...subjects.values()],
    Chapters: [columns.Chapters, ...chapters],
    Cards: [columns.Cards, ...cards],
    Pairs: [columns.Pairs, ...pairs],
  };
}

function pick(o, keys) {
  return Object.fromEntries(keys.filter((k) => o[k] !== undefined).map((k) => [k, o[k]]));
}

/**
 * JSON with one line per card and per pair, like the hand-written decks, so
 * a content change shows up as a one-line diff.
 */
export function formatDeck(deck) {
  const lines = ['{', `  "classLevel": ${deck.classLevel},`, '  "subjects": ['];
  deck.subjects.forEach((s, si) => {
    lines.push('    {');
    lines.push(`      "id": ${JSON.stringify(s.id)},`);
    lines.push(`      "name": ${JSON.stringify(s.name)},`);
    for (const k of ['colour', 'ink', 'glyph']) {
      if (s[k] !== undefined) lines.push(`      "${k}": ${JSON.stringify(s[k])},`);
    }
    lines.push('      "chapters": [');
    s.chapters.forEach((ch, ci) => {
      lines.push('        {');
      lines.push(`          "id": ${JSON.stringify(ch.id)},`);
      lines.push(`          "number": ${ch.number},`);
      lines.push(`          "title": ${JSON.stringify(ch.title)},`);
      if (ch.pairs) lines.push(`          "pairs": ${inline(ch.pairs)},`);
      lines.push('          "cards": [');
      ch.cards.forEach((c, i) => {
        lines.push(`            ${inline(c)}${i < ch.cards.length - 1 ? ',' : ''}`);
      });
      lines.push('          ]');
      lines.push(`        }${ci < s.chapters.length - 1 ? ',' : ''}`);
    });
    lines.push('      ]');
    lines.push(`    }${si < deck.subjects.length - 1 ? ',' : ''}`);
  });
  lines.push('  ]', '}', '');
  return lines.join('\n');
}

/** JSON on one line, with a space after each comma and colon. */
function inline(v) {
  if (Array.isArray(v)) return `[${v.map(inline).join(', ')}]`;
  if (v !== null && typeof v === 'object') {
    return `{${Object.entries(v).map(([k, x]) => `${JSON.stringify(k)}: ${inline(x)}`).join(', ')}}`;
  }
  return JSON.stringify(v);
}
