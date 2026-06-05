import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/migration_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_app_bar.dart';

enum _Phase { setup, running, done }

class ShopMigrationView extends StatefulWidget {
  const ShopMigrationView({super.key});

  @override
  State<ShopMigrationView> createState() => _ShopMigrationViewState();
}

class _ShopMigrationViewState extends State<ShopMigrationView> {
  _Phase _phase = _Phase.setup;

  String? _sourceShopId;
  String? _sourceShopName;
  bool _shopsLoaded = true;

  final _targetController = TextEditingController();
  String? _targetShopId;
  String? _targetShopName;
  bool _verifying = false;
  String? _targetError;

  bool _isSuperAdmin = false;
  List<Map<String, dynamic>> _allShops = [];

  int? _estimatedCount;

  int _done = 0;
  int _total = 0;
  bool _cancelRequested = false;

  MigrationResult? _result;

  @override
  void initState() {
    super.initState();
    _loadSetupData();
  }

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _loadSetupData() async {
    try {
      final shopId = await UserService.getCurrentShopId();
      final isSuperAdmin = UserService.isCurrentUserSuperAdmin();
      String? shopName;
      int count = 0;
      List<Map<String, dynamic>> shops = [];

      if (shopId != null) {
        shopName = await _fetchShopName(shopId);
        count = await MigrationService.countRepairs(shopId);
      }
      if (isSuperAdmin) {
        shops = await UserService.getAllShops();
      }

      if (!mounted) return;
      setState(() {
        _sourceShopId = shopId;
        _sourceShopName = shopName;
        _isSuperAdmin = isSuperAdmin;
        _allShops = shops;
        _estimatedCount = count;
        _shopsLoaded = true;
      });
    } catch (e) {
      if (mounted) setState(() => _shopsLoaded = true);
    }
  }

