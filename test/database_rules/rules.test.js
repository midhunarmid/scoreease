// Tests for database.rules.json. Run with `npm test` from this folder; it
// starts the Realtime Database emulator, so Java and firebase-tools are needed.
const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const { ref, get, set, update, remove } = require('firebase/database');

const hash = (password) => crypto.createHash('sha256').update(password).digest('hex');

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-scoreease',
    database: {
      rules: fs.readFileSync(path.join(__dirname, '../../database.rules.json'), 'utf8'),
    },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearDatabase();
});

const db = (uid) => env.authenticatedContext(uid).database();

// The multi-path write the app makes when it creates a board.
function createBoard(uid, id, { read, write, owner } = {}) {
  const updates = {
    [`boardMeta/${id}`]: {
      ownerId: uid,
      readProtected: !!read,
      writeProtected: !!write,
      ownerProtected: !!owner,
    },
    [`scoreboards/${id}`]: { id, title: 'Game night', ownerId: uid, players: { ann: 0, bob: 0 } },
  };
  if (read) updates[`secrets/${id}/read`] = hash(read);
  if (write) updates[`secrets/${id}/write`] = hash(write);
  if (owner) updates[`secrets/${id}/owner`] = hash(owner);
  return update(ref(db(uid)), updates);
}

test('unauthenticated users cannot read or write anything', async () => {
  await assertSucceeds(createBoard('alice', 'open'));
  const anon = env.unauthenticatedContext().database();
  await assertFails(get(ref(anon, 'scoreboards/open')));
  await assertFails(set(ref(anon, 'scoreboards/open/players/ann'), 5));
});

test('nobody can list every board or read secrets', async () => {
  await assertSucceeds(createBoard('alice', 'b1', { read: 'pw' }));
  await assertFails(get(ref(db('alice'), 'scoreboards')));
  await assertFails(get(ref(db('alice'), 'secrets/b1')));
  await assertFails(get(ref(db('mallory'), 'secrets/b1')));
});

test('a taken ID cannot be created again', async () => {
  await assertSucceeds(createBoard('alice', 'b1'));
  await assertFails(createBoard('mallory', 'b1'));
});

test('a board cannot be created on behalf of someone else', async () => {
  const updates = {
    'boardMeta/b1': { ownerId: 'alice', readProtected: false, writeProtected: false, ownerProtected: false },
    'scoreboards/b1': { id: 'b1', title: 'x', ownerId: 'alice' },
  };
  await assertFails(update(ref(db('mallory')), updates));
});

test('open boards can be read and scored by anyone signed in', async () => {
  await assertSucceeds(createBoard('alice', 'b1'));
  await assertSucceeds(get(ref(db('bob'), 'scoreboards/b1')));
  await assertSucceeds(set(ref(db('bob'), 'scoreboards/b1/players/ann'), 3));
});

test('read-protected boards need the read password', async () => {
  await assertSucceeds(createBoard('alice', 'b1', { read: 'letmein' }));
  await assertSucceeds(get(ref(db('alice'), 'scoreboards/b1')));
  await assertSucceeds(get(ref(db('bob'), 'boardMeta/b1')));
  await assertFails(get(ref(db('bob'), 'scoreboards/b1')));

  await assertFails(set(ref(db('bob'), 'grants/b1/bob/read'), hash('wrong')));
  await assertFails(get(ref(db('bob'), 'scoreboards/b1')));

  await assertSucceeds(set(ref(db('bob'), 'grants/b1/bob/read'), hash('letmein')));
  await assertSucceeds(get(ref(db('bob'), 'scoreboards/b1')));
});

test('a grant stops working once the password changes', async () => {
  await assertSucceeds(createBoard('alice', 'b1', { read: 'old' }));
  await assertSucceeds(set(ref(db('bob'), 'grants/b1/bob/read'), hash('old')));
  await assertSucceeds(get(ref(db('bob'), 'scoreboards/b1')));

  await assertSucceeds(set(ref(db('alice'), 'secrets/b1/read'), hash('new')));
  await assertFails(get(ref(db('bob'), 'scoreboards/b1')));
  // The app re-checks a saved grant by rewriting it; that now fails.
  await assertFails(set(ref(db('bob'), 'grants/b1/bob/read'), hash('old')));
});

