const fs = require('fs');
const path = require('path');
const https = require('https');

const cfg = JSON.parse(
  fs.readFileSync(
    path.join(process.env.USERPROFILE, '.config', 'configstore', 'firebase-tools.json'),
    'utf8',
  ),
);
const token = cfg.tokens.access_token;
const project = 'alex-pos';
const shopId = 'Y6XpFI3Qp0vqS19tEeWK';

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function req(method, urlPath, body) {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : null;
    const r = https.request(
      {
        hostname: 'firestore.googleapis.com',
        path: urlPath,
        method,
        headers: {
          Authorization: 'Bearer ' + token,
          'Content-Type': 'application/json',
          ...(data ? { 'Content-Length': Buffer.byteLength(data) } : {}),
        },
      },
      (res) => {
        let out = '';
        res.on('data', (c) => (out += c));
        res.on('end', () => {
          try {
            resolve({ status: res.statusCode, json: JSON.parse(out || '{}'), text: out });
          } catch {
            resolve({ status: res.statusCode, text: out });
          }
        });
      },
    );
    r.on('error', reject);
    if (data) r.write(data);
    r.end();
  });
}

function pick(f, k) {
  const v = f?.[k];
  if (!v) return null;
  if (v.stringValue != null) return v.stringValue;
  return null;
}

function encodeValue(val) {
  if (val === null) return { nullValue: null };
  if (typeof val === 'string') return { stringValue: val };
  throw new Error('unsupported ' + typeof val);
}

async function reqRetry(method, urlPath, body, tries = 8) {
  for (let i = 0; i < tries; i++) {
    const res = await req(method, urlPath, body);
    if (res.status !== 429) return res;
    const wait = 5000 * (i + 1);
    console.log(`429 quota — retry in ${wait / 1000}s (${i + 1}/${tries})`);
    await sleep(wait);
  }
  return req(method, urlPath, body);
}

(async () => {
  const membersRes = await reqRetry(
    'GET',
    `/v1/projects/${project}/databases/(default)/documents/shops/${shopId}/members?pageSize=100`,
  );
  if (membersRes.status !== 200) {
    console.error('members list failed', membersRes.status, membersRes.text || membersRes.json);
    process.exit(1);
  }

  const members = (membersRes.json.documents || []).map((doc) => {
    const f = doc.fields || {};
    return {
      uid: doc.name.split('/').pop(),
      displayName: pick(f, 'displayName'),
      phone: pick(f, 'phone'),
      role: pick(f, 'role'),
      approvalStatus: pick(f, 'approvalStatus'),
    };
  });
  console.log('Members:', JSON.stringify(members, null, 2));

  const target =
    members.find(
      (m) =>
        m.approvalStatus === 'pendingOwner' &&
        ((m.displayName || '').toLowerCase() === 'alex' ||
          (m.phone || '').includes('784712870')),
    ) ||
    members.find((m) => m.approvalStatus === 'pendingOwner' && m.role === 'staff');

  if (!target) {
    const already = members.find(
      (m) =>
        ((m.displayName || '').toLowerCase() === 'alex' ||
          (m.phone || '').includes('784712870')) &&
        m.approvalStatus === 'approved',
    );
    if (already) {
      console.log('Already approved:', already);
      process.exit(0);
    }
    console.error('No pendingOwner staff member found to approve');
    process.exit(1);
  }

  console.log('Approving:', target);

  const nowIso = new Date().toISOString();
  const patchBody = {
    fields: {
      approvalStatus: encodeValue('approved'),
      approvedAt: encodeValue(nowIso),
      rejectedAt: encodeValue(null),
      rejectionReason: encodeValue(null),
    },
  };

  const updateMask = [
    'updateMask.fieldPaths=approvalStatus',
    'updateMask.fieldPaths=approvedAt',
    'updateMask.fieldPaths=rejectedAt',
    'updateMask.fieldPaths=rejectionReason',
  ].join('&');

  const patchRes = await reqRetry(
    'PATCH',
    `/v1/projects/${project}/databases/(default)/documents/shops/${shopId}/members/${target.uid}?${updateMask}`,
    patchBody,
  );

  console.log('Patch status:', patchRes.status);
  if (patchRes.status !== 200) {
    console.error(patchRes.text || JSON.stringify(patchRes.json));
    process.exit(1);
  }

  console.log('Done — approved', target.displayName, `(${target.uid})`);
  console.log('Device should unlock after Refresh status.');
})();
