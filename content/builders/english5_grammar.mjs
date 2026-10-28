// Adds Class 5 English Grammar (new subject) to the Collins Class 5 content sheet.
// The book's two contents pages and Ch 1 Nouns (pp. 9–16) were photographed
// (Google Photos album, 2026-10-28). Ch 1 is written from those pages; the other
// grammar and writing chapters are written from their titles and marked
// "Check against the book pages". Ch 25–34 are reading passages: they stay drafts
// (hidden) until the pages are photographed. Safe to re-run: these chapters are replaced.
// Usage: node english5_grammar.mjs <content dir> <in.xlsx> <out.xlsx>
import { readFileSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { join } from 'node:path';

const [dir, inFile, outFile] = process.argv.slice(2);
const { readXlsx, writeXlsx } = await import(pathToFileURL(join(dir, 'xlsx.js')));
const { columns } = await import(pathToFileURL(join(dir, 'decks.js')));
const { tabs } = readXlsx(readFileSync(inFile));

const subject = ['english_grammar', 'English Grammar', '8', '#DCFCE7', '#166534', 'Gr'];
const fromPages = 'Class 5 English grammar book, Ch 1 Nouns (pp. 9–16)';
const fromTitle = 'Class 5 English grammar book, written from the chapter title';

// Each card: [level, front, back, [wrong], explain, tf_statement, tf_answer, blank_sentence, blank_answer]
const chapters = [
  { title: 'Nouns', fromPages: true, pairs: [['a class of', 'students'], ['a pack of', 'wolves'], ['a colony of', 'ants'], ['a swarm of', 'bees'], ['a shoal of', 'fish'], ['a bouquet of', 'roses']], cards: [
    [1, 'What is a noun?', 'The name of a person, place, animal, thing, feeling, state or quality', ['A word that shows an action', 'A word that describes a noun', 'A word that joins two sentences'], ''],
    [1, 'What is a common noun?', 'The common name of all persons, places, animals or things of the same kind', ['The special name of one person or place', 'The name of a group', 'The name of a feeling'], 'shoes, teacher, cat, door, neighbour'],
    [1, 'What is a proper noun?', 'The special name given to a person, place, animal or thing', ['The common name of things of the same kind', 'The name of a group of things', 'A noun we cannot touch'], 'Jack, England'],
    [1, '"Jack knows how to play the guitar." Which word is a proper noun?', 'Jack', ['guitar', 'play', 'knows'], ''],
    [1, '"Denmark is an important country." Which word is a proper noun?', 'Denmark', ['country', 'important', 'is'], '', 'In this sentence, "country" is a proper noun.', 'FALSE'],
    [1, '"Mr Jones is my neighbour." Which word is a common noun?', 'neighbour', ['Mr Jones', 'is', 'my'], ''],
    [1, 'Which of these is a common noun?', 'teacher', ['England', 'Mrs Bhatt', 'Vadodara'], ''],
    [1, 'What is a collective noun?', 'The name given to a group of people, animals or things', ['The name of a single person', 'The name of a feeling', 'Two nouns joined together'], 'army, fleet, flock'],
    [1, 'Fill in: a ___ of students', 'class', ['flock', 'pack', 'colony'], '', '', '', 'A ___ of students sat in the hall.', 'class'],
    [1, 'Fill in: a ___ of cards', 'deck', ['crew', 'gang', 'swarm'], ''],
    [1, 'Fill in: a ___ of birds', 'flock', ['pack', 'deck', 'crew'], ''],
    [1, 'Fill in: a swarm of ___', 'bees', ['roses', 'stones', 'drawers'], ''],
    [2, 'Fill in: a ___ of sailors', 'crew', ['gang', 'team', 'colony'], ''],
    [2, 'Fill in: a ___ of ants', 'colony', ['crew', 'deck', 'set'], ''],
    [2, 'Fill in: a ___ of wolves', 'pack', ['flock', 'class', 'shoal'], ''],
    [2, 'Fill in: a ___ of thieves', 'gang', ['team', 'crew', 'deck'], ''],
    [2, 'Fill in: a ___ of tools', 'set', ['pack', 'colony', 'flock'], ''],
    [2, 'Fill in: a ___ of players', 'team', ['gang', 'murder', 'swarm'], ''],
    [2, 'Fill in: a constellation of ___', 'stars', ['fish', 'grass', 'sticks'], ''],
    [2, 'Fill in: a bundle of ___', 'sticks', ['stars', 'people', 'bees'], '', '', '', 'I collected a bundle of ___ for the bonfire.', 'sticks'],
    [2, 'Fill in: a chest of ___', 'drawers', ['roses', 'geese', 'grass'], ''],
    [2, '"The flock of birds ___ sitting on a wire."', 'is', ['are', 'were', 'be'], 'We use singular verbs with collective nouns.', 'We use plural verbs with collective nouns.', 'FALSE'],
    [1, 'What are concrete nouns?', 'Names of things that we can see, touch and feel', ['Names of feelings and ideas', 'Names of groups', 'Special names of places'], 'bucket, water, well, tree, mangoes, bag, school'],
    [1, 'What are abstract nouns?', 'Names of feelings, ideas, qualities or states that we cannot touch or see but only feel', ['Names of things we can touch', 'Names of groups of animals', 'Special names of people'], 'happiness, wisdom, strength, fear'],
    [1, 'Which of these is a concrete noun?', 'bucket', ['happiness', 'wisdom', 'fear'], ''],
    [2, '"The puppy trembled in fear." Which word is an abstract noun?', 'fear', ['puppy', 'trembled', 'in'], ''],
    [2, '"Rajiv\'s success brought his mother a lot of happiness." Which are the abstract nouns?', 'success and happiness', ['Rajiv and mother', 'mother and lot', 'brought and lot'], ''],
    [2, 'Abstract noun formed from "brave"', 'bravery', ['braveness', 'braved', 'bravely'], ''],
    [2, 'Abstract noun formed from "wise"', 'wisdom', ['wiseness', 'wisely', 'wisest'], ''],
    [2, 'Abstract noun formed from "child"', 'childhood', ['childship', 'childness', 'children'], ''],
    [2, 'Abstract noun formed from "friend"', 'friendship', ['friendhood', 'friendly', 'friendness'], ''],
    [3, 'Abstract noun formed from "accept"', 'acceptance', ['acception', 'acceptment', 'acceptness'], ''],
    [3, 'Abstract noun formed from "starve"', 'starvation', ['starvence', 'starvement', 'starvity'], ''],
    [3, 'Abstract noun formed from "advise"', 'advice', ['advisement', 'advision', 'advisor'], 'The verb is "advise" (with s); the noun is "advice" (with c).'],
    [3, 'Mahatma Gandhi fought for India\'s ___. (free)', 'freedom', ['freeness', 'freely', 'freehood'], '', '', '', 'Mahatma Gandhi fought for India\'s ___.', 'freedom'],
    [3, 'We should not show ___ to animals. (cruel)', 'cruelty', ['cruelness', 'cruelly', 'crueldom'], ''],
    [3, 'The wrestler is known for his ___. (strong)', 'strength', ['strongness', 'strongly', 'strongth'], ''],
    [3, 'I believe in the prisoner\'s ___. (innocent)', 'innocence', ['innocentness', 'innocency', 'innocently'], ''],
    [1, 'What is a compound noun?', 'A noun formed by joining two or more nouns', ['A noun with a capital letter', 'The name of a group', 'A noun we can only feel'], 'time + table = timetable; black + board = blackboard'],
    [2, '"I read the newspaper in the morning." Which word is a compound noun?', 'newspaper', ['morning', 'read', 'the'], ''],
    [2, 'tooth + ache = ?', 'toothache', ['toothpaste', 'toothbrush', 'teethache'], ''],
    [3, 'Which compound noun uses a hyphen?', 'well-being', ['timetable', 'blackboard', 'football'], 'Some compound words use hyphens to join two words, like dry-cleaning.'],
  ] },
  { title: 'Nouns: Singular and Plural', pairs: [['child', 'children'], ['mouse', 'mice'], ['leaf', 'leaves'], ['baby', 'babies'], ['box', 'boxes']], cards: [
    [1, 'What is a singular noun?', 'A noun used as the name of a single person, animal or thing', ['A noun for more than one thing', 'A noun for a group', 'A noun for a feeling'], '"I ate an egg for breakfast."'],
    [1, 'What is a plural noun?', 'A noun used as the name of more than one person, animal or thing', ['A noun for only one thing', 'A special name', 'A noun we cannot see'], '"Mr Sinha bought eggs from the grocery store."'],
    [1, 'Plural of "box"', 'boxes', ['boxs', 'boxies', 'boxen'], 'Nouns ending in s, ss, sh, ch, x add -es.'],
    [1, 'Plural of "baby"', 'babies', ['babys', 'babyes', 'babis'], 'Consonant + y: change y to i and add -es.'],
    [1, 'Plural of "boy"', 'boys', ['boies', 'boyes', 'boy'], 'Vowel + y: just add -s.'],
    [1, 'Plural of "child"', 'children', ['childs', 'childes', 'childrens'], ''],
    [2, 'Plural of "leaf"', 'leaves', ['leafs', 'leafes', 'leavs'], ''],
    [2, 'Plural of "mouse"', 'mice', ['mouses', 'mices', 'meese'], ''],
    [2, 'Plural of "tooth"', 'teeth', ['tooths', 'teeths', 'toothes'], ''],
    [2, 'Plural of "potato"', 'potatoes', ['potatos', 'potatoies', 'potato'], ''],
    [2, 'Plural of "sheep"', 'sheep', ['sheeps', 'shoop', 'sheepes'], 'Some nouns stay the same: sheep, deer, fish.', '"Sheeps" is the correct plural of sheep.', 'FALSE'],
    [3, 'Plural of "ox"', 'oxen', ['oxes', 'oxs', 'oxi'], ''],
    [3, 'Which noun is always used in the plural?', 'scissors', ['pencil', 'book', 'table'], 'Also trousers, spectacles.'],
    [3, 'Plural of "piano"', 'pianos', ['pianoes', 'pianies', 'piano'], ''],
  ] },
  { title: 'Nouns: Gender', pairs: [['king', 'queen'], ['lion', 'lioness'], ['nephew', 'niece'], ['horse', 'mare'], ['actor', 'actress']], cards: [
    [1, 'A noun that names a male is of which gender?', 'Masculine', ['Feminine', 'Common', 'Neuter'], 'boy, king, uncle'],
    [1, 'A noun that names a female is of which gender?', 'Feminine', ['Masculine', 'Common', 'Neuter'], 'girl, queen, aunt'],
    [1, 'What gender is "table"?', 'Neuter', ['Masculine', 'Feminine', 'Common'], 'Non-living things are neuter.'],
    [1, 'Feminine of "king"', 'queen', ['kingess', 'princess', 'lady'], ''],
    [2, 'What gender is "teacher"?', 'Common', ['Masculine', 'Feminine', 'Neuter'], 'It can be a man or a woman: teacher, friend, doctor.', '"Friend" is a neuter noun.', 'FALSE'],
    [2, 'Feminine of "lion"', 'lioness', ['lionine', 'liona', 'she-lion'], ''],
    [2, 'Feminine of "nephew"', 'niece', ['nephewess', 'cousin', 'aunt'], ''],
    [2, 'Feminine of "horse"', 'mare', ['horsess', 'filly', 'doe'], ''],
    [3, 'Masculine of "cow"', 'bull', ['ox', 'calf', 'buck'], ''],
    [3, 'Feminine of "hero"', 'heroine', ['heroess', 'heroin', 'shero'], ''],
  ] },
  { title: 'Nouns: Possession', pairs: [["the boy's bag", 'one boy'], ["the boys' bags", 'many boys'], ["children's park", 'plural without s'], ['legs of the table', 'non-living thing']], cards: [
    [1, 'Which mark do we use to show possession?', "Apostrophe (')", ['Comma', 'Full stop', 'Hyphen'], ''],
    [1, 'How do we show possession with most singular nouns?', "Add 's", ["Add s'", 'Add -es', 'Add nothing'], "the girl's book"],
    [2, 'How do we show possession with plural nouns ending in s?', "Add only an apostrophe after s", ["Add 's", 'Add -es', 'Add -ies'], "the girls' hostel"],
    [2, 'Which is correct?', "the children's toys", ["the childrens' toys", "the childrens toys", "the children toys'"], 'Plural nouns not ending in s take \'s.'],
    [2, '"The bag belongs to Ravi." Possessive form?', "Ravi's bag", ["Ravis' bag", 'Ravis bag', "Ravi bag's"], ''],
    [3, 'For non-living things, which is better?', 'the legs of the table', ["the table's legs", "the tables' leg", 'the table legs\''], ''],
    [3, '"the room of the teachers" in possessive form', "the teachers' room", ["the teacher's room", "the teachers's room", 'the teachers room'], ''],
  ] },
  { title: 'Subject and Predicate', pairs: [['Subject', 'who or what the sentence is about'], ['Predicate', 'what is said about the subject'], ['The dog', 'barked loudly'], ['Close the door', 'subject "you" is hidden']], cards: [
    [1, 'The part of a sentence that tells who or what it is about is called the…', 'Subject', ['Predicate', 'Object', 'Verb'], ''],
    [1, 'The part of a sentence that tells something about the subject is called the…', 'Predicate', ['Subject', 'Noun', 'Article'], ''],
    [1, '"The dog barked loudly." What is the subject?', 'The dog', ['barked', 'loudly', 'barked loudly'], ''],
    [2, '"My sister plays the flute." What is the predicate?', 'plays the flute', ['My sister', 'the flute', 'My'], ''],
    [2, '"Close the door." What is the subject?', 'You (it is hidden)', ['door', 'Close', 'the door'], 'In commands, the subject "you" is understood.', 'Every sentence must show its subject in words.', 'FALSE'],
    [3, '"Down the hill rolled the ball." What is the subject?', 'the ball', ['the hill', 'Down', 'rolled'], 'The subject can come after the predicate.'],
  ] },
  { title: 'Kinds of Sentences', pairs: [['Assertive', 'makes a statement'], ['Interrogative', 'asks a question'], ['Imperative', 'gives an order or request'], ['Exclamatory', 'shows strong feeling']], cards: [
    [1, 'A sentence that asks a question is…', 'Interrogative', ['Assertive', 'Imperative', 'Exclamatory'], 'It ends with a question mark (?).'],
    [1, 'A sentence that makes a statement is…', 'Assertive (declarative)', ['Interrogative', 'Imperative', 'Exclamatory'], ''],
    [1, '"Please shut the window." What kind of sentence is this?', 'Imperative', ['Assertive', 'Interrogative', 'Exclamatory'], 'It gives a command or makes a request.'],
    [1, '"What a beautiful garden!" What kind of sentence is this?', 'Exclamatory', ['Interrogative', 'Imperative', 'Assertive'], ''],
    [2, 'Which punctuation mark ends an exclamatory sentence?', 'Exclamation mark (!)', ['Full stop (.)', 'Question mark (?)', 'Comma (,)'], ''],
    [2, '"Where do you live" needs which mark at the end?', 'Question mark (?)', ['Full stop (.)', 'Exclamation mark (!)', 'Comma (,)'], '', '', '', 'Where do you live___', '?'],
    [3, '"Do not touch the wires." What kind of sentence is this?', 'Imperative', ['Interrogative', 'Exclamatory', 'Assertive'], 'Negative commands are imperative too.'],
  ] },
  { title: 'Adjectives', pairs: [['quality', 'brave, red'], ['quantity', 'some, much'], ['number', 'five, few'], ['demonstrative', 'this, those'], ['interrogative', 'which, whose']], cards: [
    [1, 'What is an adjective?', 'A word that describes a noun or pronoun', ['A word that shows action', 'A word that names a person', 'A word that joins sentences'], ''],
    [1, '"The tall boy won the race." Which word is an adjective?', 'tall', ['boy', 'won', 'race'], ''],
    [2, '"I have five pencils." "Five" is an adjective of…', 'number', ['quality', 'quantity', 'demonstration'], ''],
    [2, '"There is some milk in the jug." "Some" is an adjective of…', 'quantity', ['number', 'quality', 'interrogation'], 'Quantity adjectives go with things we cannot count.'],
    [2, '"This book is mine." "This" is a…', 'demonstrative adjective', ['quality adjective', 'number adjective', 'pronoun only'], 'this, that, these, those point out nouns.'],
    [2, '"Which dress do you like?" "Which" is a…', 'interrogative adjective', ['demonstrative adjective', 'number adjective', 'verb'], ''],
    [3, '"The clever fox tricked the crow." Adjective of what kind?', 'quality', ['quantity', 'number', 'possessive'], '', '"Clever" is an adjective of quantity.', 'FALSE'],
  ] },
  { title: 'Adjectives: Degrees of Comparison', pairs: [['good', 'better'], ['bad', 'worse'], ['big', 'bigger'], ['happy', 'happier'], ['little', 'less']], cards: [
    [1, 'How many degrees of comparison are there?', 'Three — positive, comparative, superlative', ['Two', 'Four', 'Five'], ''],
    [1, 'Comparative of "tall"', 'taller', ['tallest', 'more tall', 'tallier'], ''],
    [1, 'Superlative of "tall"', 'tallest', ['taller', 'most tall', 'tallist'], ''],
    [2, 'Comparative of "good"', 'better', ['gooder', 'best', 'more good'], ''],
    [2, 'Superlative of "bad"', 'worst', ['baddest', 'worse', 'most bad'], ''],
    [2, 'Comparative of "big"', 'bigger', ['biger', 'more big', 'biggest'], 'Short word ending in one vowel + consonant: double the last letter.'],
    [2, 'Comparative of "happy"', 'happier', ['happyer', 'more happy', 'happiest'], ''],
    [2, 'Superlative of "beautiful"', 'most beautiful', ['beautifullest', 'more beautiful', 'beautifulest'], 'Long adjectives use more / most.'],
    [3, 'Which degree is used to compare two things?', 'Comparative', ['Positive', 'Superlative', 'None'], '', 'We use the superlative degree to compare two things.', 'FALSE', 'Riya is ___ than Meena. (tall)', 'taller'],
    [3, 'Superlative of "many"', 'most', ['manyest', 'more', 'mostest'], ''],
  ] },
  { title: 'Pronouns', pairs: [['I, we, he, she', 'personal'], ['myself, themselves', 'reflexive'], ['mine, yours', 'possessive'], ['who, what', 'interrogative']], cards: [
    [1, 'What is a pronoun?', 'A word used in place of a noun', ['A word that describes a noun', 'A word that shows action', 'A naming word only'], ''],
    [1, '"Riya is my friend. ___ lives near my house."', 'She', ['He', 'It', 'They'], ''],
    [1, 'Which of these is a pronoun?', 'they', ['table', 'run', 'happy'], ''],
    [2, '"I hurt ___ while playing."', 'myself', ['me', 'mine', 'my'], 'myself, yourself, themselves are reflexive pronouns.'],
    [2, '"This pen is ___." (belongs to me)', 'mine', ['my', 'me', 'I'], ''],
    [2, '"___ is knocking at the door?"', 'Who', ['Whom', 'Which', 'Whose'], ''],
    [3, '"These are my books." vs "These books are mine." In the first sentence, "These" is a…', 'demonstrative pronoun', ['personal pronoun', 'reflexive pronoun', 'adjective'], 'When this/these stand alone for a noun, they are pronouns.'],
  ] },
  { title: 'Articles', pairs: [['a', 'before consonant sounds'], ['an', 'before vowel sounds'], ['the', 'a particular thing'], ['a, an', 'indefinite']], cards: [
    [1, 'How many articles are there in English?', 'Three — a, an, the', ['Two', 'Four', 'One'], ''],
    [1, '___ apple', 'an', ['a', 'the', 'no article'], ''],
    [1, '___ ball', 'a', ['an', 'the', 'no article'], ''],
    [2, '___ hour', 'an', ['a', 'the', 'no article'], 'The h is silent, so "hour" begins with a vowel sound.'],
    [2, '___ university', 'a', ['an', 'the', 'no article'], '"University" begins with a "yoo" sound.', 'We say "an university".', 'FALSE'],
    [2, '___ sun rises in the east.', 'The', ['A', 'An', 'no article'], 'Use "the" for things that are one of a kind.'],
    [2, 'Which is the definite article?', 'the', ['a', 'an', 'this'], ''],
    [3, '___ Ganga is a holy river.', 'The', ['A', 'An', 'no article'], 'Use "the" before names of rivers, seas and mountain ranges.'],
  ] },
  { title: 'Verbs', pairs: [['go', 'went'], ['eat', 'ate'], ['write', 'wrote'], ['see', 'saw'], ['sing', 'sang']], cards: [
    [1, 'What is a verb?', 'A word that shows an action or a state of being', ['A naming word', 'A describing word', 'A joining word'], ''],
    [1, '"The children danced happily." Which word is the verb?', 'danced', ['children', 'happily', 'The'], ''],
    [1, 'Past tense of "go"', 'went', ['goed', 'gone', 'goes'], ''],
    [2, 'Which is a helping verb?', 'is', ['run', 'eat', 'jump'], 'is, am, are, was, were, has, have, will help the main verb.'],
    [2, '"She is singing a song." Which is the main verb?', 'singing', ['is', 'song', 'She'], ''],
    [2, 'Past tense of "write"', 'wrote', ['writed', 'written', 'writes'], ''],
    [3, '"The baby slept." The verb has no object. It is…', 'intransitive', ['transitive', 'helping', 'irregular only'], '"She kicked the ball" — kicked has an object, so it is transitive.'],
  ] },
  { title: 'Simple Present and Present Continuous', pairs: [['habit', 'He walks daily'], ['happening now', 'He is walking'], ['universal truth', 'Water boils at 100 °C'], ['am/is/are + -ing', 'present continuous']], cards: [
    [1, 'Which tense shows habits and daily actions?', 'Simple present', ['Present continuous', 'Simple past', 'Future'], ''],
    [1, '"She ___ to school every day." (go)', 'goes', ['go', 'going', 'went'], '', '', '', 'She ___ to school every day.', 'goes'],
    [1, 'Which tense shows an action happening right now?', 'Present continuous', ['Simple present', 'Simple past', 'Past perfect'], ''],
    [2, '"Look! The baby ___." (cry)', 'is crying', ['cries', 'cry', 'cried'], ''],
    [2, '"The sun ___ in the east."', 'rises', ['is rising', 'rise', 'rose'], 'Universal truths use the simple present.'],
    [2, 'Present continuous is formed with…', 'am / is / are + verb + -ing', ['has / have + past participle', 'was / were + -ing', 'will + verb'], ''],
    [3, '"They ___ football now." (play)', 'are playing', ['plays', 'is playing', 'play'], '', '"They is playing" is correct.', 'FALSE'],
  ] },
  { title: 'Present Perfect Tense', pairs: [['has', 'he, she, it'], ['have', 'I, we, you, they'], ['since', 'point of time'], ['for', 'length of time']], cards: [
    [1, 'Present perfect is formed with…', 'has / have + past participle', ['had + past participle', 'is + -ing', 'will + verb'], ''],
    [1, '"I ___ finished my homework."', 'have', ['has', 'had', 'having'], ''],
    [2, '"She ___ just left."', 'has', ['have', 'is', 'were'], ''],
    [2, '"He has ___ the letter." (write)', 'written', ['wrote', 'writed', 'writing'], ''],
    [2, '"We have lived here ___ 2015."', 'since', ['for', 'from', 'by'], '"Since" with a point of time; "for" with a length of time.'],
    [3, '"They have known each other ___ ten years."', 'for', ['since', 'from', 'by'], '', '', '', 'I have waited ___ two hours.', 'for'],
  ] },
  { title: 'Simple Past and Past Continuous', pairs: [['walk', 'walked'], ['was reading', 'past continuous'], ['yesterday', 'simple past'], ['were', 'they, we, you']], cards: [
    [1, 'Which tense shows an action completed in the past?', 'Simple past', ['Past continuous', 'Simple present', 'Future'], ''],
    [1, '"We ___ a movie yesterday." (watch)', 'watched', ['watch', 'watching', 'watches'], ''],
    [2, 'Past continuous is formed with…', 'was / were + verb + -ing', ['is / are + -ing', 'had + past participle', 'will be + -ing'], ''],
    [2, '"I ___ reading when the bell rang."', 'was', ['were', 'am', 'is'], ''],
    [2, '"They ___ playing in the park at 5 p.m."', 'were', ['was', 'is', 'has'], ''],
    [3, '"While Mother ___ (cook), the lights went out."', 'was cooking', ['cooked', 'is cooking', 'cooks'], 'A longer past action interrupted by a short one.'],
  ] },
  { title: 'Past Perfect Tense', pairs: [['had', 'past perfect helper'], ['earlier action', 'had left'], ['later action', 'reached'], ['eaten', 'past participle of eat']], cards: [
    [1, 'Past perfect is formed with…', 'had + past participle', ['has + past participle', 'was + -ing', 'will have'], ''],
    [2, '"The train ___ left before we reached the station."', 'had', ['has', 'have', 'was'], 'Past perfect shows the earlier of two past actions.'],
    [2, '"She had ___ her lunch before I came." (eat)', 'eaten', ['ate', 'eat', 'eating'], ''],
    [3, 'In "When I reached, the show had started", which action happened first?', 'The show started', ['I reached', 'Both together', 'Neither'], '', 'Past perfect shows the later of two past actions.', 'FALSE'],
  ] },
  { title: 'Simple Future and Future Continuous Tense', pairs: [['will go', 'simple future'], ['will be going', 'future continuous'], ['tomorrow', 'future time'], ['shall', 'often with I and we']], cards: [
    [1, 'Simple future is formed with…', 'will / shall + base verb', ['was + -ing', 'has + past participle', 'had + past participle'], ''],
    [1, '"I ___ visit my grandmother tomorrow."', 'will', ['was', 'had', 'did'], ''],
    [2, 'Future continuous is formed with…', 'will be + verb + -ing', ['will + verb', 'is + -ing', 'had been + -ing'], ''],
    [2, '"At 8 p.m. tomorrow, we ___ dinner."', 'will be having', ['had', 'have had', 'were having'], ''],
    [3, 'Which sentence is in the future continuous tense?', 'She will be dancing at the show.', ['She will dance at the show.', 'She is dancing at the show.', 'She danced at the show.'], ''],
  ] },
  { title: 'Agreement of Subject and Verb', pairs: [['The boy', 'plays'], ['The boys', 'play'], ['Ram and Shyam', 'are'], ['Each of the girls', 'has']], cards: [
    [1, 'A singular subject takes a…', 'singular verb', ['plural verb', 'no verb', 'helping verb only'], ''],
    [1, '"The dogs ___ loudly."', 'bark', ['barks', 'is barking', 'has barked'], ''],
    [2, '"Ram and Shyam ___ friends."', 'are', ['is', 'was', 'has'], 'Two subjects joined by "and" take a plural verb.'],
    [2, '"Each of the students ___ a book."', 'has', ['have', 'are', 'were'], ''],
    [2, '"The news ___ good."', 'is', ['are', 'were', 'have'], '', '"News" takes a plural verb.', 'FALSE'],
    [3, '"Neither the teacher nor the students ___ present."', 'were', ['was', 'is', 'has'], 'With neither…nor, the verb agrees with the nearer subject.'],
  ] },
  { title: 'Adverbs', pairs: [['slowly', 'manner'], ['here', 'place'], ['yesterday', 'time'], ['always', 'frequency'], ['very', 'degree']], cards: [
    [1, 'What does an adverb do?', 'It tells more about a verb, adjective or another adverb', ['It names a person', 'It replaces a noun', 'It joins two words'], ''],
    [1, '"The tortoise walked slowly." Which word is the adverb?', 'slowly', ['tortoise', 'walked', 'The'], ''],
    [2, '"She always speaks the truth." "Always" is an adverb of…', 'frequency', ['place', 'manner', 'time'], ''],
    [2, '"Come here." "Here" is an adverb of…', 'place', ['time', 'manner', 'degree'], ''],
    [2, '"We will meet tomorrow." "Tomorrow" is an adverb of…', 'time', ['place', 'frequency', 'manner'], ''],
    [3, '"The tea is very hot." "Very" is an adverb of…', 'degree', ['manner', 'time', 'place'], 'It tells how much.'],
  ] },
  { title: 'Prepositions', pairs: [['at', '5 o\'clock'], ['on', 'Monday'], ['in', 'July'], ['between', 'two'], ['among', 'many']], cards: [
    [1, 'What does a preposition show?', 'The relation of a noun or pronoun to another word', ['An action', 'A feeling', 'A question'], 'in, on, under, behind, between'],
    [1, '"The cat is ___ the table." (below it)', 'under', ['on', 'in', 'at'], ''],
    [2, '"The school starts ___ 8 o\'clock."', 'at', ['on', 'in', 'by'], ''],
    [2, '"My birthday is ___ Monday."', 'on', ['in', 'at', 'by'], ''],
    [2, '"Divide the sweets ___ the two brothers."', 'between', ['among', 'in', 'with'], '"Between" for two; "among" for more than two.'],
    [3, '"Share the toys ___ all the children."', 'among', ['between', 'with', 'into'], '', '', '', 'The teacher distributed books ___ the students.', 'among'],
  ] },
  { title: 'Conjunctions', pairs: [['and', 'adds'], ['but', 'contrast'], ['or', 'choice'], ['because', 'reason'], ['so', 'result']], cards: [
    [1, 'What is a conjunction?', 'A word that joins words or sentences', ['A word that describes a noun', 'A naming word', 'An action word'], 'and, but, or, because, so'],
    [1, '"I like tea ___ coffee."', 'and', ['but', 'because', 'so'], ''],
    [2, '"He is poor ___ honest."', 'but', ['and', 'or', 'so'], ''],
    [2, '"Hurry up, ___ you will miss the bus."', 'or', ['and', 'but', 'because'], ''],
    [2, '"I stayed home ___ I was ill."', 'because', ['but', 'or', 'although'], ''],
    [3, '"___ it was raining, we went out."', 'Although', ['Because', 'So', 'Or'], ''],
  ] },
  { title: 'Direct and Indirect Speech', pairs: [['said to', 'told'], ['am', 'was'], ['today', 'that day'], ['here', 'there'], ['this', 'that']], cards: [
    [1, 'Which marks enclose the exact words of a speaker?', 'Quotation marks (" ")', ['Brackets', 'Hyphens', 'Commas only'], ''],
    [2, 'Direct: He said, "I am happy." Indirect?', 'He said that he was happy.', ['He said that I am happy.', 'He said that he is happy.', 'He told that I was happy.'], ''],
    [2, 'In indirect speech, "said to" usually becomes…', 'told', ['asked', 'spoke', 'say'], ''],
    [2, 'Direct: She said, "I like mangoes." Indirect?', 'She said that she liked mangoes.', ['She said that I like mangoes.', 'She said she likes mangoes.', 'She told that I liked mangoes.'], ''],
    [3, 'Direct: The teacher said, "Sit down." Indirect?', 'The teacher told us to sit down.', ['The teacher said that sit down.', 'The teacher asked if we sit down.', 'The teacher told sit down.'], 'Commands use told/ordered + to.'],
    [3, 'Direct: He said to me, "Are you ready?" Indirect?', 'He asked me if I was ready.', ['He told me that are you ready.', 'He said me if you are ready.', 'He asked me are you ready.'], ''],
  ] },
  { title: 'Punctuation and Capital Letters', pairs: [['.', 'full stop'], [',', 'comma'], ['?', 'question mark'], ['!', 'exclamation mark'], ["'", 'apostrophe']], cards: [
    [1, 'Which word is always written with a capital letter?', 'I', ['me', 'my', 'we'], ''],
    [1, 'Which of these needs a capital letter?', 'monday', ['table', 'river', 'happy'], 'Days, months, names of people and places start with capitals.'],
    [1, 'Which mark ends a statement?', 'Full stop (.)', ['Question mark', 'Comma', 'Apostrophe'], ''],
    [2, 'Which mark separates items in a list?', 'Comma (,)', ['Full stop', 'Apostrophe', 'Exclamation mark'], 'I bought apples, bananas and grapes.'],
    [2, 'In "rohan lives in delhi", which words need capital letters?', 'Rohan and Delhi', ['lives and in', 'only lives', 'none of them'], 'Names of people and places begin with capital letters.'],
    [3, 'In "can\'t", what does the apostrophe show?', 'A letter is left out (cannot)', ['Possession', 'A question', 'Plural'], ''],
  ] },
  { title: 'Grammar on the Go', pairs: [['noun', 'naming word'], ['verb', 'action word'], ['adjective', 'describing word'], ['adverb', 'tells how, when, where']], cards: [
    [1, '"The little girl sang sweetly." Which word is the adjective?', 'little', ['girl', 'sang', 'sweetly'], ''],
    [1, '"The little girl sang sweetly." Which word is the adverb?', 'sweetly', ['little', 'girl', 'The'], ''],
    [2, 'Correct the sentence: "She don\'t like milk."', "She doesn't like milk.", ["She don't likes milk.", "She not like milk.", "She doesn't likes milk."], ''],
    [2, 'Choose the correct sentence.', 'He has gone to school.', ['He have gone to school.', 'He has went to school.', 'He gone to school.'], ''],
    [3, 'Find the error: "Each of the boys have a bag."', 'have → has', ['Each → All', 'boys → boy', 'bag → bags'], ''],
  ] },
  { title: 'Words: A Mixed Bag', pairs: [['happy', 'glad'], ['brave', 'cowardly'], ['sea', 'see'], ['re-', 'again'], ['un-', 'not']], cards: [
    [1, 'A word with the same meaning as another is a…', 'synonym', ['antonym', 'homophone', 'prefix'], 'big — large'],
    [1, 'A word with the opposite meaning is an…', 'antonym', ['synonym', 'homophone', 'suffix'], 'hot — cold'],
    [1, 'Synonym of "happy"', 'glad', ['sad', 'angry', 'tired'], ''],
    [2, 'Antonym of "brave"', 'cowardly', ['bold', 'strong', 'daring'], ''],
    [2, 'Words that sound the same but have different meanings and spellings are…', 'homophones', ['synonyms', 'antonyms', 'compound words'], 'sea / see, son / sun'],
    [2, 'Add a prefix to make the opposite of "kind"', 'unkind', ['diskind', 'inkind', 'miskind'], ''],
    [3, 'One word for "a person who writes books"', 'author', ['editor', 'reader', 'printer'], ''],
    [3, '"Rewrite" means…', 'write again', ['write badly', 'not write', 'write before'], 'The prefix re- means again.'],
  ] },
  ...[
    ["Birbal's Wit", [['Birbal', 'Akbar\'s witty minister'], ['Akbar', 'Mughal emperor'], ['wit', 'quick clever thinking'], ['court', 'where the king meets people']]],
    ['Hard Times', [['hard times', 'difficult days'], ['hardship', 'suffering'], ['courage', 'bravery'], ['hope', 'expecting good']]],
    ['William Tell', [['William Tell', 'Swiss archer'], ['Gessler', 'cruel governor'], ['apple', 'on his son\'s head'], ['crossbow', 'his weapon']]],
    ['Feathered Friend', [['canary', 'small yellow bird'], ['space station', 'the setting'], ['air', 'what the bird sensed'], ['Arthur C. Clarke', 'the writer']]],
    ['Pirate Don Durk of Dowdee', [['pirate', 'robber of the sea'], ['Dowdee', 'Don Durk\'s home'], ['cutlass', 'curved sword'], ['poem', 'written in rhyme']]],
    ['Dinosaurs', [['dinosaurs', 'extinct reptiles'], ['fossils', 'remains in rock'], ['extinct', 'no longer living'], ['herbivore', 'plant eater']]],
    ['The Inchcape Rock', [['Inchcape Rock', 'dangerous rock at sea'], ['the bell', 'warned sailors'], ['Sir Ralph the Rover', 'cut the bell'], ['Abbot of Aberbrothok', 'placed the bell']]],
    ['Solomon and the Two Mothers', [['Solomon', 'wise king'], ['two mothers', 'claimed one baby'], ['sword', 'test of the true mother'], ['wisdom', 'good judgement']]],
    ['Boyhood Days', [['boyhood', 'time as a young boy'], ['memories', 'things remembered'], ['village', 'small place in the country'], ['autobiography', 'life story by oneself']]],
    ['Mangroves: Safeguarding the Land', [['mangroves', 'trees in salty coastal water'], ['Sundarbans', 'large mangrove forest'], ['erosion', 'wearing away of land'], ['coast', 'land beside the sea']]],
  ].map(([title, pairs]) => ({ title, draft: true, pairs, cards: [
    [1, `"${title}" is which kind of chapter in the book?`, 'A reading passage', ['A grammar rule', 'A test', 'A letter format'], 'Draft until the chapter pages are photographed.'],
  ] })),
  { title: 'Paragraph Writing', pairs: [['topic sentence', 'main idea'], ['supporting sentences', 'details'], ['concluding sentence', 'sums up'], ['one paragraph', 'one main idea']], cards: [
    [1, 'A paragraph should be about…', 'one main idea', ['many unrelated ideas', 'only one word', 'a list of names'], ''],
    [2, 'The sentence that tells the main idea of a paragraph is the…', 'topic sentence', ['concluding sentence', 'title', 'question'], 'It usually comes first.'],
    [2, 'Sentences that give details about the main idea are…', 'supporting sentences', ['topic sentences', 'headings', 'questions'], ''],
    [3, 'The last sentence that sums up a paragraph is the…', 'concluding sentence', ['topic sentence', 'supporting sentence', 'title'], ''],
  ] },
  { title: 'Letter Writing', pairs: [['informal letter', 'to friends and family'], ['formal letter', 'to principal or officials'], ['Dear Riya', 'informal greeting'], ['Yours faithfully', 'formal closing']], cards: [
    [1, 'A letter to a friend is a/an…', 'informal letter', ['formal letter', 'application', 'notice'], ''],
    [1, 'A letter to your principal asking for leave is a…', 'formal letter', ['informal letter', 'diary entry', 'story'], ''],
    [2, 'Where do we write the sender\'s address in a letter?', 'At the top, before the date', ['At the very end', 'In the middle', 'Nowhere'], ''],
    [2, 'Which closing suits a letter to your grandmother?', 'Your loving grandson / granddaughter', ['Yours faithfully', 'Yours obediently', 'Sincerely, Principal'], ''],
    [3, 'A formal letter should have a…', 'subject line stating its purpose', ['joke at the start', 'long story', 'drawing'], ''],
  ] },
  { title: 'Essay and Autobiography', pairs: [['introduction', 'beginning'], ['body', 'main points'], ['conclusion', 'ending'], ['autobiography', 'written in the first person']], cards: [
    [1, 'An essay has which three parts?', 'Introduction, body and conclusion', ['Title, date and signature', 'Question, answer and hint', 'Greeting, body and closing'], ''],
    [2, 'The story of a person\'s life written by that person is an…', 'autobiography', ['biography', 'essay', 'diary'], 'A biography is written by someone else.'],
    [2, 'An autobiography is written in which person?', 'First person (I, me, my)', ['Third person (he, she)', 'Second person (you)', 'No person'], ''],
    [3, 'An object telling its own life story ("I am a tree…") is an…', 'imaginary autobiography', ['biography', 'letter', 'notice'], ''],
  ] },
  { title: 'Story Writing', pairs: [['title', 'name of the story'], ['characters', 'people or animals in it'], ['moral', 'lesson of the story'], ['outline', 'hints in order']], cards: [
    [1, 'The lesson we learn from a story is its…', 'moral', ['title', 'character', 'setting'], ''],
    [2, 'The people or animals in a story are its…', 'characters', ['morals', 'titles', 'settings'], ''],
    [2, 'Stories are usually written in which tense?', 'Past tense', ['Future tense', 'Present continuous', 'Future continuous'], ''],
    [3, 'When writing from an outline, you should…', 'use all the hints in the given order', ['skip the hints', 'change the order', 'write only the moral'], ''],
  ] },
  { title: 'Diary Entry', pairs: [['diary', 'personal record'], ['date and day', 'at the top'], ['Dear Diary', 'common opening'], ['feelings', 'shared in a diary']], cards: [
    [1, 'A diary is a…', 'personal record of daily events and feelings', ['letter to the principal', 'news report', 'poem'], ''],
    [2, 'What do we write at the top of a diary entry?', 'The date and day', ['The address', 'The subject line', 'A moral'], ''],
    [2, 'A diary entry is usually written in which person?', 'First person', ['Third person', 'Second person', 'No person'], ''],
    [3, 'A diary entry about today\'s school trip is mostly written in the…', 'past tense', ['future tense', 'future continuous', 'no tense'], ''],
  ] },
];

const ix = Object.fromEntries(columns.Cards.map((c, i) => [c, i]));
const ids = new Set();
const newChapters = [];
const cardRows = [];
const pairRows = [];
let total = 0;
chapters.forEach((ch, i) => {
  const id = `c5-egr-${String(i + 1).padStart(2, '0')}`;
  ids.add(id);
  newChapters.push(['5', subject[0], String(i + 1), ch.title, id, ch.draft ? 'draft' : '']);
  ch.cards.forEach(([level, front, back, wrong, explain, tfS = '', tfA = '', blS = '', blA = ''], j) => {
    const row = columns.Cards.map(() => '');
    Object.assign(row, {
      [ix.chapter_id]: id, [ix.card_id]: `${id}-${String(j + 1).padStart(2, '0')}`, [ix.front]: front, [ix.back]: back,
      [ix.wrong_1]: wrong[0] ?? '', [ix.wrong_2]: wrong[1] ?? '', [ix.wrong_3]: wrong[2] ?? '',
      [ix.explain]: explain, [ix.tf_statement]: tfS, [ix.tf_answer]: tfA,
      [ix.blank_sentence]: blS, [ix.blank_answer]: blA, [ix.level]: String(level),
      [ix.source]: ch.fromPages ? fromPages : fromTitle,
      [ix.notes]: ch.fromPages ? '' : 'Check against the book pages',
    });
    cardRows.push(row);
  });
  for (const [l, r] of ch.pairs) pairRows.push([id, l, r]);
  total += ch.cards.length;
  const levels = [1, 2, 3].map((n) => ch.cards.filter((c) => c[0] === n).length).join('/');
  console.log(`${id}  Ch ${i + 1} ${ch.title}: ${ch.cards.length} cards (${levels})${ch.draft ? '  [draft]' : ''}`);
});

const subjects = [...tabs.Subjects.filter((r) => r[0] !== subject[0]), subject];
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
