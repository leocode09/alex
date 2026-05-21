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
            resolve({ status: res.statusCode, json: JSON.parse(out || '{}') });
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

function runQuery(collectionId, field, value) {
  return req('POST', `/v1/projects/${project}/databases/(default)/documents:runQuery`, {
    structuredQuery: {
      from: [{ collectionId }],
      where: {
        fieldFilter: {
          field: { fieldPath: field },
          op: 'EQUAL',
          value: { stringValue: value },
        },
      },
      limit: 20,
    },
  });
}

function patchDoc(docPath, fields) {
  const fieldPaths = Object.keys(fields);
  return req(
    'PATCH',
    `/v1/projects/${project}/databases/(default)/documents/${docPath}?${fieldPaths
      .map((f) => `updateMask.fieldPaths=${encodeURIComponent(f)}`)
      .join('&')}`,
    { fields },
  );
}

function str(v) {
  return { stringValue: v };
}

function del() {
  return { nullValue: null };
}

function pickDocId(result) {
  return (result.json || [])
    .filter((x) => x.document)
    .map((x) => ({
      id: x.document.name.split('/').pop(),
      name: x.document.fields?.name?.stringValue,
      code: x.document.fields?.code?.stringValue,
      status: x.document.fields?.approvalStatus?.stringValue,
    }));
}

(async () => {
  console.log('Approving pending businesses…');
  await sleep(3000);
  const pendingShops = await runQuery('shops', 'approvalStatus', 'pendingSystemAdmin');
  const shops = pickDocId(pendingShops);
  console.log('Pending shops:', shops);
  for (const shop of shops) {
    const now = new Date().toISOString();
    const res = await patchDoc(`shops/${shop.id}`, {
      approvalStatus: str('approved'),
      approvedAt: str(now),
      approvedBy: str('cursor-agent-fix'),
      rejectedAt: del(),
      rejectionReason: del(),
    });
    console.log('Approved shop', shop.code || shop.id, res.status);
    await sleep(1500);
  }

  for (const code of ['KQ9TGR', 'DFDXXY']) {
    await sleep(2000);
    const q = await runQuery('shops', 'code', code);
    console.log('Shop', code, pickDocId(q));
  }

  console.log('Approving pending staff on DFDXXY shop…');
  await sleep(3000);
  const shopQ = await runQuery('shops', 'code', 'DFDXXY');
  const dfd = pickDocId(shopQ)[0];
  if (!dfd) {
    console.log('DFDXXY shop not found');
    return;
  }

  const members = await req(
    'GET',
    `/v1/projects/${project}/databases/(default)/documents/shops/${dfd.id}/members?pageSize=50`,
  );
  console.log('Members list status', members.status);
  for (const doc of members.json.documents || []) {
    const id = doc.name.split('/').pop();
    const f = doc.fields || {};
    const status = f.approvalStatus?.stringValue || 'approved';
    const name = f.displayName?.stringValue || id;
    if (status !== 'pendingOwner') continue;
    const now = new Date().toISOString();
    const res = await patchDoc(`shops/${dfd.id}/members/${id}`, {
      approvalStatus: str('approved'),
      approvedAt: str(now),
      approvedBy: str('cursor-agent-fix'),
      rejectedAt: del(),
      rejectionReason: del(),
    });
    console.log('Approved member', name, res.status, res.json?.error?.message || '');
    await sleep(1500);
  }
})();
