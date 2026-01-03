# pos_system

[![Build Android APK](https://github.com/YOUR_USERNAME/YOUR_REPO_NAME/actions/workflows/build-apk.yml/badge.svg)](https://github.com/YOUR_USERNAME/YOUR_REPO_NAME/actions/workflows/build-apk.yml)

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

This project uses GitHub Actions to automatically build Android APKs. The workflow:

- **Triggers**: Runs on pushes and pull requests to main/master/develop branches, and can be manually triggered
- **Build Status**: Track build status using the badge above (update YOUR_USERNAME and YOUR_REPO_NAME)
- **Artifacts**: Built APKs are available as downloadable artifacts in the Actions tab for 30 days
- **Status Tracking**: Build status is automatically tracked by GitHub and visible in:
  - Pull request checks
  - Commit status indicators
  - Actions tab with detailed logs and summaries

To view build status and download APKs:
1. Go to the **Actions** tab in your GitHub repository
2. Click on the latest workflow run
3. Download the `release-apk` artifact from the workflow summary
