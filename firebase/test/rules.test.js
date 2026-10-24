// Security rules tests. Run with `npm test`, which starts the Firestore
// emulator; nothing here touches staging or prod.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  arrayUnion,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  setLogLevel,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

// Denied writes are the point of half these tests; don't log each one.
setLogLevel('silent');

const PARENT_PHONE = '9876543210';
const OTHER_PHONE = '9123456789';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-revup',
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
});

after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

// ---- Signed-in contexts ----------------------------------------------------

const parent = () =>
  env.authenticatedContext('parent1', { phone_number: `+91${PARENT_PHONE}` }).firestore();
const otherParent = () =>
  env.authenticatedContext('parent2', { phone_number: `+91${OTHER_PHONE}` }).firestore();
const teacher = () =>
  env.authenticatedContext('teacher1', { phone_number: '+919000000001' }).firestore();
const student = () => env.authenticatedContext('student1').firestore();
const stranger = () => env.authenticatedContext('stranger').firestore();
const anon = () => env.unauthenticatedContext().firestore();

/** Writes [docs] ({path: data}) with the rules switched off. */
async function seed(docs) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [path, data] of Object.entries(docs)) {
      await setDoc(doc(db, path), data);
    }
  });
}

const now = () => Timestamp.now();

const users = {
  'users/parent1': { role: 'parent', phone: `+91${PARENT_PHONE}` },
  'users/parent2': { role: 'parent', phone: `+91${OTHER_PHONE}` },
  'users/teacher1': { role: 'teacher', phone: '+919000000001' },
  'users/student1': { role: 'student' },
};

const aChild = {
  parentUid: 'parent1',
  name: 'Aarav',
  classLevel: 2,
  avatar: 1,
  createdAt: now(),
};

const aClass = {
  teacherUid: 'teacher1',
  school: 'KV',
  subjectId: 'science',
  classLevel: 8,
  section: 'B',
  joinCode: 'K7M2QX',
  size: 30,
  memberUids: [],
  createdAt: now(),
};

// ---- Users -----------------------------------------------------------------

describe('users', () => {
  test('a parent creates their own record with their own number', async () => {
    await assertSucceeds(
      setDoc(doc(parent(), 'users/parent1'), {
        role: 'parent',
        phone: `+91${PARENT_PHONE}`,
        createdAt: serverTimestamp(),
      }),
    );
  });

  test('cannot claim someone else\'s number', async () => {
    await assertFails(
      setDoc(doc(parent(), 'users/parent1'), {
        role: 'parent',
        phone: `+91${OTHER_PHONE}`,
        createdAt: serverTimestamp(),
      }),
    );
  });

  test('a teacher needs a phone sign-in', async () => {
    await assertFails(
      setDoc(doc(student(), 'users/student1'), {
        role: 'teacher',
        createdAt: serverTimestamp(),
      }),
    );
  });

  test('cannot write another user\'s record', async () => {
    await assertFails(
      setDoc(doc(stranger(), 'users/parent1'), {
        role: 'student',
        createdAt: serverTimestamp(),
      }),
    );
  });

  test('cannot read another user, or change role later', async () => {
    await seed(users);
    await assertFails(getDoc(doc(stranger(), 'users/parent1')));
    await assertSucceeds(getDoc(doc(parent(), 'users/parent1')));
    await assertFails(updateDoc(doc(parent(), 'users/parent1'), { role: 'teacher' }));
  });

  test('signed-out visitors see nothing', async () => {
    await seed(users);
    await assertFails(getDoc(doc(anon(), 'users/parent1')));
  });
});

// ---- Children --------------------------------------------------------------

