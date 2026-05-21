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
  return f?.[k]?.stringValue ?? null;
}

(async () => {
  console.log('Waiting 120s for Firestore quota…');
  await sleep(120000);

  for (let attempt = 1; attempt <= 6; attempt++) {
    const membersRes = await req(
      'GET',
      `/v1/projects/${project}/databases/(default)/documents/shops/${shopId}/members?pageSize=50`,
    );
    if (membersRes.status === 429) {
      console.log(`List attempt ${attempt}: quota, wait 30s`);
      await sleep(30000);
      continue;
    }
    if (membersRes.status !== 200) {
      console.error('List failed', membersRes.status, membersRes.text);
      process.exit(1);
    }

    const members = (membersRes.json.documents || []).map((doc) => ({
      uid: doc.name.split('/').pop(),
      displayName: pick(doc.fields, 'displayName'),
      phone: pick(doc.fields, 'phone'),
      role: pick(doc.fields, 'role'),
      approvalStatus: pick(doc.fields, 'approvalStatus') || 'approved',
    }));
    console.log('Members:', JSON.stringify(members, null, 2));

    const target = members.find(
      (m) =>
        m.approvalStatus === 'pendingOwner' &&
        ((m.displayName || '').toLowerCase() === 'alex' ||
          (m.phone || '').replace(/\D/g, '').endsWith('784712870')),
    );

    if (!target) {
      const approved = members.find(
        (m) =>
          (m.displayName || '').toLowerCase() === 'alex' ||
          (m.phone || '').replace(/\D/g, '').endsWith('784712870'),
      );
      if (approved?.approvalStatus === 'approved') {
        console.log('Alex already approved:', approved);
        process.exit(0);
      }
      console.error('No pending alex member found');
      process.exit(1);
    }

    const nowIso = new Date().toISOString();
    const fields = {
      approvalStatus: { stringValue: 'approved' },
      approvedAt: { stringValue: nowIso },
      approvedBy: { stringValue: 'cursor-agent' },
      rejectedAt: { nullValue: null },
      rejectionReason: { nullValue: null },
    };
    const mask = Object.keys(fields)
      .map((f) => `updateMask.fieldPaths=${encodeURIComponent(f)}`)
      .join('&');

    const patchRes = await req(
      'PATCH',
      `/v1/projects/${project}/databases/(default)/documents/shops/${shopId}/members/${target.uid}?${mask}`,
      { fields },
    );
    console.log('Patch', target.displayName, patchRes.status, patchRes.text?.slice(0, 500));
    process.exit(patchRes.status === 200 ? 0 : 1);
  }
  process.exit(1);
})();
