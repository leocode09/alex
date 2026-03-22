# ALEX

[![Build Android APK](https://github.com/leocode09/alex/actions/workflows/build-apk.yml/badge.svg)](https://github.com/leocode09/alex/actions/workflows/build-apk.yml)
[![shorebird ci](https://api.shorebird.dev/api/v1/github/leocode09/alex/badge.svg)](https://console.shorebird.dev/ci)
[![Shorebird Release Android](https://github.com/leocode09/alex/actions/workflows/shorebird-release.yml/badge.svg)](https://github.com/leocode09/alex/actions/workflows/shorebird-release.yml)

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## CI/CD

This project uses GitHub Actions to build Android APKs and (optionally) publish **Shorebird** releases.

### Standard APK build

- **Triggers**: Pushes and pull requests to main/master/develop, plus manual runs
- **Artifacts**: Download the `release-apk` artifact from the workflow run summary

### Shorebird release (automatic on version tags)

Workflow: [shorebird-release.yml](.github/workflows/shorebird-release.yml)

- **Manual run**: GitHub → Actions → **Shorebird Release Android** → Run workflow
- **Automatic run**: Push a tag matching `v*` (e.g. `v1.0.1`) after updating `version:` in `pubspec.yaml` for that release. If the Shorebird release version already exists, the job will fail until you bump the version.
- **Secret**: Add `SHOREBIRD_TOKEN` under repository **Settings → Secrets and variables → Actions**. Create the token locally with `shorebird login:ci` ([docs](https://docs.shorebird.dev/code-push/ci/github/)).
- **Artifacts**: Each successful run uploads APK and AAB files from the Shorebird build.

To view build status and download APKs:

1. Open the [Actions tab](https://github.com/leocode09/alex/actions)
2. Select the workflow run
3. Download the listed artifacts from the run summary