  Future<String?> _fetchShopName(String shopId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('shops').doc(shopId).get();
      return doc.data()?['name'] as String? ?? shopId;
    } catch (_) {
      return shopId;
    }
  }

  Future<void> _verifyTarget() async {
    final id = _targetController.text.trim();
    if (id.isEmpty) {
      setState(() => _targetError = 'Nhập shopId của shop đích');
      return;
    }
    if (id == _sourceShopId) {
      setState(() => _targetError = 'Shop đích không được trùng shop nguồn');
      return;
    }
    setState(() {
      _verifying = true;
      _targetError = null;
      _targetShopId = null;
      _targetShopName = null;
    });
    try {
      final doc = await FirebaseFirestore.instance.collection('shops').doc(id).get();
      if (!doc.exists) {
        if (mounted) setState(() { _targetError = 'Không tìm thấy shop với ID này'; _verifying = false; });
        return;
      }
      final name = doc.data()?['name'] as String? ?? id;
      if (mounted) setState(() { _targetShopId = id; _targetShopName = name; _verifying = false; });
    } catch (e) {
      if (mounted) setState(() { _targetError = 'Lỗi xác minh: $e'; _verifying = false; });
    }
  }

  bool get _canProceed {
    if (_sourceShopId == null || _targetShopId == null) return false;
    return _targetShopId != _sourceShopId;
  }

  Future<void> _startMigration() async {
    if (!_canProceed) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận copy đơn sửa chữa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nguồn: ${_sourceShopName ?? _sourceShopId}'),
            const SizedBox(height: 4),
            Text('Đích: ${_targetShopName ?? _targetShopId}'),
            const SizedBox(height: 4),
            Text('Ước tính: ~${_estimatedCount ?? 0} đơn'),
            const SizedBox(height: 10),
            const Text(
              'Dữ liệu shop cũ giữ nguyên, không bị xóa.',
              style: TextStyle(fontSize: 12, color: Colors.deepOrange),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bắt đầu'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _phase = _Phase.running;
      _done = 0;
      _total = _estimatedCount ?? 0;
      _cancelRequested = false;
    });

    try {
      final result = await MigrationService.migrateRepairs(
        sourceShopId: _sourceShopId!,
        targetShopId: _targetShopId!,
        onProgress: (done, total) {
          if (mounted) setState(() { _done = done; _total = total; });
        },
        isCancelled: () => _cancelRequested,
      );
      if (mounted) setState(() { _result = result; _phase = _Phase.done; });
    } on MigrationCancelledException {
      if (mounted) {
        setState(() { _phase = _Phase.setup; _cancelRequested = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã dừng quá trình copy')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _result = MigrationResult(totalCopied: _done, errors: ['Lỗi: $e'], elapsed: Duration.zero);
          _phase = _Phase.done;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('BUILD_MIG phase=$_phase shopsLoaded=$_shopsLoaded result=${_result?.totalCopied}');
    return Scaffold(
      appBar: CustomAppBar.build(
        title: 'Chuyển đơn sửa chữa',
        subtitle: 'Copy sang shop mới, giữ nguyên shop cũ',
      ),
      body: _phase == _Phase.setup
          ? _buildSetup()
          : _phase == _Phase.running
              ? _buildRunning()
              : _buildDone(),
    );
  }

  Widget _buildSetup() {
    if (!_shopsLoaded) return const Center(child: CircularProgressIndicator());
    debugPrint('SETUP_A');
    final w = ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const Text('T1-RED', style: TextStyle(color: Colors.red, fontSize: 40, decoration: TextDecoration.none)),
        _sectionLabel('Shop nguồn'),
        const Text('T2-BLUE', style: TextStyle(color: Colors.blue, fontSize: 40, decoration: TextDecoration.none)),
        _shopInfoCard(color: Colors.blue, icon: Icons.store_outlined, name: 'Test Shop', shopId: 'test123'),
        const Text('T3-GREEN', style: TextStyle(color: Colors.green, fontSize: 40, decoration: TextDecoration.none)),
      ],
    );
    debugPrint('SETUP_B type=${w.runtimeType}');
    return w;
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
      );

  Widget _shopInfoCard({required Color color, required IconData icon, required String name, required String shopId}) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      color: color.withValues(alpha: 0.05),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        subtitle: shopId.isNotEmpty ? Text(shopId, style: const TextStyle(fontSize: 11)) : null,
      ),
    );
  }

  Widget _superAdminPicker() {
    final others = _allShops.where((s) => s['id'] != _sourceShopId).toList();
    if (!_shopsLoaded) return const LinearProgressIndicator();
    return DropdownButtonFormField<String>(
      // ignore: deprecated_member_use
      value: _targetShopId,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        hintText: 'Chọn shop đích...',
      ),
      items: others.map((s) {
        final id = s['id'] as String;
        final name = s['name'] as String? ?? id;
        return DropdownMenuItem(
          value: id,
          child: Text('$name  ($id)', overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (id) {
        if (id == null) return;
        final shop = others.firstWhere((s) => s['id'] == id);
        setState(() {
          _targetShopId = id;
          _targetShopName = shop['name'] as String? ?? id;
        });
      },
    );
  }

  Widget _ownerTargetField() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _targetController,
            decoration: InputDecoration(
              hintText: 'Nhập shopId của shop đích...',
              errorText: _targetError,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            onChanged: (_) => setState(() {
              _targetError = null;
              _targetShopId = null;
              _targetShopName = null;
            }),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _verifying ? null : _verifyTarget,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _verifying
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Xác minh'),
          ),
        ),
      ],
    );
  }

  Widget _buildRunning() {
    final pct = _total > 0 ? _done / _total : 0.0;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          const Icon(Icons.swap_horiz_rounded, size: 56, color: Colors.deepOrange),
          const SizedBox(height: 20),
          const Text('Đang copy đơn sửa chữa...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('$_done / $_total đơn', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: pct,
            minHeight: 10,
            backgroundColor: Colors.grey.shade200,
            color: Colors.deepOrange,
            borderRadius: BorderRadius.circular(5),
          ),
          const SizedBox(height: 8),
          Text(
            '${(pct * 100).toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.deepOrange),
          ),
          const SizedBox(height: 32),
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Không tắt app trong quá trình copy. Giữ kết nối mạng ổn định.',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _cancelRequested ? null : () => setState(() => _cancelRequested = true),
            icon: const Icon(Icons.stop_circle_outlined, color: Colors.red),
            label: Text(
              _cancelRequested ? 'Đang dừng...' : 'Dừng lại',
              style: const TextStyle(color: Colors.red),
            ),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildDone() {
    final result = _result;
    if (result == null) return const SizedBox.shrink();

    final mins = result.elapsed.inMinutes;
    final secs = result.elapsed.inSeconds % 60;
    final timeStr = mins > 0 ? '${mins}p ${secs}s' : '${secs}s';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Icon(
            result.hasErrors ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
            size: 72,
            color: result.hasErrors ? Colors.orange : AppColors.success,
          ),
          const SizedBox(height: 12),
          Text(
            result.hasErrors ? 'Hoàn tất (có lỗi)' : 'Hoàn tất!',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Đã copy ${result.totalCopied} đơn sửa chữa sang ${_targetShopName ?? _targetShopId ?? ''}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
          Text(
            'Thời gian: $timeStr',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 20),
          if (result.hasErrors)
            ExpansionTile(
              leading: const Icon(Icons.error_outline, color: Colors.red),
              title: Text('${result.errors.length} lỗi xảy ra',
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
              children: result.errors.take(10).map((e) => ListTile(
                dense: true,
                title: Text('• $e', style: const TextStyle(fontSize: 12, color: Colors.red)),
              )).toList(),
            ),
          const SizedBox(height: 16),
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Icon(Icons.checklist_rounded, size: 18, color: Colors.blue.shade700),
                    const SizedBox(width: 6),
                    Text('Bước tiếp theo',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.blue.shade700)),
                  ]),
                  const SizedBox(height: 10),
                  const Text(
                    '1. Đăng xuất khỏi app\n'
                    '2. Đăng nhập bằng tài khoản shop mới\n'
                    '3. Chờ đồng bộ tự động (~1–2 phút)\n'
                    '4. Kiểm tra danh sách đơn sửa chữa',
                    style: TextStyle(fontSize: 13, height: 1.8),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            label: const Text('Đóng'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }
}