describe('children', () => {
  beforeEach(() => seed(users));

  test('a parent adds a child', async () => {
    await assertSucceeds(
      setDoc(doc(parent(), 'children/c1'), {
        parentUid: 'parent1',
        name: 'Aarav',
        classLevel: 2,
        avatar: 1,
        createdAt: serverTimestamp(),
      }),
    );
  });

  test('a teacher cannot add children', async () => {
    await assertFails(
      setDoc(doc(teacher(), 'children/c1'), {
        parentUid: 'teacher1',
        name: 'Aarav',
        classLevel: 2,
        avatar: 1,
        createdAt: serverTimestamp(),
      }),
    );
  });

  test('a parent cannot link a student login without an approved request', async () => {
    await assertFails(
      setDoc(doc(parent(), 'children/c1'), {
        parentUid: 'parent1',
        studentUid: 'student1',
        fromRequest: 'nope',
        name: 'Diya',
        classLevel: 8,
        avatar: 0,
        createdAt: serverTimestamp(),
      }),
    );
  });

  test('only the family reads a child and their progress', async () => {
    await seed({ 'children/c1': { ...aChild, studentUid: 'student1' } });
    await assertSucceeds(getDoc(doc(parent(), 'children/c1')));
    await assertSucceeds(getDoc(doc(student(), 'children/c1')));
    await assertFails(getDoc(doc(otherParent(), 'children/c1')));
    await assertFails(getDoc(doc(teacher(), 'children/c1')));

    await assertSucceeds(setDoc(doc(student(), 'children/c1/progress/cards'), { n: 1 }));
    await assertFails(setDoc(doc(stranger(), 'children/c1/progress/cards'), { n: 1 }));
  });

  test('the parent cannot hand the child to someone else', async () => {
    await seed({ 'children/c1': aChild });
    await assertSucceeds(updateDoc(doc(parent(), 'children/c1'), { name: 'Aaru' }));
    await assertFails(updateDoc(doc(parent(), 'children/c1'), { parentUid: 'parent2' }));
  });
});

// ---- Student sign-up -------------------------------------------------------

describe('approval requests', () => {
  beforeEach(() => seed(users));

  const request = {
    studentUid: 'student1',
    name: 'Diya',
    classLevel: 8,
    avatar: 2,
    parentPhone: PARENT_PHONE,
    status: 'pending',
  };

  test('a student asks their parent', async () => {
    await assertSucceeds(
      setDoc(doc(student(), 'approvalRequests/r1'), {
        ...request,
        createdAt: serverTimestamp(),
      }),
    );
  });

  test('only Classes 6–10 sign up themselves, and cannot pre-approve', async () => {
    await assertFails(
      setDoc(doc(student(), 'approvalRequests/r1'), {
        ...request,
        classLevel: 4,
        createdAt: serverTimestamp(),
      }),
    );
    await assertFails(
      setDoc(doc(student(), 'approvalRequests/r1'), {
        ...request,
        status: 'approved',
        createdAt: serverTimestamp(),
      }),
    );
  });

  test('the named parent sees it, approves it and links the child at once', async () => {
    await seed({ 'approvalRequests/r1': { ...request, createdAt: now() } });
    const db = parent();
    const mine = await assertSucceeds(
      getDocs(query(collection(db, 'approvalRequests'), where('parentPhone', '==', PARENT_PHONE))),
    );
    if (mine.size !== 1) throw new Error(`expected 1 request, got ${mine.size}`);

    const batch = writeBatch(db);
    batch.update(doc(db, 'approvalRequests/r1'), {
      status: 'approved',
      decidedAt: serverTimestamp(),
    });
    batch.set(doc(db, 'children/c1'), {
      parentUid: 'parent1',
      studentUid: 'student1',
      fromRequest: 'r1',
      name: 'Diya',
      classLevel: 8,
      avatar: 2,
      createdAt: serverTimestamp(),
    });
    await assertSucceeds(batch.commit());
    await assertSucceeds(getDoc(doc(student(), 'children/c1')));
  });

  test('another parent can neither see nor approve it', async () => {
    await seed({ 'approvalRequests/r1': { ...request, createdAt: now() } });
    await assertFails(getDoc(doc(otherParent(), 'approvalRequests/r1')));
    await assertFails(
      updateDoc(doc(otherParent(), 'approvalRequests/r1'), {
        status: 'approved',
        decidedAt: serverTimestamp(),
      }),
    );
  });

  test('another parent cannot link the student even after approval', async () => {
    await seed({
      'approvalRequests/r1': { ...request, status: 'approved', createdAt: now() },
    });
    await assertFails(
      setDoc(doc(otherParent(), 'children/c9'), {
        parentUid: 'parent2',
        studentUid: 'student1',
        fromRequest: 'r1',
        name: 'Diya',
        classLevel: 8,
        avatar: 2,
        createdAt: serverTimestamp(),
      }),
    );
  });

  test('the link expires after 48 hours', async () => {
    const old = Timestamp.fromMillis(Date.now() - 49 * 3600 * 1000);
    await seed({ 'approvalRequests/r1': { ...request, createdAt: old } });
    await assertFails(
      updateDoc(doc(parent(), 'approvalRequests/r1'), {
        status: 'approved',
        decidedAt: serverTimestamp(),
      }),
    );
  });

  test('the student can withdraw it; others cannot', async () => {
    await seed({ 'approvalRequests/r1': { ...request, createdAt: now() } });
    await assertFails(deleteDoc(doc(stranger(), 'approvalRequests/r1')));
    await assertSucceeds(deleteDoc(doc(student(), 'approvalRequests/r1')));
  });
});