test('users cannot read or write grants of other users', async () => {
  await assertSucceeds(createBoard('alice', 'b1', { read: 'pw' }));
  await assertSucceeds(set(ref(db('bob'), 'grants/b1/bob/read'), hash('pw')));
  await assertFails(get(ref(db('mallory'), 'grants/b1/bob')));
  await assertFails(set(ref(db('mallory'), 'grants/b1/bob/read'), hash('pw')));
});

test('write-protected boards: readers can view but not score', async () => {
  await assertSucceeds(createBoard('alice', 'b1', { write: 'scorer' }));
  await assertSucceeds(get(ref(db('bob'), 'scoreboards/b1')));
  await assertFails(set(ref(db('bob'), 'scoreboards/b1/players/ann'), 10));

  await assertSucceeds(set(ref(db('bob'), 'grants/b1/bob/write'), hash('scorer')));
  await assertSucceeds(set(ref(db('bob'), 'scoreboards/b1/players/ann'), 10));
});

test('scorers can change scores but not board settings', async () => {
  await assertSucceeds(createBoard('alice', 'b1', { read: 'r', write: 'w' }));
  await assertSucceeds(set(ref(db('bob'), 'grants/b1/bob/write'), hash('w')));
  // The write password also lets you view.
  await assertSucceeds(get(ref(db('bob'), 'scoreboards/b1')));
  await assertSucceeds(update(ref(db('bob'), 'scoreboards/b1/players'), { ann: 1, bob: 2 }));
  await assertFails(set(ref(db('bob'), 'scoreboards/b1/title'), 'hacked'));
  await assertFails(set(ref(db('bob'), 'secrets/b1/read'), hash('mine')));
  await assertFails(remove(ref(db('bob'), 'scoreboards/b1')));
});

test('an open write level still respects the read password', async () => {
  await assertSucceeds(createBoard('alice', 'b1', { read: 'r' }));
  await assertFails(set(ref(db('bob'), 'scoreboards/b1/players/ann'), 1));
  await assertSucceeds(set(ref(db('bob'), 'grants/b1/bob/read'), hash('r')));
  await assertSucceeds(set(ref(db('bob'), 'scoreboards/b1/players/ann'), 1));
});

test('scores must be numbers', async () => {
  await assertSucceeds(createBoard('alice', 'b1'));
  await assertFails(set(ref(db('bob'), 'scoreboards/b1/players/ann'), 'lots'));
});

test('only the creator or an owner-password holder can edit settings', async () => {
  await assertSucceeds(createBoard('alice', 'b1', { owner: 'boss' }));
  await assertSucceeds(set(ref(db('alice'), 'scoreboards/b1/title'), 'Renamed'));
  await assertFails(set(ref(db('carol'), 'scoreboards/b1/title'), 'Mine now'));

  await assertSucceeds(set(ref(db('carol'), 'grants/b1/carol/owner'), hash('boss')));
  await assertSucceeds(set(ref(db('carol'), 'scoreboards/b1/title'), 'Mine now'));
  await assertSucceeds(set(ref(db('carol'), 'boardMeta/b1/readProtected'), true));
  await assertSucceeds(set(ref(db('carol'), 'secrets/b1/read'), hash('x')));
});

test('without an owner password only the creator can edit settings', async () => {
  await assertSucceeds(createBoard('alice', 'b1'));
  await assertFails(set(ref(db('bob'), 'scoreboards/b1/title'), 'nope'));
  await assertFails(set(ref(db('bob'), 'boardMeta/b1/writeProtected'), true));
});

test('ownership cannot be transferred', async () => {
  await assertSucceeds(createBoard('alice', 'b1', { owner: 'boss' }));
  await assertSucceeds(set(ref(db('carol'), 'grants/b1/carol/owner'), hash('boss')));
  await assertFails(set(ref(db('carol'), 'boardMeta/b1/ownerId'), 'carol'));
  await assertFails(set(ref(db('carol'), 'scoreboards/b1/ownerId'), 'carol'));
});

test('password hashes cannot be stored on the board itself', async () => {
  await assertSucceeds(createBoard('alice', 'b1'));
  await assertFails(set(ref(db('alice'), 'scoreboards/b1/access'), { read: hash('pw') }));
});

