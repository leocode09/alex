import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ui codebase does not use gradients or box shadows', () {
    final uiDir = Directory('lib/ui');
    expect(uiDir.existsSync(), isTrue);

    final forbidden = <String, List<String>>{};
    final pattern =
        RegExp(r'LinearGradient|RadialGradient|SweepGradient|BoxShadow');

    for (final file in uiDir.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) {
        continue;
      }
      final text = file.readAsStringSync();
      final matches = pattern
          .allMatches(text)
          .map((match) => match.group(0)!)
          .toList(growable: false);
      if (matches.isNotEmpty) {
        forbidden[file.path.replaceAll('\\', '/')] = matches;
      }
    }

    expect(
      forbidden,
      isEmpty,
      reason: 'Forbidden visual styles found: $forbidden',
    );
  });
}
