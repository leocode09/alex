# Shipping updates to ALEX (outside the Play Store)

ALEX is distributed as a raw APK, so two OTA layers cooperate to keep users
current without forcing a reinstall every time:

| Layer                | What it ships               | Speed           | When to use                                                  |
| -------------------- | --------------------------- | --------------- | ------------------------------------------------------------ |
| **Shorebird**        | Dart code only              | Instant, silent | Small logic fixes, UI tweaks, copy changes                   |
| **APK self-updater** | Full APK (native + assets)  | One-tap install | New plugins, Android manifest / permissions, asset changes   |

Both are already wired up. The APK self-updater is the main "push a new build
to everyone" path — this document focuses on it.

---

## How the APK self-updater works

1. App launches → 3 seconds later `ApkUpdateWatcher` fetches a small JSON
   manifest over HTTPS.
2. If `manifest.versionCode > installedVersionCode`, a dialog appears with
   release notes and an **Update now** button.
3. The app downloads the new APK into app-scoped storage and launches the
   Android package installer. The user taps **Install**.
4. Users can also trigger a check manually in **Settings → Check for Updates**
   (long-press that tile to configure the manifest URL on-device).

No Play Store involvement. No re-signing of the user's device required beyond
the one-time "Install unknown apps" permission Android shows automatically.

---

## Manifest format

Host any JSON file shaped like this over HTTPS:

```json
{
  "versionCode": 2,
  "versionName": "1.0.1",
  "apkUrl": "https://github.com/<you>/<repo>/releases/download/v1.0.1/alex-1.0.1.apk",
  "releaseNotes": "- Faster startup\n- Printer auto-reconnect\n- New discount rules",
  "mandatory": false,
  "sha256": "optional-hex-digest-of-the-apk",
  "minSupportedVersionCode": 1
}
```

Required: `versionCode`, `versionName`, `apkUrl`. Everything else is optional.

- `versionCode` is compared against the installed APK's Android build number
  (the `+N` suffix in `pubspec.yaml` → `version: 1.0.0+N`). **Always bump it
  for every release, even for hotfixes.**
- `mandatory: true` hides "Later" / "Skip this version" and forces the user to
  update before they can dismiss the dialog.

---

## Recommended hosting: GitHub Releases

Free, public (or private with a PAT), CDN-backed, and both files get versioned
commit-style for you.

### One-time setup

1. Push this repo to GitHub.
2. In the app (or in code), set the manifest URL to:

   ```
   https://github.com/<user>/<repo>/releases/latest/download/update.json
   ```

   Two ways to do it:

   - **In code** (for everyone who installs a fresh APK): edit
     `lib/services/apk_updater_service.dart` →
     `ApkUpdaterService.defaultManifestUrl`.
   - **Per-device**: Settings → long-press **Check for Updates** → paste the
     URL.

### Cutting a release

1. Bump `pubspec.yaml`:

   ```yaml
   version: 1.0.1+2   # name+code (code MUST increase every release)
   ```

2. Build the APK:

   ```powershell
   flutter build apk --release
   ```

   Output is `build\app\outputs\flutter-apk\app-release.apk`. Rename it to
   something versioned, e.g. `alex-1.0.1.apk`.

3. Write `update.json` next to the APK:

   ```json
   {
     "versionCode": 2,
     "versionName": "1.0.1",
     "apkUrl": "https://github.com/<user>/<repo>/releases/download/v1.0.1/alex-1.0.1.apk",
     "releaseNotes": "- Faster startup\n- Printer auto-reconnect"
   }
   ```

4. Create the GitHub Release:

   ```powershell
   gh release create v1.0.1 alex-1.0.1.apk update.json `
     --title "ALEX 1.0.1" `
     --notes "Faster startup and printer auto-reconnect."
   ```

   `/releases/latest/download/update.json` now resolves to this file. Existing
   installs will see the update on next launch.

### Hotfix shortcut

Same steps, smaller notes. Bump the `+N` build number even if `versionName`
stays the same — the app compares `versionCode`, not names:

```yaml
version: 1.0.1+3   # same name, bumped code
```

---

## Alternatives to GitHub Releases

- **Firebase Storage** — you already use Firebase. Upload `alex-1.0.1.apk` and
  `update.json` to a public bucket and use the download URL as the manifest
  URL. Remember to make both objects publicly readable (or use signed URLs and
  regenerate them per release).
- **Any static host** — S3, Cloudflare R2, your own VPS, Netlify Drop, etc.
  Anywhere that serves `update.json` + the APK over HTTPS works.

---

## Shorebird (already set up for Dart-only patches)

`shorebird.yaml` + `shorebird_code_push` are already wired up in `main.dart`.
To actually use it you need a Shorebird account and to replace the placeholder
`app_id`:

```powershell
shorebird login
shorebird init --force          # writes a real app_id into shorebird.yaml
shorebird release android       # ship your first "parent" release
# later, for Dart-only fixes on top of that parent release:
shorebird patch android
```

Shorebird patches are pulled automatically in `_maybeDownloadShorebirdPatch`
at startup and applied on the next launch — no user interaction. Use it for
quick iterations between full APK drops.

Anything Shorebird cannot push (new native plugin, `AndroidManifest.xml`
change, new asset, Flutter version bump) requires a full APK release, which is
exactly what the self-updater above handles.

---

## Testing locally

1. Build and install APK with `version: 1.0.0+1`.
2. Bump to `1.0.0+2`, rebuild, upload both `app-release.apk` and an
   `update.json` pointing to it somewhere reachable from the device (a GitHub
   pre-release, a quick `python -m http.server` on your laptop, etc.).
3. Open the app → in 3 seconds you should see the update dialog.
4. Tap **Update now**. First time only, Android asks you to allow "Install
   unknown apps" for ALEX. After granting, the installer screen appears.
5. Tap **Install** → ALEX restarts on the new version.

If nothing happens, use **Settings → Check for Updates** to force a check and
see error messages.

---

## Permissions note

`android/app/src/main/AndroidManifest.xml` declares
`REQUEST_INSTALL_PACKAGES`. Android shows the "Install unknown apps" prompt
the first time the installer is launched; the service detects a denied state
and returns a friendly message instead of crashing.

The `open_filex` plugin provides the required `FileProvider` so the downloaded
APK can be handed off to the system installer without any extra XML from you.
