import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/responsive_wrapper.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_info.dart';
import '../l10n/app_localizations.dart';

class AboutDeveloperView extends StatelessWidget {
  const AboutDeveloperView({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(loc.aboutDeveloper),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.surface,
      ),
      body: ResponsiveCenter(child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2962FF),
              Color(0xFF1976D2),
              Color(0xFF0D47A1),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Header Section
                _buildHeader(context, loc),

                // Main Content
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 30),

                      // Developer Card
                      _buildDeveloperCard(context, loc),

                      const SizedBox(height: 20),

                      // Store Card
                      _buildStoreCard(context, loc),

                      const SizedBox(height: 20),

                      // Contact Card
                      _buildContactCard(context, loc),

                      const SizedBox(height: 20),

                      // App Info Card
                      _buildAppInfoCard(context, loc),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      )),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl, horizontal: AppSpacing.xl),
      child: Column(
        children: [
          // Logo/Icon
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(
                color: AppColors.surface.withAlpha(230),
                width: 5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withAlpha(77),
                  spreadRadius: 3,
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: AppColors.surface.withAlpha(26),
                  spreadRadius: -2,
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.surface.withAlpha(51),
                    child: const Icon(
                      Icons.business,
                      size: 70,
                      color: AppColors.surface,
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          Text(
            loc.hulucaStoreDongNai,
            style: AppTextStyles.headline1.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimary,
              letterSpacing: 1.5,
              shadows: const [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.md),

          Text(
            loc.aboutDeveloper,
            style: AppTextStyles.headline1.copyWith(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onPrimary,
              letterSpacing: 0.8,
              shadows: const [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.sm),

          Text(
            loc.professionalStoreManagementApp,
            style: AppTextStyles.headline3.copyWith(
              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.95),
              fontWeight: FontWeight.w400,
              shadows: const [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperCard(BuildContext context, AppLocalizations loc) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.lg),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.lg),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surfaceVariant,
            ],
          ),
        ),
        child: Column(
          children: [
            // Avatar
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primaryContainer,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.18),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.code,
                size: 40,
                color: AppColors.surface,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            Text(
              'Quang Huy',
              style: AppTextStyles.headline1.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            Text(
              loc.developerAndDesigner,
              style: AppTextStyles.headline3.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(AppSpacing.lg),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.18),
                ),
              ),
              child: Text(
                'HUY AKA',
                style: AppTextStyles.headline4.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreCard(BuildContext context, AppLocalizations loc) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.lg),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.lg),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surfaceVariant,
            ],
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFF6B35),
                    Color(0xFFF7931E),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B35).withAlpha(77),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.store,
                size: 40,
                color: AppColors.surface,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            Text(
              loc.hulucaStore,
              style: AppTextStyles.headline1.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: 1.5,
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            Text(
              loc.dongNai,
              style: AppTextStyles.headline2.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 2,
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            Text(
              loc.professionalPhoneRepairShop,
              style: AppTextStyles.headline4.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(BuildContext context, AppLocalizations loc) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.lg),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.lg),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surfaceVariant,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.phone,
                    color: Color(0xFF25D366),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Liên Hệ',
                        style: TextStyle(
                          fontSize: AppTextStyles.headline2.fontSize,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        loc.hotlineAndZalo,
                        style: TextStyle(
                          fontSize: AppTextStyles.headline4.fontSize,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppSpacing.lg),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '📱',
                    style: TextStyle(fontSize: AppTextStyles.headline1.fontSize),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '0964.09.59.79',
                      style: AppTextStyles.headline2.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _launchPhone('0964095979'),
                    icon: const Icon(
                      Icons.call,
                      color: Color(0xFF25D366),
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366).withAlpha(26),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppSpacing.lg),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '💬',
                    style: TextStyle(fontSize: AppTextStyles.headline1.fontSize),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Zalo: 0964.09.59.79',
                      style: AppTextStyles.headline3.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _launchZalo('0964095979'),
                    icon: const Icon(
                      Icons.message,
                      color: Color(0xFF0068FF),
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF0068FF).withAlpha(26),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppInfoCard(BuildContext context, AppLocalizations loc) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.lg),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.lg),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surfaceVariant,
            ],
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0068FF),
                    Color(0xFF0084FF),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0068FF).withAlpha(77),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.phone_android,
                size: 40,
                color: AppColors.surface,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            Text(
              loc.shopManagerApp,
              style: AppTextStyles.headline1.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            FutureBuilder<String>(
              future: AppInfo.getVersion(),
              builder: (context, snapshot) {
                final versionText = snapshot.data != null ? loc.versionLabel(snapshot.data!) : loc.versionLabel('...');
                return Text(
                  versionText,
                  style: AppTextStyles.headline4.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),

            const SizedBox(height: AppSpacing.lg),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withAlpha(26),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF4CAF50).withAlpha(51),
                ),
              ),
              child: Text(
                '',
                style: TextStyle(
                  color: const Color(0xFF4CAF50),
                  fontWeight: FontWeight.w600,
                  fontSize: AppTextStyles.headline4.fontSize,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            Text(
              loc.appFullDescription,
              style: AppTextStyles.headline4.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchPhone(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  Future<void> _launchZalo(String phoneNumber) async {
    final Uri zaloUri = Uri.parse('https://zalo.me/$phoneNumber');
    if (await canLaunchUrl(zaloUri)) {
      await launchUrl(zaloUri);
    }
  }
}
