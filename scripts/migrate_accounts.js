/**
 * One-time migration for the phone + password account redesign.
 *
 * Run with the Firebase CLI logged in (`firebase login`) as a project
 * owner/editor:
 *
 *   node scripts/migrate_accounts.js            # dry run (report only)
 *   node scripts/migrate_accounts.js --apply    # backfill ownerPhoneKey
 *   node scripts/migrate_accounts.js --apply --dedup
 *                                               # also soft-tombstone
 *                                               # duplicate shops
 *
 * What it does:
 *   1. Backfills `ownerPhoneKey` on every /shops doc from `ownerPhone`
 *      (using the SAME normalization as lib/services/cloud/user_auth_service.dart),
 *      so a returning owner can claim their shop by phone in-app.
 *   2. Reports duplicate shops (same ownerPhoneKey) and, with --dedup,
 *      marks the non-canonical ones `{deleted:true, deletedReason:...}`.
 *      Canonical = approved first, then oldest createdAt.
 *   3. Reports orphaned member docs (member uid has no /users profile and
 *      is not the shop owner) so an owner can clean them up in-app.
 *
 * Identity itself is migrated lazily: each owner logs in with their phone
 * + a new password, and the app re-binds ownerUid via the claim path.
 */
const fs = require('fs');
const os = require('os');

const CLIENT_ID =
  '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';
const PROJECT = 'alex-pos';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;

const APPLY = process.argv.includes('--apply');
const DEDUP = process.argv.includes('--dedup');
const DEFAULT_COUNTRY_CODE = '250';

function normalizePhone(raw) {
  let digits = String(raw || '').replace(/\D/g, '');
  if (!digits) return '';
  if (digits.startsWith('00')) {
    digits = digits.slice(2);
  } else if (digits.startsWith('0')) {
    digits = DEFAULT_COUNTRY_CODE + digits.slice(1);
  }
  return digits;
}

async function getAccessToken() {
  const p = os.homedir() + '/.config/configstore/firebase-tools.json';
  const j = JSON.parse(fs.readFileSync(p, 'utf8'));
  const body = new URLSearchParams({
    client_id: CLIENT_ID,
    client_secret: CLIENT_SECRET,
    refresh_token: j.tokens.refresh_token,
    grant_type: 'refresh_token',
  });
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });
  const d = await r.json();
  if (!d.access_token) throw new Error('token exchange failed');
  return d.access_token;
}

function val(v) {
  if (v == null) return null;
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return v.integerValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('timestampValue' in v) return v.timestampValue;
  if ('nullValue' in v) return null;
  return null;
}
function flat(fields) {
  const o = {};
  for (const k in fields || {}) o[k] = val(fields[k]);
  return o;
}

async function list(token, path) {
  const docs = [];
  let pageToken = '';
  do {
    const url = `${BASE}/${path}?pageSize=300${
      pageToken ? '&pageToken=' + pageToken : ''
    }`;
    const r = await fetch(url, { headers: { Authorization: 'Bearer ' + token } });
    const d = await r.json();
    if (d.error) throw new Error(path + ': ' + JSON.stringify(d.error));
    (d.documents || []).forEach((doc) =>
      docs.push({ id: doc.name.split('/').pop(), ...flat(doc.fields) }),
    );
    pageToken = d.nextPageToken || '';
  } while (pageToken);
  return docs;
}

async function patch(token, path, fields, mask) {
  const params = mask.map((m) => `updateMask.fieldPaths=${m}`).join('&');
  const url = `${BASE}/${path}?${params}`;
  const r = await fetch(url, {
    method: 'PATCH',
    headers: {
      Authorization: 'Bearer ' + token,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ fields }),
  });
  const d = await r.json();
  if (d.error) throw new Error('patch ' + path + ': ' + JSON.stringify(d.error));
}

(async () => {
  const token = await getAccessToken();
  const shops = await list(token, 'shops');
  const users = await list(token, 'users');
  const userIds = new Set(users.map((u) => u.id));

  console.log(`Mode: ${APPLY ? 'APPLY' : 'DRY RUN'}${DEDUP ? ' +DEDUP' : ''}`);
  console.log(`Shops: ${shops.length}, Users: ${users.length}\n`);

  // 1. Backfill ownerPhoneKey
  let backfilled = 0;
  for (const s of shops) {
    const key = normalizePhone(s.ownerPhone || s.businessPhone || '');
    if (key && s.ownerPhoneKey !== key) {
      s.ownerPhoneKey = key;
      console.log(`backfill ${s.id} "${s.name}" ownerPhoneKey=${key}`);
      if (APPLY) {
        await patch(
          token,
          `shops/${s.id}`,
          { ownerPhoneKey: { stringValue: key } },
          ['ownerPhoneKey'],
        );
      }
      backfilled++;
    }
  }
  console.log(`\nownerPhoneKey backfilled: ${backfilled}\n`);

  // 2. Duplicate shops by ownerPhoneKey
  const byKey = {};
  for (const s of shops) {
    if (!s.ownerPhoneKey) continue;
    (byKey[s.ownerPhoneKey] ||= []).push(s);
  }
  for (const [key, group] of Object.entries(byKey)) {
    if (group.length < 2) continue;
    group.sort((a, b) => {
      const aApproved = a.approvalStatus === 'approved' ? 0 : 1;
      const bApproved = b.approvalStatus === 'approved' ? 0 : 1;
      if (aApproved !== bApproved) return aApproved - bApproved;
      return String(a.createdAt || '').localeCompare(String(b.createdAt || ''));
    });
    const [canonical, ...dupes] = group;
    console.log(
      `DUPLICATE phone ${key}: keep ${canonical.id} "${canonical.name}" ` +
        `(${canonical.code}); extras: ${dupes.map((d) => d.id).join(', ')}`,
    );
    if (DEDUP) {
      for (const d of dupes) {
        console.log(`  tombstone ${d.id} "${d.name}"`);
        if (APPLY) {
          await patch(
            token,
            `shops/${d.id}`,
            {
              deleted: { booleanValue: true },
              deletedReason: { stringValue: `dup of ${canonical.id}` },
            },
            ['deleted', 'deletedReason'],
          );
        }
      }
    }
  }

  // 3. Orphaned member docs
  console.log('\nOrphaned members (uid has no /users profile, not owner):');
  let orphans = 0;
  for (const s of shops) {
    const members = await list(token, `shops/${s.id}/members`);
    for (const m of members) {
      if (m.id === s.ownerUid) continue;
      if (!userIds.has(m.id)) {
        orphans++;
        console.log(
          `  shop ${s.id} "${s.name}" member ${m.id} ` +
            `(${m.displayName || 'no name'})`,
        );
      }
    }
  }
  console.log(`\nOrphaned members: ${orphans} (owners can remove these in Team)`);
  console.log('\nDone.');
})().catch((e) => {
  console.error('ERROR:', e.message);
  process.exit(1);
});