test('the owner can delete the board', async () => {
  await assertSucceeds(createBoard('alice', 'b1', { read: 'pw' }));
  await assertSucceeds(
    update(ref(db('alice')), { 'scoreboards/b1': null, 'boardMeta/b1': null, 'secrets/b1': null }),
  );
  let exists;
  await env.withSecurityRulesDisabled(async (ctx) => {
    exists = (await get(ref(ctx.database(), 'boardMeta/b1'))).exists();
  });
  assert.strictEqual(exists, false);
});

// ---- ScoreEase 2: live games under boards/{code} ----

let seq = 0;
// 20-char ids, like Firebase push ids.
const eventId = () => `-Ev${String(seq++).padStart(17, '0')}`;
const event = (uid, t = 'add', d = { p: 'p0', v: 1 }) => ({ t, d, ts: Date.now(), by: uid });

function shareBoard(uid, code, { read, write } = {}) {
  const updates = {
    [`boardMeta/${code}`]: { ownerId: uid, readProtected: !!read, writeProtected: !!write, ownerProtected: false },
    [`boards/${code}/meta`]: {
      title: 'Ping pong',
      template: 'tabletennis',
      mode: 'sets',
      settings: { points: 11, sets: 3, steps: '1' },
      participants: { p0: { name: 'Ann', color: 0 }, p1: { name: 'Reds', color: 1, members: { m0: 'Bob', m1: 'Cy' } } },
      createdAt: Date.now(),
    },
    [`boards/${code}/events/${eventId()}`]: event(uid, 'point', { p: 'p0' }),
  };
  if (read) updates[`secrets/${code}/read`] = hash(read);
  if (write) updates[`secrets/${code}/write`] = hash(write);
  return update(ref(db(uid)), updates);
}

test('boards: the owner can share a game with its events in one write', async () => {
  await assertSucceeds(shareBoard('alice', 'abc234'));
  await assertFails(shareBoard('mallory', 'abc234'));
});

test('boards: anyone signed in can watch and score an open game', async () => {
  await assertSucceeds(shareBoard('alice', 'abc234'));
  await assertSucceeds(get(ref(db('bob'), 'boards/abc234')));
  await assertSucceeds(set(ref(db('bob'), `boards/abc234/events/${eventId()}`), event('bob')));
});

test('boards: events cannot be forged, edited or deleted by scorers', async () => {
  await assertSucceeds(shareBoard('alice', 'abc234'));
  const id = eventId();
  await assertFails(set(ref(db('bob'), `boards/abc234/events/${id}`), event('alice')));
  await assertSucceeds(set(ref(db('bob'), `boards/abc234/events/${id}`), event('bob')));
  await assertFails(set(ref(db('bob'), `boards/abc234/events/${id}`), event('bob', 'add', { p: 'p0', v: 99 })));
  await assertFails(remove(ref(db('bob'), `boards/abc234/events/${id}`)));
  await assertFails(remove(ref(db('bob'), 'boards/abc234/events')));
});

test('boards: scorers can tag who scored', async () => {
  await assertSucceeds(shareBoard('alice', 'abc234'));
  const point = eventId();
  await assertSucceeds(set(ref(db('bob'), `boards/abc234/events/${point}`), event('bob', 'point', { p: 'p1' })));
  await assertSucceeds(set(ref(db('bob'), `boards/abc234/events/${eventId()}`), event('bob', 'tag', { target: point, m: { m0: 1, m1: 1 } })));
  await assertSucceeds(set(ref(db('bob'), `boards/abc234/events/${eventId()}`), event('bob', 'tag', { target: point })));
});

