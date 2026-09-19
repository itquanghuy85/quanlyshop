import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:quanlyshop/services/local_image_store.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.docs);
  final String docs;
  @override
  Future<String?> getApplicationDocumentsPath() async => docs;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('lis_');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('persist copies the picked file into documents/local_images', () async {
    final src = File('${tmp.path}/picked.jpg')..writeAsBytesSync([1, 2, 3]);
    final path = await LocalImageStore.persist(XFile(src.path), prefix: 'repair');
    expect(LocalImageStore.isStorePath(path), isTrue);
    expect(path, contains('repair_'));
    expect(File(path).readAsBytesSync(), [1, 2, 3]);
    // Original (cache) file untouched — the caller may still upload it.
    expect(src.existsSync(), isTrue);
  });

  test('remove only touches files inside the store', () async {
    final src = File('${tmp.path}/picked.jpg')..writeAsBytesSync([9]);
    final stored = await LocalImageStore.persist(XFile(src.path));
    await LocalImageStore.remove(src.path);
    expect(src.existsSync(), isTrue, reason: 'không phải file trong store');
    await LocalImageStore.remove(stored);
    expect(File(stored).existsSync(), isFalse);
  });

  test('persist falls back to the original path when the copy fails', () async {
    final path = await LocalImageStore.persist(XFile('${tmp.path}/missing.jpg'));
    expect(path, '${tmp.path}/missing.jpg');
  });
}
