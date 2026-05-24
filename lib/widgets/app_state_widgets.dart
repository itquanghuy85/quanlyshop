import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';

// ── Skeleton shimmer base ──────────────────────────────────────────────────────

class _SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  const _SkeletonBox({required this.width, required this.height, this.radius = 8});

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppColors.grey200,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }
}

// ── Skeleton row (icon + lines) ───────────────────────────────────────────────

class AppSkeletonRow extends StatelessWidget {
  final bool showLeading;
  final double lineWidth1;
  final double lineWidth2;
  const AppSkeletonRow({
    super.key,
    this.showLeading = true,
    this.lineWidth1 = 160,
    this.lineWidth2 = 100,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (showLeading) ...[
            _SkeletonBox(width: 42, height: 42, radius: DesignTokens.radiusMd),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(width: lineWidth1, height: 13),
                const SizedBox(height: 6),
                _SkeletonBox(width: lineWidth2, height: 11),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const _SkeletonBox(width: 56, height: 13),
        ],
      ),
    );
  }
}

// ── Skeleton list ─────────────────────────────────────────────────────────────

class AppSkeletonList extends StatelessWidget {
  final int itemCount;
  final bool showLeading;
  const AppSkeletonList({super.key, this.itemCount = 6, this.showLeading = true});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 70, endIndent: 16),
      itemBuilder: (_, i) => AppSkeletonRow(
        showLeading: showLeading,
        lineWidth1: 100 + (i % 3) * 40,
        lineWidth2: 60 + (i % 4) * 20,
      ),
    );
  }
}

// ── Skeleton card ─────────────────────────────────────────────────────────────

class AppSkeletonCard extends StatelessWidget {
  final double height;
  const AppSkeletonCard({super.key, this.height = 80});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _SkeletonBox(width: 42, height: 42, radius: DesignTokens.radiusMd),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SkeletonBox(width: 140, height: 13),
                const SizedBox(height: 6),
                const _SkeletonBox(width: 90, height: 11),
              ],
            )),
            const _SkeletonBox(width: 60, height: 13),
          ]),
        ],
      ),
    );
  }
}

// ── Loading section (inline, non-blocking) ────────────────────────────────────

class AppLoadingSection extends StatelessWidget {
  final String? message;
  const AppLoadingSection({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(
                message!,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Full-screen loading (bootstrap / heavy operation) ─────────────────────────

class AppFullScreenLoader extends StatelessWidget {
  final String message;
  const AppFullScreenLoader({super.key, this.message = 'Đang tải...'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.grey100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: AppColors.grey400),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Error / retry state ───────────────────────────────────────────────────────

class AppErrorState extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const AppErrorState({super.key, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, size: 30, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            Text(
              message ?? 'Không thể tải dữ liệu',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Kiểm tra kết nối và thử lại',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Thử lại'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Inline save button with loading state ─────────────────────────────────────

class AppSaveButton extends StatelessWidget {
  final bool saving;
  final VoidCallback? onPressed;
  final String label;
  final String savingLabel;

  const AppSaveButton({
    super.key,
    required this.saving,
    required this.onPressed,
    this.label = 'Lưu',
    this.savingLabel = 'Đang lưu...',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: DesignTokens.buttonHeight,
      child: FilledButton(
        onPressed: saving ? null : onPressed,
        child: saving
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Text(savingLabel),
                ],
              )
            : Text(label),
      ),
    );
  }
}

// ── Sync status chip (inline, small) ──────────────────────────────────────────

enum AppSyncState { localOnly, pending, syncing, synced, error }

class AppSyncChip extends StatelessWidget {
  final AppSyncState state;
  const AppSyncChip({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String label) = switch (state) {
      AppSyncState.localOnly => (Icons.storage_rounded, AppColors.textSecondary, 'Trên máy'),
      AppSyncState.pending   => (Icons.cloud_upload_outlined, AppColors.warning, 'Chờ đồng bộ'),
      AppSyncState.syncing   => (Icons.sync_rounded, AppColors.info, 'Đang đồng bộ'),
      AppSyncState.synced    => (Icons.cloud_done_outlined, AppColors.success, 'Đã đồng bộ'),
      AppSyncState.error     => (Icons.cloud_off_rounded, AppColors.error, 'Lỗi đồng bộ'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Section loading (partial load within a page) ──────────────────────────────

class AppSectionLoader extends StatelessWidget {
  final bool loading;
  final Widget child;
  final int skeletonCount;

  const AppSectionLoader({
    super.key,
    required this.loading,
    required this.child,
    this.skeletonCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    if (!loading) return child;
    return AppSkeletonList(itemCount: skeletonCount);
  }
}
