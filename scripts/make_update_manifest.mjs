#!/usr/bin/env node
// Builds the OTA update manifest published alongside each release.
// Hashing scheme matches MarkEase / DimeSchool: per asset a base64url SHA-256
// `hash`, an md5-hex `key` (content address), and a deterministic manifest
// `id` (SHA-256 formatted as a UUID).
//
// The app's UpdateService fetches releases/latest/download/manifest.json,
// compares `version` against its own, downloads the Android launchAsset from
// the tag-pinned URL, and verifies `hash` before installing.
//
// Run by .github/workflows/build-latest-apk.yml; also works locally:
//   node scripts/make_update_manifest.mjs \
//     --version 1.0.5+6 --repo leocode09/alex --tag apk-v1.0.5-6 \
//     --android dist/alex-pos.apk \
//     --out dist/manifest.json

import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { basename, extname } from "node:path";

const args = {};
for (let i = 2; i < process.argv.length; i += 2) {
  args[process.argv[i].replace(/^--/, "")] = process.argv[i + 1];
}
for (const key of ["version", "repo", "tag", "out"]) {
  if (!args[key]) throw new Error(`--${key} is required`);
}

const base64url = (buf) =>
  createHash("sha256").update(buf).digest("base64")
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const md5hex = (buf) => createHash("md5").update(buf).digest("hex");

const sha256ToUUID = (buf) => {
  const h = createHash("sha256").update(buf).digest("hex");
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20, 32)}`;
};

const CONTENT_TYPES = {
  ".apk": "application/vnd.android.package-archive",
};

const asset = (path) => {
  const bytes = readFileSync(path);
  const name = basename(path);
  const ext = extname(name);
  return {
    hash: base64url(bytes),
    key: md5hex(bytes),
    contentType: CONTENT_TYPES[ext] ?? "application/octet-stream",
    fileExtension: ext,
    url: `https://github.com/${args.repo}/releases/download/${args.tag}/${name}`,
  };
};

const platforms = {};
if (args.android) platforms.android = { launchAsset: asset(args.android) };
if (Object.keys(platforms).length === 0) {
  throw new Error("pass --android with the APK path");
}

const body = { version: args.version, runtimeVersion: args.version, platforms };
const manifest = {
  id: sha256ToUUID(Buffer.from(JSON.stringify(body))),
  createdAt: new Date().toISOString(),
  ...body,
};
writeFileSync(args.out, JSON.stringify(manifest, null, 2));
console.log(`wrote ${args.out}`);
console.log(JSON.stringify(
  { id: manifest.id, version: manifest.version, platforms: Object.keys(platforms) },
  null,
  2,
));