// ---- Classes ---------------------------------------------------------------

describe('classes', () => {
  beforeEach(() => seed(users));

  async function createClass(db, teacherUid = 'teacher1') {
    const batch = writeBatch(db);
    batch.set(doc(db, 'classes/k1'), {
      ...aClass,
      teacherUid,
      createdAt: serverTimestamp(),
    });
    batch.set(doc(db, 'joinCodes/K7M2QX'), { classId: 'k1', teacherUid, classLevel: 8 });
    return batch.commit();
  }

  test('a teacher creates a class and its join code together', async () => {
    await assertSucceeds(createClass(teacher()));
  });

  test('a parent cannot create a class', async () => {
    await assertFails(createClass(parent(), 'parent1'));
  });

  test('codes can be looked up one at a time but not listed', async () => {
    await seed({ 'classes/k1': aClass, 'joinCodes/K7M2QX': { classId: 'k1', teacherUid: 'teacher1' } });
    await assertSucceeds(getDoc(doc(parent(), 'joinCodes/K7M2QX')));
    await assertFails(getDocs(collection(parent(), 'joinCodes')));
    await assertFails(getDoc(doc(anon(), 'joinCodes/K7M2QX')));
  });

  test('outsiders cannot read a class', async () => {
    await seed({ 'classes/k1': aClass });
    await assertSucceeds(getDoc(doc(teacher(), 'classes/k1')));
    await assertFails(getDoc(doc(parent(), 'classes/k1')));
  });

  function join(db, joinerUid, childId, { name = 'Aarav', uids, approved }) {
    const batch = writeBatch(db);
    batch.update(doc(db, 'classes/k1'), { memberUids: arrayUnion(joinerUid) });
    batch.set(doc(db, `classes/k1/members/${childId}`), {
      uids,
      name,
      parentApproved: approved,
      joinedAt: serverTimestamp(),
    });
    return batch.commit();
  }

  test('a parent joins their child, which counts as approval', async () => {
    await seed({ 'classes/k1': aClass, 'children/c1': aChild });
    await assertSucceeds(
      join(parent(), 'parent1', 'c1', { uids: ['parent1'], approved: true }),
    );
    await assertSucceeds(getDoc(doc(parent(), 'classes/k1')));
    await assertSucceeds(getDocs(collection(teacher(), 'classes/k1/members')));
  });

  test('cannot join someone else\'s child or add other people', async () => {
    await seed({ 'classes/k1': aClass, 'children/c1': aChild });
    await assertFails(
      join(otherParent(), 'parent2', 'c1', { uids: ['parent1'], approved: true }),
    );
    await assertFails(
      updateDoc(doc(parent(), 'classes/k1'), { memberUids: arrayUnion('parent2') }),
    );
  });

  test('a student joining waits for the parent before sharing progress', async () => {
    await seed({
      'classes/k1': aClass,
      'children/c1': { ...aChild, name: 'Diya', classLevel: 8, studentUid: 'student1' },
    });
    // Cannot pretend the parent already agreed.
    await assertFails(
      join(student(), 'student1', 'c1', {
        name: 'Diya',
        uids: ['parent1', 'student1'],
        approved: true,
      }),
    );
    await assertSucceeds(
      join(student(), 'student1', 'c1', {
        name: 'Diya',
        uids: ['parent1', 'student1'],
        approved: false,
      }),
    );

    const progress = { lastActive: serverTimestamp(), mastery: 0.7 };
    await assertFails(updateDoc(doc(student(), 'classes/k1/members/c1'), progress));
    await assertFails(
      updateDoc(doc(student(), 'classes/k1/members/c1'), { parentApproved: true }),
    );
    await assertSucceeds(
      updateDoc(doc(parent(), 'classes/k1/members/c1'), { parentApproved: true }),
    );
    await assertSucceeds(updateDoc(doc(student(), 'classes/k1/members/c1'), progress));
  });

  test('the teacher cannot add students, only remove them', async () => {
    await seed({ 'classes/k1': { ...aClass, memberUids: ['parent1'] } });
    await assertFails(
      updateDoc(doc(teacher(), 'classes/k1'), { memberUids: arrayUnion('parent2') }),
    );
    await assertSucceeds(updateDoc(doc(teacher(), 'classes/k1'), { memberUids: [] }));
  });
});

