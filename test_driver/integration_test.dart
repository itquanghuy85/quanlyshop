import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
      onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
        final file = File('build/screenshots/$name.png')
          ..createSync(recursive: true);
        file.writeAsBytesSync(bytes);
        stdout.writeln('SCREENSHOT_SAVED build/screenshots/$name.png (${bytes.length} bytes)');
        return true;
      },
    );