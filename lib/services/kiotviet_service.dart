import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/db_helper.dart';
import '../models/customer_model.dart';
import '../models/product_model.dart';
import 'user_service.dart';

typedef KiotVietLogHandler = void Function(
  String event, {
  Object? error,
  StackTrace? stackTrace,
  Map<String, Object?> extras,
});

class KiotVietCredentials {
  final String retailer;
  final String clientId;
  final String clientSecret;

  const KiotVietCredentials({
    required this.retailer,
    required this.clientId,
    required this.clientSecret,
  });
}

class KiotVietSyncResult {
  final int added;
  final int updated;
  final int failed;
  final List<String> errors;

  const KiotVietSyncResult({
    this.added = 0,
    this.updated = 0,
    this.failed = 0,
    this.errors = const [],
  });

  KiotVietSyncResult operator +(KiotVietSyncResult other) {
    return KiotVietSyncResult(
      added: added + other.added,
      updated: updated + other.updated,
      failed: failed + other.failed,
      errors: [...errors, ...other.errors],
    );
  }
}

class KiotVietConnectionSnapshot {
  final String retailerCode;
  final bool hasSecureConfiguration;
  final bool hasUserCredentials;
  final String savedClientId;
  final bool hasCachedToken;
  final int? tokenExpiresAt;
  final int? lastConnectedAt;
  final String? lastError;

  const KiotVietConnectionSnapshot({
    required this.retailerCode,
    required this.hasSecureConfiguration,
    this.hasUserCredentials = false,
    this.savedClientId = '',
    required this.hasCachedToken,
    this.tokenExpiresAt,
    this.lastConnectedAt,
    this.lastError,
  });

  bool get hasSavedRetailer => retailerCode.trim().isNotEmpty;
}

class KiotVietService {
  static const String _tokenUrl = 'https://id.kiotviet.vn/connect/token';
  static const String _apiBase = 'https://public.kiotapi.com';
  static const Duration _requestTimeout = Duration(seconds: 20);
  static const String _kiotvietDomainSuffix = '.kiotviet.vn';

  static const String _prefRetailer = 'kv_retailer';
  static const String _prefAccessToken = 'kv_access_token';
  static const String _prefTokenExpiresAt = 'kv_token_expires_at';
  static const String _prefLastConnectedAt = 'kv_last_connected_at';
  static const String _prefLastError = 'kv_last_error';
  static const String _prefClientId = 'kv_client_id';
  static const String _prefClientSecret = 'kv_client_secret';

  static const String _configuredClientId = String.fromEnvironment(
    'KIOTVIET_CLIENT_ID',
    defaultValue: '',
  );
  static const String _configuredClientSecret = String.fromEnvironment(
    'KIOTVIET_CLIENT_SECRET',
    defaultValue: '',
  );

  // Runtime credentials — populated from SharedPreferences at loadConnectionSnapshot
  static String _runtimeClientId = '';
  static String _runtimeClientSecret = '';

  static bool get hasSecureConfiguration =>
      (_configuredClientId.trim().isNotEmpty && _configuredClientSecret.trim().isNotEmpty) ||
      (_runtimeClientId.trim().isNotEmpty && _runtimeClientSecret.trim().isNotEmpty);

  static String normalizeRetailerCode(String input) {
    var normalized = input.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw const FormatException('Vui lòng nhập mã cửa hàng KiotViet.');
    }

    normalized = normalized.replaceFirst(RegExp(r'^https?://'), '');
    normalized = normalized.replaceFirst(RegExp(r'^www\.'), '');
    normalized = normalized.split('/').first;
    normalized = normalized.split('?').first;
    normalized = normalized.split('#').first;

    if (normalized.endsWith(_kiotvietDomainSuffix)) {
      normalized = normalized.substring(
        0,
        normalized.length - _kiotvietDomainSuffix.length,
      );
    }

    normalized = normalized.trim();
    if (normalized.isEmpty) {
      throw const FormatException('Không nhận diện được mã cửa hàng KiotViet.');
    }

    if (normalized.contains('.')) {
      throw const FormatException(
        'Chỉ hỗ trợ mã cửa hàng hoặc URL dạng ten-cua-hang.kiotviet.vn.',
      );
    }

    final validPattern = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$');
    if (!validPattern.hasMatch(normalized)) {
      throw const FormatException(
        'Mã cửa hàng KiotViet không hợp lệ. Chỉ dùng chữ cái, số hoặc dấu gạch ngang.',
      );
    }

