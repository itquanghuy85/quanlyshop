import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../models/product_model.dart';
import '../models/sale_order_model.dart';
import '../models/expense_model.dart';
import '../models/debt_model.dart';
import '../models/attendance_model.dart';
import 'storage_service.dart';
import 'user_service.dart';

class SyncService {
  static final _db = FirebaseFirestore.instance;
  static final List<StreamSubscription> _subscriptions = [];

  /// Khởi tạo đồng bộ thời gian thực
  static Future<void> initRealTimeSync(VoidCallback onDataChanged) async {
    debugPrint("Khởi tạo real-time sync...");
    // Hủy các subscription cũ nếu có để tránh rò rỉ bộ nhớ hoặc lặp sự kiện
    await cancelAllSubscriptions();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final bool isSuperAdmin = UserService.isCurrentUserSuperAdmin();
    final String? shopId = isSuperAdmin ? null : await UserService.getCurrentShopId();

    // 1. Đồng bộ REPAIRS
    _subscribeToCollection(
      collection: 'repairs',
      shopId: shopId,
      onChanged: (data, docId) async {
        try {
          final db = DBHelper();
          if (data['deleted'] == true) {
            await db.deleteRepairByFirestoreId(docId);
          } else {
            data['firestoreId'] = docId;
            await db.upsertRepair(Repair.fromMap(data));
          }
        } catch (e) {
          debugPrint("Lỗi sync repair $docId: $e");
        }
      },
      onBatchDone: onDataChanged,
    );

    // 2. Đồng bộ SALES
    _subscribeToCollection(
      collection: 'sales',
      shopId: shopId,
      onChanged: (data, docId) async {
        try {
          final db = DBHelper();
          if (data['deleted'] == true) {
            await db.deleteSaleByFirestoreId(docId);
          } else {
            data['firestoreId'] = docId;
            await db.upsertSale(SaleOrder.fromMap(data));
          }
        } catch (e) {
          debugPrint("Lỗi sync sale $docId: $e");
        }
      },
      onBatchDone: onDataChanged,
    );

    // 3. Đồng bộ PRODUCTS
    _subscribeToCollection(
      collection: 'products',
      shopId: shopId,
      onChanged: (data, docId) async {
        try {
          final db = DBHelper();
          if (data['deleted'] == true) {
            await db.deleteProductByFirestoreId(docId);
          } else {
            data['firestoreId'] = docId;
            await db.upsertProduct(Product.fromMap(data));
          }
        } catch (e) {
          debugPrint("Lỗi sync product $docId: $e");
        }
      },
      onBatchDone: onDataChanged,
    );

    // 4. Đồng bộ EXPENSES
    _subscribeToCollection(
      collection: 'expenses',
      shopId: shopId,
      onChanged: (data, docId) async {
        try {
          final db = DBHelper();
          if (data['deleted'] == true) {
            await db.deleteExpenseByFirestoreId(docId);
          } else {
            data['firestoreId'] = docId;
            await db.upsertExpense(Expense.fromMap(data));
          }
        } catch (e) {
          debugPrint("Lỗi sync expense $docId: $e");
        }
      },
      onBatchDone: onDataChanged,
    );

    // 5. Đồng bộ DEBTS
    _subscribeToCollection(
      collection: 'debts',
      shopId: shopId,
      onChanged: (data, docId) async {
        try {
          final db = DBHelper();
          if (data['deleted'] == true) {
            await db.deleteDebtByFirestoreId(docId);
          } else {
            data['firestoreId'] = docId;
            await db.upsertDebt(Debt.fromMap(data));
          }
        } catch (e) {
          debugPrint("Lỗi sync debt $docId: $e");
        }
      },
      onBatchDone: onDataChanged,
    );

    // 6. Đồng bộ USERS (cập nhật cache khi có thay đổi)
    _subscribeToCollection(
      collection: 'users',
      shopId: shopId,
      onChanged: (data, docId) async {
        try {
          // Nếu là user hiện tại, cập nhật cache shopId
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null && docId == currentUser.uid) {
            UserService.updateCachedShopId(data['shopId']);
            debugPrint("Updated cached shopId: ${data['shopId']}");
          }
        } catch (e) {
          debugPrint("Lỗi sync user $docId: $e");
        }
      },
      onBatchDone: onDataChanged,
    );