test('boards: scorers can change who is playing', async () => {
  await assertSucceeds(shareBoard('alice', 'abc234'));
  const side = eventId();
  await assertSucceeds(set(ref(db('bob'), `boards/abc234/events/${eventId()}`), event('bob', 'sub', { p: 'p0', o: 0, n: 'Bob' })));
  await assertSucceeds(set(ref(db('bob'), `boards/abc234/events/${eventId()}`), event('bob', 'sub', { p: 'p0', n: 'Bob' })));
  await assertSucceeds(set(ref(db('bob'), `boards/abc234/events/${side}`), event('bob', 'addSide', { n: 'Greens', c: 2, t: 't2', m0: 'Gus', m1: 'Hal' })));
  await assertSucceeds(set(ref(db('bob'), `boards/abc234/events/${eventId()}`), event('bob', 'retire', { p: 'p1' })));
  await assertSucceeds(set(ref(db('bob'), `boards/abc234/events/${eventId()}`), event('bob', 'rename', { f: 'Bbo', n: 'Bob' })));
  await assertSucceeds(set(ref(db('bob'), `boards/abc234/events/${eventId()}`), event('bob', 'round', { s: { p0: 1, [side]: 2 } })));
  await assertFails(set(ref(db('bob'), `boards/abc234/events/${eventId()}`), event('bob', 'sub', { p: 'p0', n: 'x'.repeat(41) })));
  await assertFails(set(ref(db('alice'), `boards/abc234/meta/participants/${side}`), { name: 'Greens' }));
});

test('boards: scorers cannot change the game setup', async () => {
  await assertSucceeds(shareBoard('alice', 'abc234'));
  await assertFails(set(ref(db('bob'), 'boards/abc234/meta/title'), 'hacked'));
  await assertSucceeds(set(ref(db('alice'), 'boards/abc234/meta/title'), 'Renamed'));
});

test('boards: view and scoring passwords', async () => {
  await assertSucceeds(shareBoard('alice', 'abc234', { read: 'watch', write: 'score' }));
  await assertFails(get(ref(db('bob'), 'boards/abc234')));
  await assertSucceeds(set(ref(db('bob'), 'grants/abc234/bob/read'), hash('watch')));
  await assertSucceeds(get(ref(db('bob'), 'boards/abc234')));
  await assertFails(set(ref(db('bob'), `boards/abc234/events/${eventId()}`), event('bob')));
  await assertSucceeds(set(ref(db('bob'), 'grants/abc234/bob/write'), hash('score')));
  await assertSucceeds(set(ref(db('bob'), `boards/abc234/events/${eventId()}`), event('bob')));
});

test('boards: event games can be placements with players on event teams', async () => {
  await assertSucceeds(shareBoard('alice', 'abc234'));
  await assertSucceeds(set(ref(db('alice'), 'boards/abc234/meta/mode'), 'placements'));
  await assertSucceeds(set(ref(db('alice'), 'boards/abc234/meta/participants/p2'), { name: 'Dee', color: 1, team: 't1' }));
  await assertFails(set(ref(db('alice'), 'boards/abc234/meta/participants/p3'), { name: 'Eve', team: 'x'.repeat(21) }));
  await assertSucceeds(set(ref(db('bob'), `boards/abc234/events/${eventId()}`), event('bob', 'place', { p: 'p2' })));
});

test('boards: malformed data is rejected', async () => {
  await assertSucceeds(shareBoard('alice', 'abc234'));
  await assertFails(set(ref(db('alice'), 'boards/abc234/meta/mode'), 'poker'));
  await assertFails(set(ref(db('alice'), 'boards/abc234/meta/participants/p50'), { name: 'Too many' }));
  await assertFails(set(ref(db('alice'), 'boards/abc234/extra'), 1));
  await assertFails(set(ref(db('bob'), 'boards/abc234/events/short'), event('bob')));
  await assertFails(set(ref(db('bob'), `boards/abc234/events/${eventId()}`), { ...event('bob'), ts: Date.now() + 3600000 }));
});

test('boards: the owner can stop sharing', async () => {
  await assertSucceeds(shareBoard('alice', 'abc234', { read: 'pw' }));
  await assertFails(update(ref(db('bob')), { 'boards/abc234': null, 'boardMeta/abc234': null }));
  await assertSucceeds(update(ref(db('alice')), { 'boards/abc234': null, 'boardMeta/abc234': null, 'secrets/abc234': null }));
});

test('legacy team entries are validated', async () => {
  await assertSucceeds(createBoard('alice', 'b1'));
  await assertSucceeds(set(ref(db('alice'), 'scoreboards/b1/teams/t1'), { name: 'Reds', players: { ann: true } }));
  await assertFails(set(ref(db('alice'), 'scoreboards/b1/teams/t2'), { name: 'Blues', junk: 1 }));
});
