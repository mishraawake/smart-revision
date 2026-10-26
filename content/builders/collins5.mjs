// Replaces the Class 5 sample rows in the RevUp content sheet with the Collins
// Class 5 syllabus, plus cards for Science chapter 1 (Solids, Liquids and Gases).
// Usage: node collins5.mjs <content dir> <in.xlsx> <out.xlsx>
import { readFileSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { join } from 'node:path';

const [dir, inFile, outFile] = process.argv.slice(2);
const { readXlsx, writeXlsx } = await import(pathToFileURL(join(dir, 'xlsx.js')));
const { columns } = await import(pathToFileURL(join(dir, 'decks.js')));
const { tabs } = readXlsx(readFileSync(inFile));
const { more } = await import(pathToFileURL(join(import.meta.dirname, 'collins5_more.mjs')));

const syllabus = {
  english: ['Don Quixote and the Enchanted Helmet', 'Earrings for Nina', 'The Labours of Hercules',
    'Ron and the Lucky Potion', 'The Concert', 'Art is Hard'],
  maths: ['Measurement', 'Time and Temperature', 'Geometry', 'Perimeter, Area and Volume',
    'Shapes, Nets and Symmetry', 'Data Handling', 'Mapping Skills'],
  science: ['Solids, Liquids and Gases', 'Air and Water', 'Rocks and Minerals', 'Force and Energy',
    'Earth, Sun and Moon', 'Light and Shadow', 'Pollution'],
  social: ['Environmental Pollution', 'Natural Disasters', 'Evolution of Transport and Communication',
    'India Over the Ages', 'British Period in India', 'Attaining Freedom', 'Indian Government',
    'United Nations'],
};
const short = { english: 'eng', maths: 'maths', science: 'sci', social: 'ss' };
// "c5c" = Class 5 Collins, so no ID from the old Class 5 samples is reused.
const chapterId = (s, n) => `c5c-${short[s]}-${String(n).padStart(2, '0')}`;

const ch1 = chapterId('science', 1);
const src = 'Collins Class 5 Science, Ch 1';
// [front, back, [wrong], explain, hint, tf_statement, tf_answer, blank_sentence, blank_answer, level, concept]
const cards = [
  ['What is matter?', 'Anything that has mass and occupies space', ['Anything that we can see', 'Only living things', 'Only solids and liquids'],
    'Air, water, food and even our body are matter.', 'Think: mass + space', 'Air is not matter because we cannot see it.', 'FALSE',
    'Matter is anything that has mass and occupies ___.', 'space', 1, 'matter'],
  ['What are the tiny particles that matter is made of?', 'Molecules', ['Cells', 'Grains', 'Crystals'],
    'Matter is made of molecules, and molecules are made of even tinier atoms.', '', '', '', '', '', 1, 'molecules'],
  ['What is the basic building block of all matter?', 'Atom', ['Molecule', 'Element', 'Cell'],
    'Two or more atoms join together to form a molecule.', 'Even smaller than a molecule', 'Atoms can be seen with the naked eye.', 'FALSE',
    'Two or more ___ join together to form a molecule.', 'atoms', 1, 'atoms'],
  ['What is the space between two molecules called?', 'Intermolecular space', ['Molecular gap', 'Atomic space', 'Free volume'],
    'It is smallest in solids and largest in gases.', '', '', '', '', '', 1, 'intermolecular space'],
  ['What is the amount of matter in a body called?', 'Mass', ['Volume', 'Size', 'Shape'],
    'The amount of space an object occupies is its volume.', '', '', '', '', '', 1, 'mass and volume'],
  ['What is the amount of space an object occupies called?', 'Volume', ['Mass', 'Weight', 'Density'],
    '', '', '', '', '', '', 1, 'mass and volume'],
  ['What are the three states of matter?', 'Solid, liquid and gas', ['Solid, water and air', 'Ice, water and steam', 'Hard, soft and runny'],
    'The difference between them lies in how their molecules are arranged.', '', '', '', '', '', 1, 'states of matter'],
  ['In which state of matter are molecules most tightly packed?', 'Solid', ['Liquid', 'Gas'],
    'Strong attraction holds the molecules of a solid close together, so they cannot move.', '', 'In solids, the molecules are loosely packed.', 'FALSE',
    'In ___, the molecules are tightly packed.', 'solids', 1, 'solids'],
  ['In which state is the force of attraction between molecules the least?', 'Gas', ['Solid', 'Liquid'],
    'Gas molecules have a lot of free space and move freely in all directions.', '', '', '', '', '', 1, 'gases'],
  ['Why does a solid have a fixed shape and size?', 'Its molecules are tightly packed and cannot move', ['Its molecules move freely', 'It has no molecules', 'It is always cold'],
    'Strong attraction keeps the molecules in place.', '', 'Solids can be compressed easily.', 'FALSE', '', '', 2, 'solids'],
  ['Why do liquids flow?', 'Their molecules can move', ['Their molecules cannot move', 'They have a fixed shape', 'They are very heavy'],
    'Liquid molecules are more loosely packed than in solids, so they slide past each other.', '', '', '',
    'Liquids flow from a ___ level to a lower level.', 'higher', 2, 'liquids'],
  ['A liquid has a fixed volume. Does it have a fixed shape?', 'No – it takes the shape of its container', ['Yes – always round', 'Yes – always square', 'No – and no fixed volume either'],
    'Water in a glass and in a bottle has different shapes but the same volume.', '', 'Liquids have a fixed volume but no fixed shape.', 'TRUE', '', '', 2, 'liquids'],
  ['Which state of matter can be compressed to a large extent?', 'Gas', ['Solid', 'Liquid'],
    'Gases have lots of free space between molecules – that is why we can fill so much air into a balloon or tyre.', '', '', '', '', '', 2, 'gases'],
  ['What is solubility?', 'The ability of a substance to dissolve in another substance', ['The ability to melt', 'The ability to float on water', 'The ability to change colour'],
    'Sugar has high solubility in water.', '', '', '', '', '', 1, 'solubility'],
  ['The substance that dissolves is called the …?', 'Solute', ['Solvent', 'Solution', 'Mixture'],
    'In salt water, salt is the solute.', '', '', '', 'A substance that dissolves in another substance is called a ___.', 'solute', 1, 'solute and solvent'],
  ['The substance in which the solute dissolves is called the …?', 'Solvent', ['Solute', 'Solution', 'Liquid'],
    'In salt water, water is the solvent.', '', '', '', '', '', 1, 'solute and solvent'],
  ['Salt + water gives salt water. What is salt water called?', 'Solution', ['Solute', 'Solvent', 'Compound'],
    'Solute + solvent = solution.', '', '', '', '', '', 2, 'solution'],
  ['What is a uniform solution?', 'A solution where the solute spreads evenly through the solvent', ['A solution with lumps at the bottom', 'A solution that cannot be poured', 'A solid that has melted'],
    'Salt breaks into molecules that spread evenly between the water molecules.', '', '', '', '', '', 2, 'solution'],
  ['Sand, chalk powder and tea leaves do not dissolve in water. What are they called?', 'Insoluble substances', ['Soluble substances', 'Miscible liquids', 'Solvents'],
    'Salt and sugar, which dissolve, are soluble substances.', '', 'Sugar is an insoluble substance.', 'FALSE', '', '', 1, 'soluble and insoluble'],
  ['Liquids that dissolve easily in water, like milk, are called …?', 'Miscible liquids', ['Immiscible liquids', 'Insoluble liquids', 'Solutes'],
    'Milk, glycerine and alcohol are miscible with water.', '', '', '', '', '', 1, 'miscible and immiscible'],
  ['Oil floats on water and does not mix. Oil is a … liquid.', 'Immiscible', ['Miscible', 'Soluble', 'Uniform'],
    'Oil and petrol are immiscible with water.', '', 'Oil is miscible in water.', 'FALSE', '', '', 1, 'miscible and immiscible'],
  ['Why do bubbles come out when we open a bottle of soda?', 'Carbon dioxide dissolved under pressure escapes', ['Oxygen is made inside the bottle', 'The water starts boiling', 'Sugar turns into gas'],
    'Soda has carbon dioxide dissolved in it under high pressure – this gives the fizz.', '', 'Carbon dioxide does not dissolve in water.', 'FALSE', '', '', 3, 'solubility of gases'],
  ['How do fish breathe under water?', 'They use oxygen dissolved in water', ['They come up for air every minute', 'They breathe water itself', 'They do not need oxygen'],
    'Gases like oxygen and carbon dioxide dissolve in water. Aquatic plants use the dissolved carbon dioxide to make food.', '', '', '', '', '', 2, 'solubility of gases'],
  ['Why is water called the universal solvent?', 'It can dissolve more substances than any other liquid', ['It is found everywhere', 'It has no colour', 'It never freezes'],
    '', '', '', '', 'Water is known as the universal ___.', 'solvent', 2, 'universal solvent'],
  ['A solid changing into a liquid on heating is called …?', 'Melting', ['Freezing', 'Evaporation', 'Condensation'],
    'Ice melting into water is an example.', '', 'Melting of ice is a chemical change.', 'FALSE', '', '', 1, 'change of state'],
  ['A liquid changing into a gas on heating is called …?', 'Evaporation', ['Condensation', 'Melting', 'Freezing'],
    'Wet clothes dry because the water evaporates.', '', '', '', '', '', 1, 'change of state'],
  ['A liquid changing into a solid on cooling is called …?', 'Freezing', ['Melting', 'Condensation', 'Evaporation'],
    'Water kept in the freezer turns into ice.', '', '', '', 'Water kept in the freezer turns into ice. This is called ___.', 'freezing', 1, 'change of state'],
  ['A gas changing into a liquid on cooling is called …?', 'Condensation', ['Evaporation', 'Freezing', 'Melting'],
    'Water drops form outside a cold glass because water vapour in the air condenses. Dew forms the same way.', '', '', '', '', '', 1, 'change of state'],
  ['What happens to the molecules of a substance when it is heated?', 'They gain energy and move faster', ['They lose energy and slow down', 'They stop moving', 'They disappear'],
    'On cooling, molecules lose energy and slow down.', '', 'The movement of molecules increases on cooling.', 'FALSE', '', '', 2, 'heating and cooling'],
  ['Most solids get bigger when heated. What is this called?', 'Expansion', ['Contraction', 'Melting', 'Condensation'],
    'On cooling, solids contract (get smaller) as their molecules come closer.', '', '', '',
    'Most solids ___ on heating and contract on cooling.', 'expand', 2, 'expansion and contraction'],
  ['What is a physical change?', 'A temporary change where no new substance is formed', ['A permanent change that forms a new substance', 'A change that can never be reversed', 'A change only in living things'],
    'It is usually reversible, like water ↔ ice.', '', 'Physical change is a permanent change.', 'FALSE', '', '', 1, 'physical change'],
  ['What is a chemical change?', 'A permanent change where new substances are formed', ['A temporary change with no new substance', 'A change in shape only', 'A change that is easy to reverse'],
    'Burning leaves gives ash, which is very different from leaves.', '', '', '',
    'A change that produces new substances is called a ___ change.', 'chemical', 1, 'chemical change'],
  ['Melting chocolate in a pan – physical or chemical change?', 'Physical', ['Chemical'],
    'The melted chocolate can set again – no new substance is formed.', '', '', '', '', '', 3, 'physical vs chemical'],
  ['Baking a cookie – physical or chemical change?', 'Chemical', ['Physical'],
    'Baked dough cannot turn back into raw dough – new substances form.', '', '', '', '', '', 3, 'physical vs chemical'],
  ['Rusting of an iron nail – physical or chemical change?', 'Chemical', ['Physical'],
    'Rust is a new substance and the change cannot be reversed.', '', 'Rusting of iron is a chemical change.', 'TRUE', '', '', 3, 'physical vs chemical'],
  ['Making a boat from paper – physical or chemical change?', 'Physical', ['Chemical'],
    'Only the shape changes; you can unfold it back.', '', '', '', '', '', 3, 'physical vs chemical'],
  ['Burning a candle involves which kind of change?', 'Both physical and chemical', ['Only physical', 'Only chemical', 'No change'],
    'Wax melting is physical; wax burning to give heat, light and gases is chemical.', '', '', '', '', '', 3, 'physical vs chemical'],
  ['How does the smell of food cooking in the kitchen spread through the whole house?', 'Gas molecules move freely in all directions', ['The smell travels through the walls', 'Liquids flow from the kitchen', 'Solids carry the smell'],
    'The aroma is carried by gas molecules that spread out to fill the space.', '', '', '', '', '', 3, 'gases'],
];
const pairs = [
  ['Melting', 'Solid → liquid'], ['Freezing', 'Liquid → solid'], ['Evaporation', 'Liquid → gas'], ['Condensation', 'Gas → liquid'],
  ['Solute', 'Salt'], ['Solvent', 'Water'],
];

const isC5 = (r) => r[0] === '5';
const oldC5 = new Set(tabs.Chapters.slice(1).filter(isC5).map((r) => r[4]));
const keep = (t, col) => [tabs[t][0], ...tabs[t].slice(1).filter((r) => !oldC5.has(r[col]))];

const chapters = keep('Chapters', 4).filter((r, i) => i === 0 || !isC5(r));
for (const [s, titles] of Object.entries(syllabus)) {
  titles.forEach((title, i) => {
    const id = chapterId(s, i + 1);
    const live = id === ch1 || more[s]?.[i + 1];
    chapters.push(['5', s, String(i + 1), title, id, live ? '' : 'draft']);
  });
}

const cardRows = keep('Cards', 0);
const ix = Object.fromEntries(columns.Cards.map((c, i) => [c, i]));
cards.forEach(([front, back, wrong, explain, hint, tfS, tfA, blS, blA, level, concept], i) => {
  const row = columns.Cards.map(() => '');
  Object.assign(row, {
    [ix.chapter_id]: ch1, [ix.card_id]: `c5cs1-${String(i + 1).padStart(2, '0')}`, [ix.front]: front, [ix.back]: back,
    [ix.wrong_1]: wrong[0] ?? '', [ix.wrong_2]: wrong[1] ?? '', [ix.wrong_3]: wrong[2] ?? '',
    [ix.explain]: explain, [ix.hint]: hint, [ix.tf_statement]: tfS, [ix.tf_answer]: tfA,
    [ix.blank_sentence]: blS, [ix.blank_answer]: blA, [ix.source]: src, [ix.level]: String(level), [ix.concept]: concept,
  });
  cardRows.push(row);
});
const cardPrefix = { maths: 'c5cm', science: 'c5cs', social: 'c5css' };
const pairRows = [...keep('Pairs', 0), ...pairs.map(([l, r]) => [ch1, l, r])];
let added = 0;
for (const [s, byNumber] of Object.entries(more)) {
  for (const [n, ch] of Object.entries(byNumber)) {
    const id = chapterId(s, Number(n));
    ch.cards.forEach(([front, back, wrong, explain, tfS = '', tfA = ''], i) => {
      const row = columns.Cards.map(() => '');
      Object.assign(row, {
        [ix.chapter_id]: id, [ix.card_id]: `${cardPrefix[s]}${n}-${String(i + 1).padStart(2, '0')}`, [ix.front]: front, [ix.back]: back,
        [ix.wrong_1]: wrong[0] ?? '', [ix.wrong_2]: wrong[1] ?? '', [ix.wrong_3]: wrong[2] ?? '',
        [ix.explain]: explain, [ix.tf_statement]: tfS, [ix.tf_answer]: tfA,
        [ix.source]: 'Class 5 topic, written from the Collins chapter title',
        [ix.notes]: 'Check against the Collins book pages',
      });
      cardRows.push(row);
      added++;
    });
    for (const [l, r] of ch.pairs) pairRows.push([id, l, r]);
  }
}
console.log(`Added ${added} cards from chapter titles`);

const out = { 'Read me': tabs['Read me'], Subjects: tabs.Subjects, Chapters: chapters, Cards: cardRows, Pairs: pairRows };
const widths = {
  'Read me': [30, 110], Subjects: [14, 20, 8, 12, 12, 8], Chapters: [7, 12, 8, 40, 14, 10],
  Cards: columns.Cards.map((c) => ({ front: 50, back: 36, explain: 50, tf_statement: 40, blank_sentence: 40 }[c] ?? 16)),
  Pairs: [14, 30, 30],
};
writeFileSync(outFile, writeXlsx(out, { widths }));
console.log(`Removed ${oldC5.size} old Class 5 chapters; added ${chapters.length - (tabs.Chapters.length - oldC5.size)} Collins chapters, ${cards.length} cards, ${pairs.length} pairs`);
