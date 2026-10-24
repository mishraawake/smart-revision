// Just enough .xlsx to read a Google Sheets download and write a starter
// workbook: tabs of plain text cells. No dependencies; Node's zlib does the
// zip compression.

import { crc32, deflateRawSync, inflateRawSync } from 'node:zlib';

// ---- Reading ----------------------------------------------------------------

/**
 * Returns { tabs: {name: string[][]}, dates: [{tab, row, col}] }. Rows and
 * columns are 0-based; `dates` lists cells Sheets stored as dates, which
 * happens when an author types "1/2" into a column not set to plain text.
 */
export function readXlsx(buffer) {
  const files = unzip(buffer);
  const text = (path) => {
    const f = files.get(path);
    return f === undefined ? null : f.toString('utf8');
  };

  const strings = [];
  for (const [, si] of (text('xl/sharedStrings.xml') ?? '').matchAll(/<si>([\s\S]*?)<\/si>/g)) {
    strings.push(textOf(si));
  }

  const dateStyles = readDateStyles(text('xl/styles.xml') ?? '');

  const targets = new Map();
  for (const [tag] of (text('xl/_rels/workbook.xml.rels') ?? '').matchAll(/<Relationship\b[^>]*>/g)) {
    const a = attrs(tag);
    targets.set(a.Id, a.Target.replace(/^\/?(xl\/)?/, 'xl/'));
  }

  const tabs = {};
  const dates = [];
  for (const [tag] of (text('xl/workbook.xml') ?? '').matchAll(/<sheet\b[^>]*>/g)) {
    const a = attrs(tag);
    const name = unescape(a.name);
    const xml = text(targets.get(a['r:id']));
    if (xml === null) continue;
    const rows = [];
    for (const [, cellAttrs, body = ''] of xml.matchAll(/<c\b([^>]*?)(?:\/>|>([\s\S]*?)<\/c>)/g)) {
      const c = attrs(cellAttrs);
      const [, letters, digits] = /^([A-Z]+)(\d+)$/.exec(c.r);
      const row = Number(digits) - 1;
      const col = columnIndex(letters);
      const v = /<v>([\s\S]*?)<\/v>/.exec(body)?.[1];
      let value;
      switch (c.t) {
        case 's':
          value = strings[Number(v)];
          break;
        case 'inlineStr':
          value = textOf(body);
          break;
        case 'b':
          value = v === '1' ? 'TRUE' : 'FALSE';
          break;
        default:
          value = v === undefined ? '' : unescape(v);
          if (value !== '' && c.t === undefined && dateStyles.has(Number(c.s ?? 0))) {
            dates.push({ tab: name, row, col });
          }
      }
      if (value === undefined || value === '') continue;
      (rows[row] ??= [])[col] = value;
    }
    tabs[name] = Array.from(rows, (r) => Array.from(r ?? [], (v) => v ?? ''));
  }
  return { tabs, dates };
}

