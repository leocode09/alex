# ALEX

[![Build Android APK](https://github.com/leocode09/alex/actions/workflows/build-apk.yml/badge.svg)](https://github.com/leocode09/alex/actions/workflows/build-apk.yml)
[![Build Latest APK](https://github.com/leocode09/alex/actions/workflows/build-latest-apk.yml/badge.svg)](https://github.com/leocode09/alex/actions/workflows/build-latest-apk.yml)

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

This project uses GitHub Actions to build Android APKs and publish OTA manifests.

### Standard APK build

- **Triggers**: Pushes and pull requests to main/master/develop, plus manual runs
- **Artifacts**: Download the `release-apk` artifact from the workflow run summary

### OTA release (manual)

Workflow: [build-latest-apk.yml](.github/workflows/build-latest-apk.yml)

- **Manual run**: GitHub → Actions → **Build Latest APK** → Run workflow
- **Publishes**: `alex-pos.apk`, versioned APK copy, and `manifest.json` for the in-app updater
- See [UPDATES.md](UPDATES.md) for the full release playbook

To view build status and download APKs:

1. Open the [Actions tab](https://github.com/leocode09/alex/actions)
2. Select the workflow run
3. Download the listed artifacts from the run summary