// ---- Assignments -----------------------------------------------------------

describe('assignments', () => {
  beforeEach(() =>
    seed({
      ...users,
      'classes/k1': { ...aClass, memberUids: ['parent1', 'parent2'] },
      'children/c1': aChild,
      'children/c2': { ...aChild, parentUid: 'parent2', name: 'Meera' },
      'classes/k1/members/c1': { uids: ['parent1'], name: 'Aarav', parentApproved: true, joinedAt: now() },
      'classes/k1/members/c2': { uids: ['parent2'], name: 'Meera', parentApproved: false, joinedAt: now() },
      'classes/k1/assignments/a1': {
        kind: 'quiz',
        subjectId: 'science',
        chapterId: 'c8-sci-01',
        due: now(),
        createdAt: now(),
      },
    }),
  );

  const quiz = {
    kind: 'quiz',
    subjectId: 'science',
    chapterId: 'c8-sci-02',
    due: Timestamp.fromMillis(Date.now() + 86400000),
    createdAt: Timestamp.now(),
  };

  test('the teacher sets work; members read it; members cannot set it', async () => {
    await assertSucceeds(setDoc(doc(teacher(), 'classes/k1/assignments/a2'), quiz));
    await assertSucceeds(getDocs(collection(parent(), 'classes/k1/assignments')));
    await assertFails(setDoc(doc(parent(), 'classes/k1/assignments/a3'), quiz));
    await assertFails(getDocs(collection(stranger(), 'classes/k1/assignments')));
  });

  const result = (score) => ({
    score,
    total: 10,
    answers: [],
    finishedAt: serverTimestamp(),
  });

  test('an approved member hands in their own work', async () => {
    await assertSucceeds(
      setDoc(doc(parent(), 'classes/k1/assignments/a1/submissions/c1'), result(8)),
    );
    await assertSucceeds(getDoc(doc(teacher(), 'classes/k1/assignments/a1/submissions/c1')));
  });

  test('no impossible scores, no handing in for others', async () => {
    await assertFails(
      setDoc(doc(parent(), 'classes/k1/assignments/a1/submissions/c1'), result(11)),
    );
    await assertFails(
      setDoc(doc(otherParent(), 'classes/k1/assignments/a1/submissions/c1'), result(8)),
    );
  });

  test('nothing is handed in before the parent approves', async () => {
    await assertFails(
      setDoc(doc(otherParent(), 'classes/k1/assignments/a1/submissions/c2'), result(5)),
    );
  });

  test('classmates cannot see each other\'s scores', async () => {
    await seed({
      'classes/k1/assignments/a1/submissions/c1': { score: 8, total: 10, answers: [], finishedAt: now() },
    });
    await assertFails(getDoc(doc(otherParent(), 'classes/k1/assignments/a1/submissions/c1')));
  });
});

// ---- The app's own flows -----------------------------------------------------
// Mirrors FirebaseAccountService call for call, so a query the rules would
// reject on a real phone fails here first.

