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

  // Source info
  String? _sourceShopId;
  String? _sourceShopName;

  // Target info
  final _targetController = TextEditingController();
  String? _targetShopId;
  String? _targetShopName;
  bool _verifying = false;
  String? _targetError;

  // Super-admin mode
  bool _isSuperAdmin = false;
  List<Map<String, dynamic>> _allShops = [];
  bool _shopsLoaded = false;

  // Estimate
  int? _estimatedCount;

  // Running phase
  int _done = 0;
  int _total = 0;
  bool _cancelRequested = false;

  // Done phase
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
    final shopId = await UserService.getCurrentShopId();
    final isSuperAdmin = UserService.isCurrentUserSuperAdmin();

    String? shopName;
    if (shopId != null) {
      shopName = await _fetchShopName(shopId);
      final count = await MigrationService.countRepairs(shopId);
      if (mounted) setState(() => _estimatedCount = count);
    }

    List<Map<String, dynamic>> shops = [];
    if (isSuperAdmin) {
      shops = await UserService.getAllShops();
    }

    if (mounted) {
      setState(() {
        _sourceShopId = shopId;
        _sourceShopName = shopName;
        _isSuperAdmin = isSuperAdmin;
        _allShops = shops;
        _shopsLoaded = true;
      });
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
    setState(() { _verifying = true; _targetError = null; _targetShopId = null; _targetShopName = null; });
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
    if (_sourceShopId == null) return false;
    if (_isSuperAdmin) return _targetShopId != null && _targetShopId != _sourceShopId;
    return _targetShopId != null;
  }

  Future<bool> _showConfirmDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.swap_horiz_rounded, color: Colors.deepOrange),
          SizedBox(width: 8),
          Text('Xác nhận copy đơn sửa', style: TextStyle(fontSize: 16)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(Icons.store_outlined, 'Nguồn:', _sourceShopName ?? _sourceShopId ?? ''),
            const SizedBox(height: 8),
            _infoRow(Icons.store_outlined, 'Đích:', _targetShopName ?? _targetShopId ?? ''),
            const SizedBox(height: 8),
            _infoRow(Icons.build_outlined, 'Ước tính:', '~${_estimatedCount ?? 0} đơn sửa chữa'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Text(
                'Dữ liệu ở shop cũ vẫn giữ nguyên. Shop mới sẽ nhận bản sao.',
                style: TextStyle(fontSize: 12, color: Colors.deepOrange),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bắt đầu copy'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Widget _infoRow(IconData icon, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: Colors.grey),
      const SizedBox(width: 6),
      Text('$label ', style: const TextStyle(fontSize: 13, color: Colors.grey)),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
    ],
  );

  Future<void> _startMigration() async {
    if (!_canProceed) return;
    final confirmed = await _showConfirmDialog();
    if (!confirmed || !mounted) return;

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
          const SnackBar(content: Text('Đã dừng quá trình chuyển dữ liệu')),
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

  Future<bool> _onWillPop() async {
    if (_phase != _Phase.running) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dừng quá trình?'),
        content: const Text('Đang copy dữ liệu. Thoát sẽ dừng sau batch hiện tại.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tiếp tục')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Dừng', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (leave == true) setState(() => _cancelRequested = true);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _phase != _Phase.running,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _onWillPop();
      },
      child: Scaffold(
        appBar: CustomAppBar.build(
          title: 'Chuyển đơn sửa chữa',
          subtitle: 'Copy sang shop mới, giữ nguyên shop cũ',
        ),
        body: switch (_phase) {
          _Phase.setup  => _buildSetup(),
          _Phase.running => _buildRunning(),
          _Phase.done   => _buildDone(),
        },
      ),
    );
  }

  // ── Phase 1: Setup ─────────────────────────────────────────────────────────

  Widget _buildSetup() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildShopCard(
            color: const Color(0xFF1565C0),
            icon: Icons.store_outlined,
            label: 'Shop nguồn (hiện tại)',
            name: _sourceShopName,
            shopId: _sourceShopId,
            isLoading: !_shopsLoaded,
          ),
          const SizedBox(height: 12),
          _isSuperAdmin ? _buildSuperAdminTargetPicker() : _buildOwnerTargetField(),
          const SizedBox(height: 12),
          if (_sourceShopId != null) _buildEstimateCard(),
          const SizedBox(height: 12),
          _buildWarningCard(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: _canProceed ? _startMigration : null,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Tiếp tục', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildShopCard({
    required Color color,
    required IconData icon,
    required String label,
    required String? name,
    required String? shopId,
    bool isLoading = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: isLoading
                ? const LinearProgressIndicator()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(name ?? shopId ?? 'Chưa xác định',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                      if (shopId != null)
                        Text(shopId,
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuperAdminTargetPicker() {
    final otherShops = _allShops.where((s) => s['id'] != _sourceShopId).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Shop đích', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _targetShopId,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            hintText: 'Chọn shop đích...',
          ),
          items: otherShops.map((s) {
            final id = s['id'] as String;
            final name = s['name'] as String? ?? id;
            return DropdownMenuItem(value: id, child: Text('$name  ($id)', overflow: TextOverflow.ellipsis));
          }).toList(),
          onChanged: (id) {
            if (id == null) return;
            final shop = otherShops.firstWhere((s) => s['id'] == id);
            setState(() {
              _targetShopId = id;
              _targetShopName = shop['name'] as String? ?? id;
            });
          },
        ),
        if (_targetShopName != null) ...[
          const SizedBox(height: 8),
          _buildShopCard(
            color: const Color(0xFF2E7D32),
            icon: Icons.store_mall_directory_outlined,
            label: 'Shop đích đã chọn',
            name: _targetShopName,
            shopId: _targetShopId,
          ),
        ],
      ],
    );
  }

  Widget _buildOwnerTargetField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Shop đích', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _targetController,
                decoration: InputDecoration(
                  hintText: 'Nhập shopId của shop mới...',
                  errorText: _targetError,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (_) => setState(() { _targetError = null; _targetShopId = null; _targetShopName = null; }),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _verifying ? null : _verifyTarget,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _verifying
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Xác minh'),
            ),
          ],
        ),
        if (_targetShopName != null) ...[
          const SizedBox(height: 10),
          _buildShopCard(
            color: const Color(0xFF2E7D32),
            icon: Icons.store_mall_directory_outlined,
            label: 'Shop đích đã xác minh',
            name: _targetShopName,
            shopId: _targetShopId,
          ),
        ],
      ],
    );
  }

  Widget _buildEstimateCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(children: [
        Icon(Icons.build_outlined, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          _estimatedCount == null
              ? 'Đang đếm số đơn...'
              : '~$_estimatedCount đơn sửa chữa sẽ được copy sang shop mới',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
      ]),
    );
  }

  Widget _buildWarningCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Dữ liệu ở shop cũ giữ nguyên, không bị xóa.\n'
              'Shop mới sẽ nhận bản sao với ID mới.\n'
              'Sau khi copy xong, đăng nhập shop mới để đồng bộ.',
              style: TextStyle(fontSize: 12, height: 1.6, color: Colors.orange.shade900),
            ),
          ),
        ],
      ),
    );
  }

  // ── Phase 2: Running ───────────────────────────────────────────────────────

  Widget _buildRunning() {
    final pct = _total > 0 ? _done / _total : 0.0;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.swap_horiz_rounded, size: 56, color: Colors.deepOrange),
          const SizedBox(height: 20),
          const Text(
            'Đang copy đơn sửa chữa...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '$_done / $_total đơn',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              color: Colors.deepOrange,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(pct * 100).toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.deepOrange),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Không tắt app trong quá trình copy. Kết nối mạng phải ổn định.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _cancelRequested
                ? null
                : () => setState(() => _cancelRequested = true),
            icon: const Icon(Icons.stop_circle_outlined, color: Colors.red),
            label: Text(_cancelRequested ? 'Đang dừng...' : 'Dừng lại',
                style: const TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── Phase 3: Done ──────────────────────────────────────────────────────────

  Widget _buildDone() {
    final result = _result!;
    final mins = result.elapsed.inMinutes;
    final secs = result.elapsed.inSeconds % 60;
    final timeStr = mins > 0 ? '${mins}p ${secs}s' : '${secs}s';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
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
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Đã copy ${result.totalCopied} đơn sửa chữa sang ${_targetShopName ?? _targetShopId ?? ''}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Text(
            'Thời gian: $timeStr',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 20),
          // Errors
          if (result.hasErrors)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              leading: Icon(Icons.error_outline, color: Colors.red.shade600),
              title: Text('${result.errors.length} lỗi xảy ra',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
              children: result.errors.take(10).map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• $e', style: const TextStyle(fontSize: 12, color: Colors.red)),
              )).toList(),
            ),
          const SizedBox(height: 16),
          // Next steps
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.checklist_rounded, size: 18, color: Colors.blue.shade700),
                  const SizedBox(width: 6),
                  Text('Bước tiếp theo', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.blue.shade700)),
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
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              label: const Text('Đóng'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