/** Style indexes whose number format shows a date or time. */
function readDateStyles(xml) {
  const custom = new Map();
  for (const [tag] of xml.matchAll(/<numFmt\b[^>]*>/g)) {
    const a = attrs(tag);
    custom.set(Number(a.numFmtId), unescape(a.formatCode));
  }
  const isDate = (id) => {
    if ((id >= 14 && id <= 22) || (id >= 45 && id <= 47)) return true;
    const code = custom.get(id);
    // Strip quoted text and [colour] tags before looking for d/m/y/h/s.
    return code !== undefined && /[dmyhs]/i.test(code.replace(/"[^"]*"|\[[^\]]*\]/g, ''));
  };
  const out = new Set();
  const cellXfs = /<cellXfs\b[^>]*>([\s\S]*?)<\/cellXfs>/.exec(xml)?.[1] ?? '';
  let i = 0;
  for (const [tag] of cellXfs.matchAll(/<xf\b[^>]*>/g)) {
    if (isDate(Number(attrs(tag).numFmtId ?? 0))) out.add(i);
    i++;
  }
  return out;
}

export function unzip(buffer) {
  let end = buffer.length - 22;
  while (end >= 0 && buffer.readUInt32LE(end) !== 0x06054b50) end--;
  if (end < 0) throw new Error('Not an .xlsx file (no zip directory found)');
  const count = buffer.readUInt16LE(end + 10);
  let p = buffer.readUInt32LE(end + 16);
  const files = new Map();
  for (let i = 0; i < count; i++) {
    const method = buffer.readUInt16LE(p + 10);
    const size = buffer.readUInt32LE(p + 20);
    const nameLength = buffer.readUInt16LE(p + 28);
    const skip = nameLength + buffer.readUInt16LE(p + 30) + buffer.readUInt16LE(p + 32);
    const name = buffer.toString('utf8', p + 46, p + 46 + nameLength);
    const local = buffer.readUInt32LE(p + 42);
    const start = local + 30 + buffer.readUInt16LE(local + 26) + buffer.readUInt16LE(local + 28);
    const data = buffer.subarray(start, start + size);
    files.set(name, method === 8 ? inflateRawSync(data) : data);
    p += 46 + skip;
  }
  return files;
}

function attrs(tag) {
  const out = {};
  for (const [, k, v] of tag.matchAll(/([\w:]+)="([^"]*)"/g)) out[k] = v;
  return out;
}

/** All <t> runs in a shared or inline string, skipping phonetic hints. */
function textOf(xml) {
  const plain = xml.replace(/<rPh\b[\s\S]*?<\/rPh>/g, '');
  return [...plain.matchAll(/<t\b[^>]*>([\s\S]*?)<\/t>/g)].map((m) => unescape(m[1])).join('');
}

function unescape(s) {
  return s.replace(/&(#x[0-9a-f]+|#\d+|amp|lt|gt|quot|apos);/gi, (_, e) => {
    if (e[0] === '#') {
      return String.fromCodePoint(e[1] === 'x' || e[1] === 'X' ? parseInt(e.slice(2), 16) : Number(e.slice(1)));
    }
    return { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'" }[e.toLowerCase()];
  });
}

function columnIndex(letters) {
  let n = 0;
  for (const ch of letters) n = n * 26 + (ch.charCodeAt(0) - 64);
  return n - 1;
}

// ---- Writing ----------------------------------------------------------------

/**
 * Builds a workbook from { tabName: string[][] }. Every cell is text and
 * every column is formatted as plain text, so Sheets keeps "1/2" as typed.
 * `widths` optionally gives { tabName: [characters per column] }.
 */
export function writeXlsx(tabs, { widths = {} } = {}) {
  const names = Object.keys(tabs);
  const files = [
    ['[Content_Types].xml', xml(
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
      '<Default Extension="xml" ContentType="application/xml"/>' +
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>' +
      names.map((_, i) => `<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>`).join('') +
      '</Types>')],
    ['_rels/.rels', xml(
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>' +
      '</Relationships>')],
    ['xl/workbook.xml', xml(
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>' +
      names.map((n, i) => `<sheet name="${escape(n)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>`).join('') +
      '</sheets></workbook>')],
    ['xl/_rels/workbook.xml.rels', xml(
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
      names.map((_, i) => `<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>`).join('') +
      `<Relationship Id="rId${names.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>` +
      '</Relationships>')],
    // Style 1: plain text (numFmt 49). Style 2: plain text, bold, for headers.
    ['xl/styles.xml', xml(
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
      '<fonts count="2"><font><sz val="11"/><name val="Arial"/></font><font><b/><sz val="11"/><name val="Arial"/></font></fonts>' +
      '<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>' +
      '<borders count="1"><border/></borders>' +
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>' +
      '<cellXfs count="3"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>' +
      '<xf numFmtId="49" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>' +
      '<xf numFmtId="49" fontId="1" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1"/></cellXfs>' +
      '</styleSheet>')],
    ...names.map((n, i) => [`xl/worksheets/sheet${i + 1}.xml`, sheetXml(tabs[n], widths[n])]),
  ];
  return zip(files);
}

function sheetXml(rows, widths = []) {
  const columns = Math.max(1, widths.length, ...rows.map((r) => r.length));
  const cols = Array.from({ length: columns }, (_, i) =>
    `<col min="${i + 1}" max="${i + 1}" width="${widths[i] ?? 16}" style="1" customWidth="1"/>`).join('');
  const body = rows.map((r, ri) => `<row r="${ri + 1}">` + r.map((v, ci) => {
    if (v === undefined || v === null || v === '') return '';
    return `<c r="${columnLetters(ci)}${ri + 1}" t="inlineStr" s="${ri === 0 ? 2 : 1}"><is><t xml:space="preserve">${escape(String(v))}</t></is></c>`;
  }).join('') + '</row>').join('');
  return xml(
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
    '<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>' +
    `<cols>${cols}</cols><sheetData>${body}</sheetData></worksheet>`);
}

function xml(s) {
  return Buffer.from('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n' + s, 'utf8');
}

function escape(s) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function columnLetters(i) {
  let s = '';
  for (let n = i + 1; n > 0; n = Math.floor((n - 1) / 26)) s = String.fromCharCode(65 + ((n - 1) % 26)) + s;
  return s;
}

/** Zips [[path, Buffer]] pairs. */
export function zip(files) {
  const locals = [];
  const central = [];
  let offset = 0;
  for (const [name, data] of files) {
    const nameBuf = Buffer.from(name, 'utf8');
    const packed = deflateRawSync(data);
    const crc = crc32(data);
    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(20, 4);
    local.writeUInt16LE(0x0800, 6); // UTF-8 names
    local.writeUInt16LE(8, 8);
    local.writeUInt32LE(crc, 14);
    local.writeUInt32LE(packed.length, 18);
    local.writeUInt32LE(data.length, 22);
    local.writeUInt16LE(nameBuf.length, 26);
    locals.push(local, nameBuf, packed);

    const entry = Buffer.alloc(46);
    entry.writeUInt32LE(0x02014b50, 0);
    entry.writeUInt16LE(20, 4);
    entry.writeUInt16LE(20, 6);
    entry.writeUInt16LE(0x0800, 8);
    entry.writeUInt16LE(8, 10);
    entry.writeUInt32LE(crc, 16);
    entry.writeUInt32LE(packed.length, 20);
    entry.writeUInt32LE(data.length, 24);
    entry.writeUInt16LE(nameBuf.length, 28);
    entry.writeUInt32LE(offset, 42);
    central.push(entry, nameBuf);
    offset += 30 + nameBuf.length + packed.length;
  }
  const centralBuf = Buffer.concat(central);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(files.length, 8);
  end.writeUInt16LE(files.length, 10);
  end.writeUInt32LE(centralBuf.length, 12);
  end.writeUInt32LE(offset, 16);
  return Buffer.concat([...locals, centralBuf, end]);
}
