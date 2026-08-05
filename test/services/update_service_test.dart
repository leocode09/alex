import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:alex/services/update_service.dart';

void main() {
  group('UpdateService.compareVersions', () {
    test('orders dotted numeric versions', () {
      expect(UpdateService.compareVersions('1.0.43', '1.0.0'), greaterThan(0));
      expect(UpdateService.compareVersions('1.0.9', '1.0.10'), lessThan(0));
      expect(UpdateService.compareVersions('2.0.0', '1.9.9'), greaterThan(0));
      expect(UpdateService.compareVersions('1.0.0', '1.0.0'), 0);
    });

    test('treats +build as the least significant component', () {
      expect(UpdateService.compareVersions('1.0.0+2', '1.0.0+1'), greaterThan(0));
      expect(UpdateService.compareVersions('1.0.1', '1.0.0+99'), greaterThan(0));
      expect(UpdateService.compareVersions('1.0.0', '1.0.0+1'), lessThan(0));
      expect(UpdateService.compareVersions('1.0.0+1', '1.0.0+1'), 0);
    });

    test('tolerates short and four-part versions', () {
      expect(UpdateService.compareVersions('1.0', '1.0.0'), 0);
      expect(UpdateService.compareVersions('1.0.43.43', '1.0.43'), greaterThan(0));
      expect(UpdateService.compareVersions('garbage', '1.0.0'), lessThan(0));
    });
  });

  group('UpdateManifest.parse', () {
    final sample = jsonEncode({
      'id': 'abc215d6-d868-e20c-dad3-fad6e3df606a',
      'createdAt': '2026-07-06T00:00:00.000Z',
      'version': '1.0.43',
      'runtimeVersion': '1.0.43',
      'platforms': {
        'android': {
          'launchAsset': {
            'hash': '3MTQHsKKBK7RnBb6ATl53eG7v4b29JkoemEnebD4_bI',
            'key': '209e47c0a53beec43565c37e47082989',
            'contentType': 'application/vnd.android.package-archive',
            'fileExtension': '.apk',
            'url':
                'https://github.com/leocode09/alex/releases/download/apk-v1.0.43-43/alex-pos.apk',
          },
        },
      },
    });

    test('extracts the android platform entry', () {
      final android = UpdateManifest.parse(sample, platform: 'android');
      expect(android, isNotNull);
      expect(android!.version, '1.0.43');
      expect(android.id, 'abc215d6-d868-e20c-dad3-fad6e3df606a');
      expect(android.asset.key, '209e47c0a53beec43565c37e47082989');
      expect(android.asset.url, endsWith('alex-pos.apk'));
    });

    test('returns null for a missing platform', () {
      expect(UpdateManifest.parse(sample, platform: 'windows'), isNull);
    });

    test('returns null on malformed input', () {
      expect(UpdateManifest.parse('not json', platform: 'android'), isNull);
      expect(UpdateManifest.parse('{}', platform: 'android'), isNull);
      expect(
        UpdateManifest.parse(
          jsonEncode({
            'version': '1.0.43',
            'platforms': {
              'android': {'launchAsset': {'url': '', 'hash': ''}},
            },
          }),
          platform: 'android',
        ),
        isNull,
      );
    });

    test('falls back to runtimeVersion when version is absent', () {
      final manifest = UpdateManifest.parse(
        jsonEncode({
          'runtimeVersion': '1.0.44',
          'platforms': {
            'android': {
              'launchAsset': {'url': 'https://x/y.apk', 'hash': 'h', 'key': 'k'},
            },
          },
        }),
        platform: 'android',
      );
      expect(manifest!.version, '1.0.44');
    });
  });
}
