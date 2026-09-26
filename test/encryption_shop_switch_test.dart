import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quanlyshop/services/encryption_service.dart';

/// Field encryption is keyed per shop. init() used to return early once
/// ANY shop was initialised, so switching shop kept the old key: data of the
/// new shop failed to decrypt and new writes were encrypted with the wrong
/// shop's key (found auditing super admin "Vào shop", 2026-09-26).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    EncryptionService.reset();
  });

  test('switching shop re-keys: each shop decrypts only its own data', () async {
    await EncryptionService.init('shopA');
    final a = EncryptionService.encrypt('0901234567');
    expect(a, isNot('0901234567'));

    await EncryptionService.init('shopB');
    final b = EncryptionService.encrypt('0901234567');
    expect(b, isNot(a), reason: 'shopB must use its own key');
    expect(EncryptionService.decrypt(b), '0901234567');
    // shopA ciphertext is not readable with shopB's key (returned as-is).
    expect(EncryptionService.decrypt(a), a);

    await EncryptionService.init('shopA');
    expect(EncryptionService.decrypt(a), '0901234567');
  });

  test('re-init for the same shop is a no-op (same ciphertext)', () async {
    await EncryptionService.init('shopA');
    final first = EncryptionService.encrypt('x');
    await EncryptionService.init('shopA');
    expect(EncryptionService.encrypt('x'), first);
  });
}