    return normalized;
  }

  static Future<void> saveCredentials(KiotVietCredentials creds) async {
    await saveRetailerCode(creds.retailer);
  }

  static Future<KiotVietCredentials?> loadCredentials() async {
    final snapshot = await loadConnectionSnapshot();
    if (!snapshot.hasSavedRetailer || !snapshot.hasSecureConfiguration) {
      return null;
    }
    return _buildInternalCredentials(snapshot.retailerCode);
  }

  static Future<void> clearCredentials() async {
    await clearConnection();
  }

  static Future<void> saveRetailerCode(String rawRetailer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefRetailer, normalizeRetailerCode(rawRetailer));
  }

  static Future<void> saveClientCredentials(String clientId, String clientSecret) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefClientId, clientId.trim());
    await prefs.setString(_prefClientSecret, clientSecret.trim());
    _runtimeClientId = clientId.trim();
    _runtimeClientSecret = clientSecret.trim();
    // Clear cached token — new credentials need fresh auth
    await prefs.remove(_prefAccessToken);
    await prefs.remove(_prefTokenExpiresAt);
  }

  static Future<bool> hasUserSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_prefClientId) ?? '';
    final secret = prefs.getString(_prefClientSecret) ?? '';
    return id.isNotEmpty && secret.isNotEmpty;
  }

  static Future<void> clearConnection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefRetailer);
    await prefs.remove(_prefAccessToken);
    await prefs.remove(_prefTokenExpiresAt);
    await prefs.remove(_prefLastConnectedAt);
    await prefs.remove(_prefLastError);
  }

  static Future<void> clearClientCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefClientId);
    await prefs.remove(_prefClientSecret);
    _runtimeClientId = '';
    _runtimeClientSecret = '';
    await prefs.remove(_prefAccessToken);
    await prefs.remove(_prefTokenExpiresAt);
  }

  static Future<KiotVietConnectionSnapshot> loadConnectionSnapshot({
    KiotVietLogHandler? onLog,
  }) async {
    _dispatchLog(onLog, 'init_start');
    try {
      final prefs = await SharedPreferences.getInstance();
      // Load runtime credentials from prefs into static fields
      final savedClientId = prefs.getString(_prefClientId)?.trim() ?? '';
      final savedClientSecret = prefs.getString(_prefClientSecret)?.trim() ?? '';
      if (savedClientId.isNotEmpty && savedClientSecret.isNotEmpty) {
        _runtimeClientId = savedClientId;
        _runtimeClientSecret = savedClientSecret;
      }

      final storedRetailer = prefs.getString(_prefRetailer)?.trim() ?? '';
      final retailerCode = storedRetailer.isEmpty
          ? ''
          : normalizeRetailerCode(storedRetailer);
      final tokenExpiresAt = prefs.getInt(_prefTokenExpiresAt);
      final now = DateTime.now().millisecondsSinceEpoch;

      final snapshot = KiotVietConnectionSnapshot(
        retailerCode: retailerCode,
        hasSecureConfiguration: hasSecureConfiguration,
        hasUserCredentials: savedClientId.isNotEmpty && savedClientSecret.isNotEmpty,
        savedClientId: savedClientId,
        hasCachedToken:
            (prefs.getString(_prefAccessToken)?.isNotEmpty ?? false) &&
            tokenExpiresAt != null &&
            tokenExpiresAt > now,
        tokenExpiresAt: tokenExpiresAt,
        lastConnectedAt: prefs.getInt(_prefLastConnectedAt),
        lastError: prefs.getString(_prefLastError),
      );

      _dispatchLog(
        onLog,
        'init_success',
        extras: {
          'hasSavedRetailer': snapshot.hasSavedRetailer,
          'hasSecureConfiguration': snapshot.hasSecureConfiguration,
          'hasCachedToken': snapshot.hasCachedToken,
        },
      );
      return snapshot;
    } catch (error, stackTrace) {
      _dispatchLog(
        onLog,
        'init_error',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static Future<void> connect(
    String rawRetailer, {
    http.Client? client,
    KiotVietLogHandler? onLog,
  }) async {
    final retailer = normalizeRetailerCode(rawRetailer);
    final prefs = await SharedPreferences.getInstance();

    _dispatchLog(onLog, 'connect_start', extras: {'retailer': retailer});

    try {
      final creds = _buildInternalCredentials(retailer);
      await saveRetailerCode(retailer);
      await _getAccessToken(creds, client: client, onLog: onLog);
      await prefs.setInt(
        _prefLastConnectedAt,
        DateTime.now().millisecondsSinceEpoch,
      );
      await prefs.remove(_prefLastError);
      _dispatchLog(onLog, 'connect_success', extras: {'retailer': retailer});
    } catch (error, stackTrace) {
      await prefs.setString(_prefLastError, error.toString());
      _dispatchLog(
        onLog,
        'connect_error',
        error: error,
        stackTrace: stackTrace,
        extras: {'retailer': retailer},
      );
      rethrow;
    }
  }

  static Future<KiotVietSyncResult> connectAndSync(
    String rawRetailer, {
    String? shopId,
    http.Client? client,
    void Function(String)? onProgress,
    KiotVietLogHandler? onLog,
  }) async {
    final retailer = normalizeRetailerCode(rawRetailer);
    await connect(retailer, client: client, onLog: onLog);
    final creds = _buildInternalCredentials(retailer);
    return syncAll(
      creds,
      shopId: shopId,
      client: client,
      onProgress: onProgress,
      onLog: onLog,
    );
  }

  static Future<String> _getAccessToken(
    KiotVietCredentials creds, {
    http.Client? client,
    KiotVietLogHandler? onLog,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final cachedToken = prefs.getString(_prefAccessToken);
    final cachedExpiry = prefs.getInt(_prefTokenExpiresAt) ?? 0;

    if ((cachedToken?.isNotEmpty ?? false) && cachedExpiry > now + 60000) {
      return cachedToken!;
    }

    final effectiveClient = client ?? http.Client();
    final shouldCloseClient = client == null;

    try {
      final response = await effectiveClient
          .post(
            Uri.parse(_tokenUrl),
            headers: const {
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {
              'grant_type': 'client_credentials',
              'client_id': creds.clientId,
              'client_secret': creds.clientSecret,
              'scopes': 'PublicApi.Access',
            },
          )
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        throw StateError(
          'Không lấy được token KiotViet (${response.statusCode}). Vui lòng kiểm tra mã cửa hàng hoặc cấu hình bảo mật.',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = (data['access_token'] as String?)?.trim() ?? '';
      if (token.isEmpty) {
        throw const FormatException('Phản hồi token từ KiotViet không hợp lệ.');
      }

      final expiresInSeconds = _toInt(data['expires_in'], fallback: 86400);
      final expiresAt = now + (expiresInSeconds * 1000);
      await prefs.setString(_prefAccessToken, token);
      await prefs.setInt(_prefTokenExpiresAt, expiresAt);
      await prefs.remove(_prefLastError);
      return token;
    } catch (error, stackTrace) {
      await prefs.setString(_prefLastError, error.toString());
      _dispatchLog(
        onLog,
        'connect_error',
        error: error,
        stackTrace: stackTrace,
        extras: {'retailer': creds.retailer},
      );
      rethrow;
    } finally {
      if (shouldCloseClient) {
        effectiveClient.close();
      }
    }
  }

  static Future<KiotVietSyncResult> syncProducts(
    KiotVietCredentials creds,
    String shopId, {
    http.Client? client,
    void Function(String)? onProgress,
    KiotVietLogHandler? onLog,
  }) async {
    final effectiveClient = client ?? http.Client();
    final shouldCloseClient = client == null;

    try {
      final token = await _getAccessToken(
        creds,
        client: effectiveClient,
        onLog: onLog,
      );
      final db = DBHelper();

      var added = 0;
      var updated = 0;
      var failed = 0;
      final errors = <String>[];

      var currentItem = 0;
      const pageSize = 100;
      var total = 0;

      do {
        final uri = Uri.parse(
          '$_apiBase/products?pageSize=$pageSize&currentItem=$currentItem',
        );
        final response = await effectiveClient
            .get(
              uri,
              headers: {
                'Authorization': 'Bearer $token',
                'Retailer': creds.retailer,
              },
            )
            .timeout(_requestTimeout);

        if (response.statusCode != 200) {
          throw StateError(
            'Lỗi API sản phẩm KiotViet (${response.statusCode}).',
          );
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = (data['data'] as List<dynamic>? ?? const []);
        total = _toInt(data['total'], fallback: items.length);

        onProgress?.call(
          'Đang xử lý sản phẩm ${currentItem + 1}-${currentItem + items.length} / $total...',
        );

        for (final kv in items) {
          try {
            final map = Map<String, dynamic>.from(kv as Map);
            final sku = (map['code'] as String? ?? '').trim();
            final name = (map['name'] as String? ?? '').trim();
            if (sku.isEmpty || name.isEmpty) {
              throw const FormatException('Thiếu SKU hoặc tên sản phẩm.');
            }

            final price = _toInt(map['basePrice']);
            final description = (map['categoryName'] as String? ?? '').trim();
            final status = map['allowsSale'] == true ? 1 : 0;
            final quantity = _toInt(map['onHand']);

            final existing = await db.database.then(
              (database) => database.rawQuery(
                'SELECT id FROM products WHERE sku = ? AND shopId = ?',
                [sku, shopId],
              ),
            );

            if (existing.isNotEmpty) {
              final existingId = existing.first['id'] as int;
              // Do NOT update quantity — KiotViet API returns total stock across all
              // branches, which inflates the local capital calculation. Only sync
              // descriptive fields; local quantity tracks this shop's stock.
              await db.database.then(
                (database) => database.rawUpdate(
                  'UPDATE products SET name = ?, price = ?, description = ?, status = ?, updatedAt = ? WHERE id = ?',
                  [
                    name,
                    price,
                    description,
                    status,
                    DateTime.now().millisecondsSinceEpoch,
                    existingId,
                  ],
                ),
              );
              updated++;
            } else {
              final product = Product(
                name: name,
                brand: 'KiotViet',
                cost: 0,
                price: price,
                status: status,
                description: description,
                quantity: quantity,
                createdAt: DateTime.now().millisecondsSinceEpoch,
                shopId: shopId,
                sku: sku,
                isSynced: false,
              );
              final productMap = product.toMap()..remove('id');
              await db.database.then(
                (database) => database.rawInsert(
                  'INSERT INTO products (${productMap.keys.join(',')}) VALUES (${List.filled(productMap.length, '?').join(',')})',
                  productMap.values.toList(),
                ),
              );
              added++;
            }
          } catch (error) {
            failed++;
            errors.add('Sản phẩm lỗi: $error');
          }
        }

        currentItem += items.length;
      } while (currentItem < total && total > 0);

      onProgress?.call(
        'Hoàn tất sản phẩm: +$added mới, ~$updated cập nhật, $failed lỗi',
      );

      return KiotVietSyncResult(
        added: added,
        updated: updated,
        failed: failed,
        errors: errors,
      );
    } finally {
      if (shouldCloseClient) {
        effectiveClient.close();
      }
    }
  }

  static Future<KiotVietSyncResult> syncCustomers(
    KiotVietCredentials creds,
    String shopId, {
    http.Client? client,
    void Function(String)? onProgress,
    KiotVietLogHandler? onLog,
  }) async {
    final effectiveClient = client ?? http.Client();
    final shouldCloseClient = client == null;

    try {
      final token = await _getAccessToken(
        creds,
        client: effectiveClient,
        onLog: onLog,
      );
      final db = DBHelper();

      var added = 0;
      var updated = 0;
      var failed = 0;
      final errors = <String>[];

      var currentItem = 0;
      const pageSize = 100;
      var total = 0;

      do {
        final uri = Uri.parse(
          '$_apiBase/customers?pageSize=$pageSize&currentItem=$currentItem',
        );
        final response = await effectiveClient
            .get(
              uri,
              headers: {
                'Authorization': 'Bearer $token',
                'Retailer': creds.retailer,
              },
            )
            .timeout(_requestTimeout);

        if (response.statusCode != 200) {
          throw StateError(
            'Lỗi API khách hàng KiotViet (${response.statusCode}).',
          );
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = (data['data'] as List<dynamic>? ?? const []);
        total = _toInt(data['total'], fallback: items.length);

        onProgress?.call(
          'Đang xử lý khách hàng ${currentItem + 1}-${currentItem + items.length} / $total...',
        );

        for (final kv in items) {
          try {
            final map = Map<String, dynamic>.from(kv as Map);
            final name = (map['name'] as String? ?? '').trim();
            final phone = (map['contactNumber'] as String? ?? '').trim();
            if (phone.isEmpty || name.isEmpty) {
              continue;
            }

            final email = (map['email'] as String?)?.trim();
            final address = (map['address'] as String?)?.trim();

            final existing = await db.database.then(
              (database) => database.rawQuery(
                'SELECT id FROM customers WHERE phone = ? AND shopId = ?',
                [phone, shopId],
              ),
            );

            if (existing.isNotEmpty) {
              final existingId = existing.first['id'] as int;
              await db.database.then(
                (database) => database.rawUpdate(
                  'UPDATE customers SET name = ?, email = ?, address = ?, updatedAt = ? WHERE id = ?',
                  [
                    name,
                    email,
                    address,
                    DateTime.now().millisecondsSinceEpoch,
                    existingId,
                  ],
                ),
              );
              updated++;
            } else {
              final customer = Customer(
                name: name,
                phone: phone,
                email: email,
                address: address,
                createdAt: DateTime.now().millisecondsSinceEpoch,
                shopId: shopId,
                isSynced: false,
              );
              final customerMap = customer.toMap()..remove('id');
              await db.database.then(
                (database) => database.rawInsert(
                  'INSERT INTO customers (${customerMap.keys.join(',')}) VALUES (${List.filled(customerMap.length, '?').join(',')})',
                  customerMap.values.toList(),
                ),
              );
              added++;
            }
          } catch (error) {
            failed++;
            errors.add('Khách hàng lỗi: $error');
          }
        }

        currentItem += items.length;
      } while (currentItem < total && total > 0);

      onProgress?.call(
        'Hoàn tất khách hàng: +$added mới, ~$updated cập nhật, $failed lỗi',
      );

      return KiotVietSyncResult(
        added: added,
        updated: updated,
        failed: failed,
        errors: errors,
      );
    } finally {
      if (shouldCloseClient) {
        effectiveClient.close();
      }
    }
  }

  static Future<KiotVietSyncResult> syncAll(
    KiotVietCredentials creds, {
    String? shopId,
    http.Client? client,
    void Function(String)? onProgress,
    KiotVietLogHandler? onLog,
  }) async {
    final resolvedShopId = (shopId ?? await UserService.getCurrentShopId() ?? '')
        .trim();
    if (resolvedShopId.isEmpty) {
      throw const FormatException(
        'Không xác định được cửa hàng hiện tại để đồng bộ KiotViet.',
      );
    }

    final effectiveClient = client ?? http.Client();
    final shouldCloseClient = client == null;

    try {
      onProgress?.call('Bắt đầu đồng bộ sản phẩm...');
      final productResult = await syncProducts(
        creds,
        resolvedShopId,
        client: effectiveClient,
        onProgress: onProgress,
        onLog: onLog,
      );

      onProgress?.call('Bắt đầu đồng bộ khách hàng...');
      final customerResult = await syncCustomers(
        creds,
        resolvedShopId,
        client: effectiveClient,
        onProgress: onProgress,
        onLog: onLog,
      );

      onProgress?.call('Đồng bộ hoàn tất.');
      return productResult + customerResult;
    } finally {
      if (shouldCloseClient) {
        effectiveClient.close();
      }
    }
  }

  static KiotVietCredentials _buildInternalCredentials(String retailer) {
    final clientId = _configuredClientId.trim().isNotEmpty
        ? _configuredClientId.trim()
        : _runtimeClientId.trim();
    final clientSecret = _configuredClientSecret.trim().isNotEmpty
        ? _configuredClientSecret.trim()
        : _runtimeClientSecret.trim();

    if (clientId.isEmpty || clientSecret.isEmpty) {
      throw StateError(
        'KiotViet chưa được cấu hình. Vui lòng nhập Client ID và Client Secret trong phần Kết nối KiotViet.',
      );
    }

    return KiotVietCredentials(
      retailer: normalizeRetailerCode(retailer),
      clientId: clientId,
      clientSecret: clientSecret,
    );
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static void _dispatchLog(
    KiotVietLogHandler? onLog,
    String event, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> extras = const {},
  }) {
    final payload = <String, Object?>{
      'event': event,
      'source': 'KiotVietService',
      ...extras,
    };

    developer.log(
      jsonEncode(payload),
      name: 'KiotViet',
      error: error,
      stackTrace: stackTrace,
    );

    if (stackTrace != null) {
      developer.log(
        stackTrace.toString(),
        name: 'KiotVietStackTrace',
        error: error,
        stackTrace: stackTrace,
      );
    }

    onLog?.call(
      event,
      error: error,
      stackTrace: stackTrace,
      extras: extras,
    );
  }
}
