import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/responsive_wrapper.dart';
import '../data/help_center_repository.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_spacing.dart';
import '../services/notification_service.dart';

class HelpCenterView extends StatefulWidget {
  final String userRole;
  const HelpCenterView({super.key, required this.userRole});

  @override
  State<HelpCenterView> createState() => _HelpCenterViewState();
}

class _HelpCenterViewState extends State<HelpCenterView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _activeCategoryId = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<HelpTopic> _computeTopics() {
    final query = _searchCtrl.text.trim();
    final role = widget.userRole.isEmpty ? 'all' : widget.userRole;

    if (query.isNotEmpty) {
      return HelpCenterRepository.searchTopics(query, audience: role);
    }

    if (_activeCategoryId == 'all') {
      final filtered = HelpCenterRepository.topics.where((topic) {
        return _matchesAudience(topic.audience, role);
      }).toList();
      filtered.sort((a, b) => (b.isFeatured ? 1 : 0) - (a.isFeatured ? 1 : 0));
      return filtered;
    }

    return HelpCenterRepository.topicsByCategory(_activeCategoryId, audience: role);
  }

  List<HelpTopic> _topicsForCategory(String categoryId) {
    final role = widget.userRole.isEmpty ? 'all' : widget.userRole;
    return HelpCenterRepository.topicsByCategory(categoryId, audience: role);
  }

  bool _matchesAudience(List<String> audience, String role) {
    if (role == 'all' || audience.contains('all')) {
      return true;
    }
    return audience.contains(role);
  }

  String _localizeRole(String role) {
    switch (role) {
      case 'owner':
        return 'Chủ shop';
      case 'manager':
        return 'Quản lý';
      case 'technician':
        return 'Kỹ thuật';
      case 'cashier':
        return 'Thu ngân';
      case 'admin':
        return 'Admin';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = HelpCenterRepository.categories;
    final role = widget.userRole.isEmpty ? 'all' : widget.userRole;
    final topics = _computeTopics();
    final featured = HelpCenterRepository.featuredTopics(audience: role);

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0068FF), Color(0xFF0084FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'Trung tâm hướng dẫn',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.surface,
          ),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ResponsiveCenter(child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Tìm kiếm theo từ khóa, tính năng... ',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.outline),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _categoryChip(
                        id: 'all',
                        label: 'Gợi ý',
                        icon: Icons.lightbulb_outline,
                        isActive: _activeCategoryId == 'all',
                      ),
                      for (final category in categories)
                        _categoryChip(
                          id: category.id,
                          label: category.title,
                          icon: category.icon,
                          isActive: _activeCategoryId == category.id,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_searchCtrl.text.isEmpty)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _buildQuickSummary(context),
                  ),
                if (_searchCtrl.text.isEmpty) ...[
                  const SizedBox(height: 12),
                  _buildQuickActions(role),
                ],
                if (_searchCtrl.text.isEmpty && featured.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildFeaturedSection(featured),
                ],
              ],
            ),
          ),
          Expanded(
            child: _buildContentList(categories, topics),
          ),
        ],
      )),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          NotificationService.showSnackBar(
            'Góp ý tính năng mới? Liên hệ support@huluca.com',
            color: AppColors.primary,
          );
        },
        icon: const Icon(Icons.support_agent),
        label: const Text('Góp ý / Hỗ trợ'),
      ),
    );
  }

  Widget _buildContentList(List<HelpCategory> categories, List<HelpTopic> topics) {
    if (_searchCtrl.text.isNotEmpty) {
      if (topics.isEmpty) {
        return _emptyState('Không tìm thấy hướng dẫn nào khớp từ khóa.');
      }
      return ListView.builder(
        itemCount: topics.length + 1,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemBuilder: (context, index) {
          if (index == topics.length) {
            return _supportCard();
          }
          final topic = topics[index];
          final category = HelpCenterRepository.findCategory(topic.categoryId);
          return _topicCard(topic, category?.title ?? 'Chủ đề khác');
        },
      );
    }

    // No search → show topics grouped by category
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (_activeCategoryId == 'all')
          for (final category in categories)
            _categorySection(category)
        else
          _categorySection(
            categories.firstWhere((c) => c.id == _activeCategoryId,
                orElse: () => categories.first),
          ),
        const SizedBox(height: 12),
        _supportCard(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _categorySection(HelpCategory category) {
    final topics = _topicsForCategory(category.id);
    if (topics.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.lg)),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(category.icon, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.title,
                        style: AppTextStyles.subtitle1.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category.description,
                        style: AppTextStyles.caption.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final topic in topics) _topicCard(topic, null),
          ],
        ),
      ),
    );
  }

  Widget _topicCard(HelpTopic topic, String? categoryName) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.lg)),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        onTap: () => _openTopicDetail(topic),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (categoryName != null) ...[
                Text(
                  categoryName,
                  style: AppTextStyles.overline.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                topic.title,
                style: AppTextStyles.subtitle1.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                topic.summary,
                style: AppTextStyles.body2.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _infoChip(Icons.list_alt, '${topic.steps.length} bước'),
                  if (topic.estimatedTime != null)
                    _infoChip(Icons.timer_outlined, topic.estimatedTime!),
                  _infoChip(Icons.insights, topic.difficulty),
                  if (topic.tips.isNotEmpty)
                    _infoChip(Icons.lightbulb, '${topic.tips.length} mẹo'),
                  for (final tag in topic.tags.take(3))
                    Chip(
                      label: Text('#$tag'),
                      backgroundColor: AppColors.outline,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
      label: Text(label, style: AppTextStyles.caption),
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildQuickSummary(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hướng dẫn nhanh',
            style: AppTextStyles.subtitle1.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Chọn chủ đề phù hợp hoặc nhập từ khóa để xem hướng dẫn chi tiết từng bước, có hình ảnh và video (nếu có).',
            style: AppTextStyles.body2.copyWith(
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.verified_user, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Mọi nội dung được biên soạn theo quy trình chuẩn của Shopmanager.',
                  style: AppTextStyles.caption.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.support, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle2.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip({
    required String id,
    required String label,
    required IconData icon,
    required bool isActive,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isActive ? AppColors.surface : AppColors.primary),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
        selected: isActive,
        onSelected: (_) => setState(() {
          _activeCategoryId = id;
          _searchCtrl.clear();
        }),
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isActive ? AppColors.surface : AppColors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _openTopicDetail(HelpTopic topic) {
    final role = widget.userRole.isEmpty ? 'all' : widget.userRole;
    showAppBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final category = HelpCenterRepository.findCategory(topic.categoryId);
        final related = HelpCenterRepository.relatedTopics(topic, audience: role);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.outline,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (category != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(category.icon, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              category.title,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (!topic.audience.contains('all'))
                          Chip(
                            avatar: const Icon(Icons.workspace_premium, size: 16),
                            label: Text(
                              'Dành cho ${topic.audience.map(_localizeRole).join(', ')}',
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Text(
                    topic.title,
                    style: AppTextStyles.headline4.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    topic.summary,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  if (topic.estimatedTime != null || topic.difficulty.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.speed, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (topic.estimatedTime != null)
                                  Text(
                                    'Thời gian thực hiện: ${topic.estimatedTime}',
                                    style: AppTextStyles.subtitle2.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                Text(
                                  'Độ khó: ${topic.difficulty}',
                                  style: TextStyle(color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (topic.prerequisites.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Chuẩn bị trước',
                      style: AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    for (final item in topic.prerequisites)
                      ListTile(
                        leading: const Icon(Icons.check_circle_outline, color: AppColors.info),
                        title: Text(item),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                  ],
                  Text(
                    'Các bước thực hiện',
                    style: AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < topic.steps.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.primary,
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(color: AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              topic.steps[i],
                              style: TextStyle(fontSize: AppTextStyles.body1.fontSize),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (topic.tips.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Mẹo & ghi chú',
                      style: AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    for (final tip in topic.tips)
                      ListTile(
                        leading: const Icon(Icons.check_circle, color: AppColors.success),
                        title: Text(tip),
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                  if (topic.videoUrl != null) ...[
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => NotificationService.showSnackBar(
                        'Mở video hướng dẫn: ${topic.videoUrl}',
                        color: AppColors.primary,
                      ),
                      icon: const Icon(Icons.play_circle_fill),
                      label: const Text('Xem video minh họa'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: AppColors.surface,
                      ),
                    ),
                  ],
                  if (topic.resources.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Tài liệu đính kèm',
                      style: AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      color: AppColors.background,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          for (final resource in topic.resources)
                            ListTile(
                              leading: const Icon(Icons.file_present_outlined, color: AppColors.textSecondary),
                              title: Text(resource),
                              trailing: const Icon(Icons.open_in_new, size: 18),
                              onTap: () => NotificationService.showSnackBar(
                                'Mở tài liệu: $resource',
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (related.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Liên quan',
                      style: AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final item in related)
                          ActionChip(
                            label: Text(item.title),
                            onPressed: () {
                              Navigator.of(context).pop();
                              Future.delayed(
                                const Duration(milliseconds: 150),
                                () => _openTopicDetail(item),
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Khó khăn? Liên hệ team hỗ trợ: support@huluca.com',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => NotificationService.showSnackBar(
                        'Đã đánh dấu hướng dẫn này là đã xem.',
                        color: AppColors.success,
                      ),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Tôi đã hiểu hướng dẫn này'),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickActions(String role) {
    final chips = [
      ActionChip(
        avatar: const Icon(Icons.play_circle_outline, size: 18, color: AppColors.repairDelivered),
        label: const Text('Video hướng dẫn'),
        onPressed: () {
          NotificationService.showSnackBar(
            'Các video hướng dẫn đang được cập nhật.',
            color: AppColors.repairDelivered,
          );
        },
      ),
      ActionChip(
        avatar: const Icon(Icons.support_agent, size: 18, color: AppColors.primary),
        label: const Text('Liên hệ hỗ trợ'),
        onPressed: () {
          NotificationService.showSnackBar(
            'Gửi email đến support@huluca.com để được trợ giúp nhanh.',
            color: AppColors.primary,
          );
        },
      ),
      ActionChip(
        avatar: const Icon(Icons.feedback_outlined, size: 18, color: AppColors.warning),
        label: const Text('Đề xuất cải tiến'),
        onPressed: () {
          NotificationService.showSnackBar(
            'Góp ý của bạn sẽ giúp tài liệu đầy đủ hơn!',
            color: AppColors.warning,
          );
        },
      ),
    ];

    if (role != 'all') {
      chips.add(
        ActionChip(
          avatar: const Icon(Icons.workspace_premium_outlined, size: 18, color: AppColors.success),
          label: Text('Dành cho ${_localizeRole(role)}'),
          onPressed: () {
            setState(() => _activeCategoryId = 'all');
            NotificationService.showSnackBar(
              'Đã lọc các hướng dẫn phù hợp với vai trò của bạn.',
              color: AppColors.success,
            );
          },
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: chips,
    );
  }

  Widget _buildFeaturedSection(List<HelpTopic> featured) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star_rounded, color: AppColors.warning),
            const SizedBox(width: 8),
            Text(
              'Nổi bật',
              style: AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: featured.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final topic = featured[index];
              final category = HelpCenterRepository.findCategory(topic.categoryId);
              return GestureDetector(
                onTap: () => _openTopicDetail(topic),
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary,
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            category?.icon ?? Icons.menu_book,
                            color: AppColors.surface,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              topic.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.surface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        topic.summary,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.timer, size: 16, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(
                            topic.estimatedTime ?? 'Nhanh',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const Spacer(),
                          const Icon(Icons.chevron_right, color: Colors.white70),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _supportCard() {
    return Card(
      elevation: 0,
      color: AppColors.textSecondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.headset_mic, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'Cần thêm trợ giúp?',
                  style: AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Đội ngũ Huluca sẵn sàng hỗ trợ qua email, Zalo hoặc hướng dẫn trực tiếp.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: () => NotificationService.showSnackBar(
                    'Đã sao chép email support@huluca.com',
                    color: AppColors.textSecondary,
                  ),
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Email support@huluca.com'),
                ),
                OutlinedButton.icon(
                  onPressed: () => NotificationService.showSnackBar(
                    'Liên hệ Zalo CSKH: 0901 234 567',
                    color: AppColors.textSecondary,
                  ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Zalo CSKH'),
                ),
                OutlinedButton.icon(
                  onPressed: () => NotificationService.showSnackBar(
                    'Đặt lịch training online trong tuần này.',
                    color: AppColors.textSecondary,
                  ),
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: const Text('Đặt lịch training'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
