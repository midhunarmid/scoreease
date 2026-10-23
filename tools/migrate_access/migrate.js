// One-time migration for v1.5.0.
//
// Before 1.5.0 each board stored its password hashes at scoreboards/{id}/access,
// readable by anyone. This moves them to secrets/{id} (unreadable by clients),
// writes the public flags to boardMeta/{id}, and removes the old access node.
//
// Usage (needs a service account key for the project):
//   GOOGLE_APPLICATION_CREDENTIALS=key.json node migrate.js           # dry run
//   GOOGLE_APPLICATION_CREDENTIALS=key.json node migrate.js --apply   # write
//
// Run it after the new app is live and before deploying database.rules.json.
// It is safe to run more than once.
const admin = require('firebase-admin');

const DATABASE_URL = process.env.DATABASE_URL || 'https://scoreease-98ed8-default-rtdb.firebaseio.com';
const apply = process.argv.includes('--apply');
const isHash = (value) => typeof value === 'string' && /^[0-9a-f]{64}$/.test(value);

async function main() {
  admin.initializeApp({ credential: admin.credential.applicationDefault(), databaseURL: DATABASE_URL });
  const db = admin.database();

  const [boards, metas] = await Promise.all([db.ref('scoreboards').get(), db.ref('boardMeta').get()]);
  const updates = {};
  let migrated = 0;

  boards.forEach((board) => {
    const id = board.key;
    const value = board.val() || {};
    const access = value.access || {};
    const existingMeta = metas.child(id).val();

    if (!existingMeta) {
      updates[`boardMeta/${id}`] = {
        ownerId: typeof value.ownerId === 'string' ? value.ownerId : '',
        readProtected: isHash(access.read),
        writeProtected: isHash(access.write),
        ownerProtected: isHash(access.owner),
      };
    }
    for (const level of ['read', 'write', 'owner']) {
      if (isHash(access[level])) updates[`secrets/${id}/${level}`] = access[level];
    }
    if (value.access !== undefined) updates[`scoreboards/${id}/access`] = null;
    if (!existingMeta || value.access !== undefined) migrated++;
  });

  console.log(`${boards.numChildren()} boards found, ${migrated} need migrating, ${Object.keys(updates).length} paths to write.`);
  if (!apply) {
    console.log('Dry run. Re-run with --apply to write these changes.');
    return;
  }
  if (Object.keys(updates).length > 0) await db.ref().update(updates);
  console.log('Done.');
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
