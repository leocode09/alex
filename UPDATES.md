# Shipping updates to ALEX (outside the Play Store)

ALEX is distributed as a raw APK. The in-app updater silently checks a published
manifest on launch, downloads newer builds in the background, verifies SHA-256
integrity, and shows a green **Install** banner when ready.

---

## How it works

1. App launches → `UpdateService.start()` fetches `manifest.json` over HTTPS.
2. If `manifest.version` is newer than the installed build, the APK downloads
   silently to app-scoped storage.
3. After hash verification, a green banner appears: **ALEX {version} is ready.**
4. The user taps **Install** → Android package installer opens.
5. Users can also trigger a check manually in **Settings → Check for Updates**
   (long-press that tile to configure the manifest URL on-device).

No Play Store involvement. No re-signing of the user's device required beyond
the one-time "Install unknown apps" permission Android shows automatically.

---

## Manifest format

Host a JSON file shaped like this over HTTPS (MarkEase / DimeSchool protocol):

```json
{
  "id": "abc215d6-d868-e20c-dad3-fad6e3df606a",
  "createdAt": "2026-07-11T00:00:00.000Z",
  "version": "1.0.5+6",
  "runtimeVersion": "1.0.5+6",
  "platforms": {
    "android": {
      "launchAsset": {
        "hash": "3MTQHsKKBK7RnBb6ATl53eG7v4b29JkoemEnebD4_bI",
        "key": "209e47c0a53beec43565c37e47082989",
        "contentType": "application/vnd.android.package-archive",
        "fileExtension": ".apk",
        "url": "https://github.com/leocode09/alex/releases/download/apk-v1.0.5-6/alex-pos.apk"
      }
    }
  }
}
```

- `version` / `runtimeVersion` — semver string compared against the installed
  build (`1.0.4+5` from `pubspec.yaml`). **Always bump the `+N` build number
  for every release, even for hotfixes.**
- `hash` — base64url SHA-256 of the APK bytes (verified before install).
- `key` — md5 hex content address (used for on-disk filename).
- `url` — pinned to the release tag (never `latest`) so published assets are
  immutable.

Generate manifests with `scripts/make_update_manifest.mjs`.

---

## Recommended hosting: GitHub Releases

Free, public, CDN-backed, and both files get versioned for you.

### One-time setup

1. Push this repo to GitHub.
2. In the app (or in code), set the manifest URL to:

   ```
   https://github.com/leocode09/alex/releases/latest/download/manifest.json
   ```

   Two ways to do it:

   - **In code** (for everyone who installs a fresh APK): edit
     `lib/services/update_service.dart` → `UpdateService.defaultManifestUrl`.
   - **Per-device**: Settings → long-press **Check for Updates** → paste the
     URL.

### Cutting a release manually

1. Bump `pubspec.yaml`:

   ```yaml
   version: 1.0.5+6   # name+code (code MUST increase every release)
   ```

2. Build the APK:

   ```powershell
   flutter build apk --release --build-name 1.0.5 --build-number 6
   ```

   Output is `build\app\outputs\flutter-apk\app-release.apk`.

3. Generate `manifest.json`:

   ```powershell
   node scripts/make_update_manifest.mjs `
     --version 1.0.5+6 `
     --repo leocode09/alex `
     --tag apk-v1.0.5-6 `
     --android build/app/outputs/flutter-apk/app-release.apk `
     --out dist/manifest.json
   ```

4. Create the GitHub Release:

   ```powershell
   gh release create apk-v1.0.5-6 `
     build/app/outputs/flutter-apk/app-release.apk `
     dist/manifest.json `
     --latest `
     --title "ALEX 1.0.5+6"
   ```

   `/releases/latest/download/manifest.json` now resolves to this file. Existing
   installs will see the update on next launch.

### GitHub Action shortcut

Use **Actions → Build Latest APK → Run workflow** to build and publish without
editing `pubspec.yaml` manually. The workflow reads the newest published
`manifest.json`, increments the build number, builds with `--build-number`, and
uploads:

- `alex-pos.apk` — stable latest APK asset for QR/download redirects.
- `alex-<versionName>-<versionCode>.apk` — versioned archive copy.
- `manifest.json` — manifest consumed by the in-app updater.

### Hotfix shortcut

Same steps, smaller notes. Bump the `+N` build number even if `versionName`
stays the same:

```yaml
version: 1.0.5+7   # same name, bumped code
```

---

## Alternatives to GitHub Releases

- **Firebase Storage** — upload `alex-pos.apk` and `manifest.json` to a public
  bucket and point the manifest URL at the JSON file.
- **Any static host** — S3, Cloudflare R2, your own VPS, etc. Anywhere that
  serves `manifest.json` + the APK over HTTPS works.

---

## Testing locally

1. Build and install APK with `version: 1.0.0+1`.
2. Bump to `1.0.0+2`, rebuild, generate `manifest.json` and host both files
   somewhere reachable from the device (a GitHub pre-release, a quick
   `python -m http.server` on your laptop, etc.).
3. Open the app → after a moment you should see the green Install banner.
4. Tap **Install**. First time only, Android asks you to allow "Install unknown
   apps" for ALEX. After granting, the installer screen appears.
5. Tap **Install** → ALEX restarts on the new version.

If nothing happens, use **Settings → Check for Updates** to force a check and
see error messages.

---

## Permissions note

`android/app/src/main/AndroidManifest.xml` declares
`REQUEST_INSTALL_PACKAGES`. Android shows the "Install unknown apps" prompt
the first time the installer is launched.

The `open_filex` plugin provides the required `FileProvider` so the downloaded
APK can be handed off to the system installer without any extra XML from you.
