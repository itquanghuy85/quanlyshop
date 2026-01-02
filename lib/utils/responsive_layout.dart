import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1200;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1200;

  static double getScreenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double getScreenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static double getResponsiveFontSize(BuildContext context, double baseSize) {
    final screenWidth = getScreenWidth(context);
    if (screenWidth < 360) return baseSize * 0.8; // Small phones
    if (screenWidth < 600) return baseSize * 0.9; // Normal phones
    if (screenWidth < 900) return baseSize; // Tablets
    return baseSize * 1.1; // Desktop
  }

  static EdgeInsets getResponsivePadding(BuildContext context) {
    final screenWidth = getScreenWidth(context);
    if (screenWidth < 360) return const EdgeInsets.all(8);
    if (screenWidth < 600) return const EdgeInsets.all(16);
    if (screenWidth < 900) return const EdgeInsets.all(24);
    return const EdgeInsets.all(32);
  }

  static double getResponsiveSpacing(BuildContext context) {
    final screenWidth = getScreenWidth(context);
    if (screenWidth < 360) return 8;
    if (screenWidth < 600) return 16;
    if (screenWidth < 900) return 24;
    return 32;
  }

  static int getResponsiveGridColumns(BuildContext context) {
    final screenWidth = getScreenWidth(context);
    if (screenWidth < 600) return 2;
    if (screenWidth < 900) return 3;
    if (screenWidth < 1200) return 4;
    return 6;
  }

  static double getResponsiveCardWidth(BuildContext context) {
    final screenWidth = getScreenWidth(context);
    final padding = getResponsivePadding(context);
    final availableWidth = screenWidth - padding.left - padding.right;

    if (screenWidth < 600) return availableWidth;
    if (screenWidth < 900) return (availableWidth - 16) / 2;
    if (screenWidth < 1200) return (availableWidth - 32) / 3;
    return (availableWidth - 64) / 4;
  }

  @override
  Widget build(BuildContext context) {
    if (isDesktop(context) && desktop != null) {
      return desktop!;
    } else if (isTablet(context) && tablet != null) {
      return tablet!;
    } else {
      return mobile;
    }
  }
}

class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, BoxConstraints constraints)
  builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => builder(context, constraints),
    );
  }
}

class AdaptiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const AdaptiveText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? const TextStyle();
    final responsiveFontSize = ResponsiveLayout.getResponsiveFontSize(
      context,
      baseStyle.fontSize ?? 14,
    );

    return Text(
      text,
      style: baseStyle.copyWith(fontSize: responsiveFontSize),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  // Static methods for testing
  static bool isMobileFromQuery(MediaQueryData query) => query.size.width < 600;

  static bool isTabletFromQuery(MediaQueryData query) =>
      query.size.width >= 600 && query.size.width < 1200;

  static bool isDesktopFromQuery(MediaQueryData query) =>
      query.size.width >= 1200;

  static double getResponsiveFontSizeFromQuery(
    MediaQueryData query,
    double baseSize,
  ) {
    final screenWidth = query.size.width;
    if (screenWidth < 360) return baseSize * 0.8; // Small phones
    if (screenWidth < 600) return baseSize * 0.9; // Normal phones
    if (screenWidth < 900) return baseSize; // Tablets
    return baseSize * 1.1; // Desktop
  }

  static int getResponsiveGridColumnsFromQuery(MediaQueryData query) {
    final screenWidth = query.size.width;
    if (screenWidth < 600) return 2; // Mobile: 2 columns
    if (screenWidth < 900) return 3; // Tablet: 3 columns
    return 4; // Desktop: 4 columns
  }
}

class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? maxWidth;
  final Alignment? alignment;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.maxWidth,
    this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final responsivePadding =
        padding ?? ResponsiveLayout.getResponsivePadding(context);
    final responsiveMargin = margin ?? EdgeInsets.zero;

    Widget content = Container(
      padding: responsivePadding,
      margin: responsiveMargin,
      alignment: alignment,
      constraints: maxWidth != null
          ? BoxConstraints(maxWidth: maxWidth!)
          : null,
      child: child,
    );

    // Center content on larger screens
    if (ResponsiveLayout.isDesktop(context) ||
        ResponsiveLayout.isTablet(context)) {
      content = Center(child: content);
    }

    return content;
  }
}

class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveLayout.getResponsiveGridColumns(context);

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: children.map((child) {
        final width = ResponsiveLayout.getResponsiveCardWidth(context);
        return SizedBox(width: width, child: child);
      }).toList(),
    );
  }
}

class ResponsiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final double? elevation;

  const ResponsiveAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.elevation,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = ResponsiveLayout.isMobile(context);

    return AppBar(
      title: AdaptiveText(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      actions: actions,
      leading: leading,
      centerTitle: centerTitle,
      elevation: elevation ?? (isSmallScreen ? 2 : 4),
      toolbarHeight: isSmallScreen ? kToolbarHeight : kToolbarHeight + 8,
    );
  }
}

class ResponsiveBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavigationBarItem> items;

  const ResponsiveBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = ResponsiveLayout.isMobile(context);

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: items,
      type: BottomNavigationBarType.fixed,
      showSelectedLabels: isSmallScreen,
      showUnselectedLabels: isSmallScreen,
      selectedFontSize: isSmallScreen ? 12 : 14,
      unselectedFontSize: isSmallScreen ? 10 : 12,
      iconSize: isSmallScreen ? 24 : 28,
      elevation: 8,
    );
  }
}