describe('app flows', () => {
  test('student signs up, parent approves, student finds their child', async () => {
    await seed({ 'users/parent1': users['users/parent1'] });
    // requestApproval (anonymous student)
    await assertSucceeds(
      setDoc(doc(student(), 'approvalRequests/r1'), {
        studentUid: 'student1',
        name: 'Diya',
        classLevel: 8,
        avatar: 2,
        parentPhone: PARENT_PHONE,
        status: 'pending',
        createdAt: serverTimestamp(),
      }),
    );
    // requestsForMe
    const db = parent();
    const pending = await assertSucceeds(
      getDocs(
        query(
          collection(db, 'approvalRequests'),
          where('parentPhone', '==', PARENT_PHONE),
          where('status', '==', 'pending'),
        ),
      ),
    );
    if (pending.size !== 1) throw new Error('parent should see the request');
    // approve: read studentUid, then batch
    const req = await assertSucceeds(getDoc(doc(db, 'approvalRequests/r1')));
    const batch = writeBatch(db);
    batch.update(doc(db, 'approvalRequests/r1'), { status: 'approved', decidedAt: serverTimestamp() });
    batch.set(doc(db, 'children/c1'), {
      parentUid: 'parent1',
      studentUid: req.data().studentUid,
      fromRequest: 'r1',
      name: 'Diya',
      classLevel: 8,
      avatar: 2,
      createdAt: serverTimestamp(),
    });
    await assertSucceeds(batch.commit());
    // approvedChildId
    await assertSucceeds(getDoc(doc(student(), 'approvalRequests/r1')));
    const mine = await assertSucceeds(
      getDocs(query(collection(student(), 'children'), where('studentUid', '==', 'student1'))),
    );
    if (mine.docs[0]?.id !== 'c1') throw new Error('student should find c1');
    // register student
    await assertSucceeds(
      setDoc(doc(student(), 'users/student1'), { role: 'student', createdAt: serverTimestamp() }),
    );
  });

  test('parent restores children and saves edits', async () => {
    await seed({ 'users/parent1': users['users/parent1'], 'children/c1': aChild });
    const got = await assertSucceeds(
      getDocs(query(collection(parent(), 'children'), where('parentUid', '==', 'parent1'))),
    );
    if (got.size !== 1) throw new Error('expected one child');
    // saveChild: get then update
    await assertSucceeds(getDoc(doc(parent(), 'children/c1')));
    await assertSucceeds(
      updateDoc(doc(parent(), 'children/c1'), { name: 'Aaru', classLevel: 3, avatar: 2 }),
    );
    // saveChild for a new one: get (missing) then set
    await assertSucceeds(getDoc(doc(parent(), 'children/c2')));
  });

  test('teacher makes a class, student joins by code, work flows both ways', async () => {
    await seed({
      ...users,
      'children/c1': { ...aChild, name: 'Diya', classLevel: 8, studentUid: 'student1' },
    });
    // createClass: code free? then batch
    const t = teacher();
    await assertSucceeds(getDoc(doc(t, 'joinCodes/K7M2QX')));
    const b = writeBatch(t);
    b.set(doc(t, 'classes/k1'), { ...aClass, createdAt: serverTimestamp() });
    b.set(doc(t, 'joinCodes/K7M2QX'), { classId: 'k1', teacherUid: 'teacher1', classLevel: 8 });
    await assertSucceeds(b.commit());
    // loadClasses
    await assertSucceeds(
      getDocs(query(collection(t, 'classes'), where('teacherUid', '==', 'teacher1'))),
    );
    // joinClass by the student's own login
    const s = student();
    const code = await assertSucceeds(getDoc(doc(s, 'joinCodes/K7M2QX')));
    if (code.data().classLevel !== 8) throw new Error('code should carry the class');
    // Not a member yet: the app treats a denied read as "not in".
    await assertFails(getDoc(doc(s, 'classes/k1/members/c1')));
    const child = await assertSucceeds(getDoc(doc(s, 'children/c1')));
    const jb = writeBatch(s);
    jb.update(doc(s, 'classes/k1'), { memberUids: arrayUnion('student1') });
    jb.set(doc(s, 'classes/k1/members/c1'), {
      uids: [child.data().parentUid, 'student1'],
      name: child.data().name,
      parentApproved: false,
      joinedAt: serverTimestamp(),
    });
    await assertSucceeds(jb.commit());
    // The parent approves sharing.
    await assertSucceeds(updateDoc(doc(parent(), 'classes/k1/members/c1'), { parentApproved: true }));

    // Teacher loads members and sets a quiz.
    await assertSucceeds(getDocs(collection(t, 'classes/k1/members')));
    await assertSucceeds(
      getDocs(query(collection(t, 'classes/k1/assignments'))),
    );
    await assertSucceeds(
      setDoc(doc(t, 'classes/k1/assignments/a1'), {
        kind: 'quiz',
        subjectId: 'science',
        chapterId: 'c8-sci-01',
        due: Timestamp.fromMillis(Date.now() + 86400000),
        createdAt: Timestamp.now(),
      }),
    );

    // assignmentsFor: classes containing me, my member row, work, my submission
    const mineClasses = await assertSucceeds(
      getDocs(query(collection(s, 'classes'), where('memberUids', 'array-contains', 'student1'))),
    );
    if (mineClasses.size !== 1) throw new Error('student should see the class');
    await assertSucceeds(getDoc(doc(s, 'classes/k1/members/c1')));
    await assertSucceeds(getDocs(collection(s, 'classes/k1/assignments')));
    await assertSucceeds(getDoc(doc(s, 'classes/k1/assignments/a1/submissions/c1')));

    // submit
    await assertSucceeds(
      setDoc(doc(s, 'classes/k1/assignments/a1/submissions/c1'), {
        score: 7,
        total: 10,
        answers: [{ cardId: 'c8s1-01', right: false, given: 'Crops sown in winter' }],
        finishedAt: serverTimestamp(),
      }),
    );
    // results
    await assertSucceeds(getDocs(collection(t, 'classes/k1/assignments/a1/submissions')));
  });
});