    // 7. Đồng bộ SHOPS (cập nhật cache khi có thay đổi)
    _subscribeToCollection(
      collection: 'shops',
      shopId: shopId,
      onChanged: (data, docId) async {
        try {
          // Shop data changed, có thể trigger UI update nếu cần
          debugPrint("Shop data changed: $docId");
        } catch (e) {
          debugPrint("Lỗi sync shop $docId: $e");
        }
      },
      onBatchDone: onDataChanged,
    );

    // 8. Đồng bộ ATTENDANCE
    try {
      _subscribeToCollection(
        collection: 'attendance',
        shopId: shopId,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true) {
              await db.deleteAttendanceByFirestoreId(docId);
            } else {
              data['firestoreId'] = docId;
              await db.upsertAttendance(Attendance.fromMap(data));
            }
          } catch (e) {
            debugPrint("Lỗi sync attendance $docId: $e");
          }
        },
        onBatchDone: onDataChanged,
      );
    } catch (e) {
      debugPrint("Lỗi khởi tạo attendance sync: $e");
    }
    debugPrint("Đã khởi tạo real-time sync cho ${isSuperAdmin ? 'super admin' : 'shop: $shopId'}");
  }

  /// Hàm helper để quản lý subscription an toàn
  static void _subscribeToCollection({
    required String collection,
    String? shopId,
    required Future<void> Function(Map<String, dynamic> data, String docId) onChanged,
    required VoidCallback onBatchDone,
  }) {
    Query<Map<String, dynamic>> query = _db.collection(collection);
    if (shopId != null) {
      query = query.where('shopId', isEqualTo: shopId);
    }

    final sub = query.snapshots().listen((snapshot) async {
      for (var change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;
        debugPrint("Real-time change in $collection: ${change.doc.id}, type: ${change.type}");
        await onChanged(data, change.doc.id);
      }
      onBatchDone();
    }, onError: (e) => debugPrint("Sync error in $collection: $e"));

    _subscriptions.add(sub);
  }

  static Future<void> cancelAllSubscriptions() async {
    for (var sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
  }

  /// Đẩy dữ liệu từ Local lên Cloud (Dùng khi có mạng trở lại)
  static Future<void> syncAllToCloud() async {
    debugPrint("Bắt đầu syncAllToCloud...");
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("Không có user, bỏ qua syncAllToCloud");
        return;
      }
      
      final String? shopId = await UserService.getCurrentShopId();
      final dbHelper = DBHelper();

      // Chỉ đẩy những đơn hàng CHƯA đồng bộ hoặc CÓ thay đổi hình ảnh
      final repairs = await dbHelper.getAllRepairs();
      debugPrint("syncAllToCloud: có ${repairs.length} repairs cần sync");
      final WriteBatch repairBatch = _db.batch();
      for (var r in repairs) {
        if (r.isSynced && !(r.imagePath?.contains('cache') ?? false)) continue;

        try {
          Map<String, dynamic> data = r.toMap();
          data['shopId'] = shopId;
          data.remove('id');

          // Xử lý upload ảnh nếu là ảnh local với timeout
          if (r.imagePath != null && r.imagePath!.isNotEmpty && !r.imagePath!.startsWith('http')) {
            List<String> urls = await StorageService.uploadMultipleImages(
              r.imagePath!.split(',').where((path) => !path.startsWith('http')).toList(), 
              'repairs/${r.createdAt}'
            ).timeout(const Duration(seconds: 30), onTimeout: () {
              debugPrint("Upload ảnh repair ${r.id} quá thời gian, bỏ qua");
              return <String>[];
            });
            // Giữ lại các ảnh cũ là URL và thêm ảnh mới
            List<String> allUrls = r.imagePath!.split(',').where((path) => path.startsWith('http')).toList();
            allUrls.addAll(urls);
            data['imagePath'] = allUrls.join(',');
          }

          final docId = r.firestoreId ?? "repair_${r.createdAt}_${r.phone}_${r.id ?? 0}";
          repairBatch.set(_db.collection('repairs').doc(docId), data, SetOptions(merge: true));
          
          r.isSynced = true;
          r.firestoreId = docId;
          r.imagePath = data['imagePath'];
          await dbHelper.updateRepair(r);
        } catch (e) {
          debugPrint("Lỗi sync repair ${r.id}: $e");
          // Tiếp tục với repair tiếp theo thay vì dừng toàn bộ
        }
      }
      await repairBatch.commit();

      // Sync SALES
      final sales = await dbHelper.getAllSales();
      debugPrint("syncAllToCloud: có ${sales.length} sales cần sync");
      final WriteBatch saleBatch = _db.batch();
      for (var s in sales) {
        if (s.isSynced) continue;

        try {
          Map<String, dynamic> data = s.toMap();
          data['shopId'] = shopId;
          data.remove('id');

          final docId = s.firestoreId ?? "sale_${s.soldAt}_${s.phone}_${s.id ?? 0}";
          saleBatch.set(_db.collection('sales').doc(docId), data, SetOptions(merge: true));
          
          s.isSynced = true;
          s.firestoreId = docId;
          await dbHelper.updateSale(s);
        } catch (e) {
          debugPrint("Lỗi sync sale ${s.id}: $e");
          // Tiếp tục với sale tiếp theo
        }
      }
      await saleBatch.commit();

      // Sync PRODUCTS
      final products = await dbHelper.getAllProducts();
      debugPrint("syncAllToCloud: có ${products.length} products cần sync");
      final WriteBatch productBatch = _db.batch();
      for (var p in products) {
        if (p.isSynced) continue;

        try {
          Map<String, dynamic> data = p.toMap();
          data['shopId'] = shopId;
          data.remove('id');

          // Xử lý upload ảnh nếu là ảnh local với timeout
          if (p.images != null && p.images!.isNotEmpty && !p.images!.startsWith('http')) {
            List<String> urls = await StorageService.uploadMultipleImages(
              p.images!.split(',').where((path) => !path.startsWith('http')).toList(), 
              'products/${p.createdAt}'
            ).timeout(const Duration(seconds: 30), onTimeout: () {
              debugPrint("Upload ảnh product ${p.id} quá thời gian, bỏ qua");
              return <String>[];
            });
            data['images'] = urls.join(',');
          }

          final docId = p.firestoreId ?? "product_${p.createdAt}_${p.imei ?? 'noimei'}_${p.id ?? 0}";
          productBatch.set(_db.collection('products').doc(docId), data, SetOptions(merge: true));
          
          p.isSynced = true;
          p.firestoreId = docId;
          p.images = data['images'];
          await dbHelper.updateProduct(p);
        } catch (e) {
          debugPrint("Lỗi sync product ${p.id}: $e");
          // Tiếp tục với product tiếp theo
        }
      }
      await productBatch.commit();

      // Sync ATTENDANCE
      try {
        final attendance = await dbHelper.getAllAttendance();
        debugPrint("syncAllToCloud: có ${attendance.length} attendance cần sync");
        final WriteBatch attendanceBatch = _db.batch();
        for (var a in attendance) {
          if (a.firestoreId != null && a.firestoreId!.isNotEmpty) continue; // Đã sync rồi

          try {
            Map<String, dynamic> data = a.toMap();
            data['shopId'] = shopId;
            data.remove('id');

            // Xử lý upload ảnh check-in/out nếu là ảnh local
            if (a.photoIn != null && a.photoIn!.isNotEmpty && !a.photoIn!.startsWith('http')) {
              List<String> urls = await StorageService.uploadMultipleImages(
                [a.photoIn!],
                'attendance/${a.dateKey}_${a.userId}_in'
              ).timeout(const Duration(seconds: 30), onTimeout: () {
                debugPrint("Upload ảnh check-in ${a.id} quá thời gian, bỏ qua");
                return <String>[];
              });
              if (urls.isNotEmpty) data['photoIn'] = urls.first;
            }

            if (a.photoOut != null && a.photoOut!.isNotEmpty && !a.photoOut!.startsWith('http')) {
              List<String> urls = await StorageService.uploadMultipleImages(
                [a.photoOut!],
                'attendance/${a.dateKey}_${a.userId}_out'
              ).timeout(const Duration(seconds: 30), onTimeout: () {
                debugPrint("Upload ảnh check-out ${a.id} quá thời gian, bỏ qua");
                return <String>[];
              });
              if (urls.isNotEmpty) data['photoOut'] = urls.first;
            }

            final docId = a.firestoreId ?? "attendance_${a.userId}_${a.dateKey}";
            attendanceBatch.set(_db.collection('attendance').doc(docId), data, SetOptions(merge: true));

            a.firestoreId = docId;
            a.photoIn = data['photoIn'];
            a.photoOut = data['photoOut'];
            await dbHelper.updateAttendance(a);
          } catch (e) {
            debugPrint("Lỗi sync attendance ${a.id}: $e");
            // Tiếp tục với attendance tiếp theo
          }
        }
        await attendanceBatch.commit();
      } catch (e) {
        debugPrint("Lỗi sync attendance collection: $e");
      }

      debugPrint("Đã hoàn thành đồng bộ toàn bộ dữ liệu lên Cloud.");
    } catch (e) {
      debugPrint("Lỗi syncAllToCloud: $e");
    }
  }

  /// Tải toàn bộ dữ liệu từ Cloud về (Dùng khi cài lại app hoặc đổi máy)
  static Future<void> downloadAllFromCloud() async {
    debugPrint("Bắt đầu downloadAllFromCloud...");
    try {
      final db = DBHelper();
      final String? shopId = await UserService.getCurrentShopId();
      if (shopId == null) {
        debugPrint("Không có shopId, bỏ qua downloadAllFromCloud");
        return;
      }

      // Log local data counts before sync
      final localRepairs = await db.getAllRepairs();
      final localProducts = await db.getInStockProducts();
      final localSales = await db.getAllSales();
      final localAttendance = await db.getAllAttendance();
      debugPrint("LOCAL DATA BEFORE SYNC: repairs=${localRepairs.length}, products=${localProducts.length}, sales=${localSales.length}, attendance=${localAttendance.length}");

      final collections = ['repairs', 'products', 'sales', 'expenses', 'debts', 'users', 'shops', 'attendance'];
      
      for (var col in collections) {
        try {
          final snap = await _db.collection(col).where('shopId', isEqualTo: shopId).get();
          debugPrint("downloadAllFromCloud: collection $col có ${snap.docs.length} documents");
          for (var doc in snap.docs) {
            try {
              final data = doc.data();
              if (data['deleted'] == true) continue;
              
              data['firestoreId'] = doc.id;
              if (col == 'repairs') {
                await db.upsertRepair(Repair.fromMap(data));
              } else if (col == 'products') await db.upsertProduct(Product.fromMap(data));
              else if (col == 'sales') await db.upsertSale(SaleOrder.fromMap(data));
              else if (col == 'expenses') await db.upsertExpense(Expense.fromMap(data));
              else if (col == 'debts') await db.upsertDebt(Debt.fromMap(data));
              else if (col == 'attendance') {
                try {
                  await db.upsertAttendance(Attendance.fromMap(data));
                } catch (e) {
                  debugPrint("Lỗi upsert attendance ${doc.id}: $e");
                }
              }
              // Users và shops không cần upsert local vì không có DB local
            } catch (e) {
              debugPrint("Lỗi xử lý document ${doc.id} trong collection $col: $e");
              // Tiếp tục với document tiếp theo
            }
          }
        } catch (e) {
          debugPrint("Lỗi tải collection $col: $e");
          // Tiếp tục với collection tiếp theo
        }
      }

      // Log local data counts after sync
      final localRepairsAfter = await db.getAllRepairs();
      final localProductsAfter = await db.getInStockProducts();
      final localSalesAfter = await db.getAllSales();
      final localAttendanceAfter = await db.getAllAttendance();
      debugPrint("LOCAL DATA AFTER SYNC: repairs=${localRepairsAfter.length}, products=${localProductsAfter.length}, sales=${localSalesAfter.length}, attendance=${localAttendanceAfter.length}");

      debugPrint("Đã hoàn thành downloadAllFromCloud.");
    } catch (e) {
      debugPrint("Lỗi downloadAllFromCloud: $e");
    }
  }
}
