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
      limit: 10,
    },
  });
}

function listMembers(shopId) {
  return req(
    'GET',
    `/v1/projects/${project}/databases/(default)/documents/shops/${shopId}/members?pageSize=50`,
  );
}

function pick(f, k) {
  const v = f[k];
  if (!v) return null;
  if (v.stringValue != null) return v.stringValue;
  if (v.integerValue != null) return v.integerValue;
  if (v.nullValue != null) return null;
  return v;
}

(async () => {
  for (const code of ['KQ9TGR', 'DFDXXY', 'kq9tgr']) {
    const q = await runQuery('shops', 'code', code);
    console.log('query status', code, q.status);
    const docs = (q.json || [])
      .filter((x) => x.document)
      .map((x) => {
        const f = x.document.fields || {};
        const id = x.document.name.split('/').pop();
        return {
          id,
          name: pick(f, 'name'),
          code: pick(f, 'code'),
          approvalStatus: pick(f, 'approvalStatus'),
          ownerUid: pick(f, 'ownerUid'),
          ownerName: pick(f, 'ownerName'),
        };
      });
    console.log('SHOP', code, JSON.stringify(docs, null, 2));
  }

  const nameQ = await runQuery('shops', 'name', 'ALEX SHOP');
  console.log('name query status', nameQ.status);
  const nameDocs = (nameQ.json || [])
    .filter((x) => x.document)
    .map((x) => {
      const f = x.document.fields || {};
      const id = x.document.name.split('/').pop();
      return {
        id,
        code: pick(f, 'code'),
        approvalStatus: pick(f, 'approvalStatus'),
      };
    });
  console.log('SHOPS named ALEX SHOP', JSON.stringify(nameDocs, null, 2));

  const members = await listMembers('Y6XpFI3Qp0vqS19tEeWK');
  console.log('members status', members.status, members.json?.error?.message || '');
  const docs = (members.json.documents || []).map((d) => {
    const f = d.fields || {};
    const id = d.name.split('/').pop();
    return {
      id,
      role: pick(f, 'role'),
      approvalStatus: pick(f, 'approvalStatus'),
      displayName: pick(f, 'displayName'),
      phone: pick(f, 'phone'),
    };
  });
  console.log('MEMBERS DFDXXY', JSON.stringify(docs, null, 2));
})();
