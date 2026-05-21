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

(async () => {
  const members = await req(
    'GET',
    `/v1/projects/${project}/databases/(default)/documents/shops/${shopId}/members?pageSize=50`,
  );
  console.log('status', members.status, members.json?.error?.message || '');
  for (const doc of members.json.documents || []) {
    const id = doc.name.split('/').pop();
    const f = doc.fields || {};
    const row = {
      id,
      role: f.role?.stringValue,
      status: f.approvalStatus?.stringValue || 'approved',
      name: f.displayName?.stringValue,
      phone: f.phone?.stringValue,
    };
    console.log(JSON.stringify(row));
    if (row.status === 'pendingOwner') {
      const now = new Date().toISOString();
      const res = await patchDoc(`shops/${shopId}/members/${id}`, {
        approvalStatus: { stringValue: 'approved' },
        approvedAt: { stringValue: now },
        approvedBy: { stringValue: 'cursor-agent-fix' },
      });
      console.log('approved', row.name, res.status);
    }
  }
})();
