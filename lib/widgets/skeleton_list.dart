import 'package:flutter/material.dart';

enum SkeletonVariant { listTile, repairCard, inventoryRow, debtCard }

/// Full-page skeleton replacement for ListView loading state.
/// Usage: `_isLoading ? const SkeletonListView() : actualList`
class SkeletonListView extends StatelessWidget {
  final int itemCount;
  final SkeletonVariant variant;
  final EdgeInsets padding;

  const SkeletonListView({
    super.key,
    this.itemCount = 7,
    this.variant = SkeletonVariant.listTile,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: ListView.separated(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _buildItem(i),
      ),
    );
  }

  Widget _buildItem(int index) {
    switch (variant) {
      case SkeletonVariant.repairCard:
        return _RepairCardSkeleton(index: index);
      case SkeletonVariant.inventoryRow:
        return _InventoryRowSkeleton();
      case SkeletonVariant.debtCard:
        return _DebtCardSkeleton();
      case SkeletonVariant.listTile:
        return _ListTileSkeleton();
    }
  }
}

// ──────────────────────────────────────────
// Shimmer pulse wrapper
// ──────────────────────────────────────────
class _Shimmer extends StatefulWidget {
  final Widget child;
  const _Shimmer({required this.child});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
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
      builder: (_, child) => Opacity(opacity: 0.45 + _anim.value * 0.45, child: child),
      child: widget.child,
    );
  }
}

// ──────────────────────────────────────────
// Primitive skeleton box
// ──────────────────────────────────────────
class _Box extends StatelessWidget {
  final double height;
  final double width;
  final double radius;

  const _Box({required this.height, this.width = double.infinity, this.radius = 6});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ──────────────────────────────────────────
// Repair / Sale card skeleton  (2-line + trailing)
// ──────────────────────────────────────────
class _RepairCardSkeleton extends StatelessWidget {
  final int index;
  const _RepairCardSkeleton({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          // Leading circle (status / number)
          _Box(height: 40, width: 40, radius: 20),
          const SizedBox(width: 12),
          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Box(height: 13, width: 160 + (index % 3) * 20.0),
                const SizedBox(height: 6),
                _Box(height: 11, width: 120 + (index % 2) * 30.0),
                const SizedBox(height: 6),
                _Box(height: 10, width: 90.0),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Trailing: amount + status chip
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Box(height: 14, width: 72),
              const SizedBox(height: 6),
              _Box(height: 22, width: 60, radius: 10),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// Inventory row skeleton
// ──────────────────────────────────────────
class _InventoryRowSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          // Product image placeholder
          _Box(height: 44, width: 44, radius: 8),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Box(height: 13, width: double.infinity),
                const SizedBox(height: 5),
                _Box(height: 10, width: 100),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Box(height: 13, width: 50),
              const SizedBox(height: 5),
              _Box(height: 11, width: 70),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// Debt card skeleton
// ──────────────────────────────────────────
class _DebtCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Box(height: 36, width: 36, radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Box(height: 13, width: 140),
                    const SizedBox(height: 5),
                    _Box(height: 10, width: 90),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Box(height: 15, width: 80),
                  const SizedBox(height: 5),
                  _Box(height: 20, width: 55, radius: 8),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Urgency bar placeholder
          _Box(height: 4, radius: 2),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// Generic list tile skeleton
// ──────────────────────────────────────────
class _ListTileSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          _Box(height: 36, width: 36, radius: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Box(height: 13, width: double.infinity),
                const SizedBox(height: 6),
                _Box(height: 10, width: 130),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _Box(height: 13, width: 60),
        ],
      ),
    );
  }
}
