# Design Tokens Reference - HULUCA Shop Manager

Quick reference bảng cho tất cả design tokens: colors, typography, spacing, etc.

---

## Color Tokens

### Primary
```
Primary Blue:       #1976D2 (RGB: 25, 118, 210)
Dark Blue:          #1565C0 (RGB: 21, 101, 192)
Light Blue:         #E3F2FD (RGB: 227, 242, 253)
```

### Semantic
```
Success:            #4CAF50 (RGB: 76, 175, 80)
Warning:            #FF9800 (RGB: 255, 152, 0)
Error:              #F44336 (RGB: 244, 67, 54)
Info:               #00BCD4 (RGB: 0, 188, 212)
```

### Neutral
```
White:              #FFFFFF
Light Gray:         #F5F5F5
Medium Gray:        #E0E0E0
Dark Gray:          #757575
Black:              #212121
```

---

## Typography Tokens

### Sizes (px)
```
H1: 32px  (Bold 700)
H2: 28px  (Bold 700)
H3: 24px  (SemiBold 600)
H4: 20px  (SemiBold 600)
Body Large: 16px (Regular 400)
Body Normal: 14px (Regular 400)
Body Small: 12px (Regular 400)
Label: 12px (Medium 500)
Button: 14px (Medium 500)
```

### Font Family
```
Primary: Roboto
Monospace: Courier New
```

---

## Spacing Tokens (px)

```
XS: 4px
S:  8px
M:  16px
L:  24px
XL: 32px
XXL: 48px
```

---

## Border Radius Tokens (px)

```
Small:   4px
Medium:  8px
Large:   12px
Round:   16px (chips, badges)
Circle:  50% (avatars)
```

---

## Elevation Tokens

```
Level 0: None
Level 1: Light shadow
Level 2: Standard shadow (cards)
Level 4: Medium shadow (FAB, hover)
Level 8: Deep shadow (dialogs)
Level 16: Very deep shadow (full-screen overlays)
```

---

## Duration Tokens (ms)

```
Quick:     150ms
Standard:  300ms
Slow:      500ms
```

---

## In-Code Usage

### Dart Constant Definition
```dart
// lib/config/design_tokens.dart

class AppColors {
  // Primary
  static const Color primary = Color(0xFF1976D2);
  static const Color primaryDark = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFFE3F2FD);
  
  // Semantic
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF00BCD4);
  
  // Neutral
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGray = Color(0xFFF5F5F5);
  static const Color mediumGray = Color(0xFFE0E0E0);
  static const Color darkGray = Color(0xFF757575);
  static const Color black = Color(0xFF212121);
}

class AppTypography {
  static const TextStyle h1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
  );
  static const TextStyle h2 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
  );
  // ... more styles
}

class AppSpacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 32;
  static const double xxl = 48;
}
```

### Usage in Widgets
```dart
Container(
  color: AppColors.primary,
  padding: EdgeInsets.all(AppSpacing.m),
  child: Text(
    'Hello World',
    style: AppTypography.h1.copyWith(color: AppColors.white),
  ),
)
```

---

## Status Colors Mapping

| Status | Color | Hex |
|--------|-------|-----|
| Pending (1) | Info Cyan | #00BCD4 |
| In Progress (2) | Warning Orange | #FF9800 |
| Done (3) | Success Green | #4CAF50 |
| Cancelled (4) | Error Red | #F44336 |

---

## Accessibility

### Contrast Ratios (WCAG AA)
```
✓ Black on White:        #212121 on #FFFFFF = 17:1
✓ Dark Gray on White:    #757575 on #FFFFFF = 4.56:1 ✓
✓ Primary Blue on White: #1976D2 on #FFFFFF = 3.13:1 (borderline)
✓ Error Red on White:    #F44336 on #FFFFFF = 3.93:1 ✓
✓ Success Green on White: #4CAF50 on #FFFFFF = 4.54:1 ✓
```

---

## Quick Copy-Paste

### Hex Colors (CSS/JSON)
```
#1976D2 #1565C0 #E3F2FD
#4CAF50 #FF9800 #F44336 #00BCD4
#FFFFFF #F5F5F5 #E0E0E0 #757575 #212121
```

### RGB Colors (Android)
```
rgb(25, 118, 210)   - Primary Blue
rgb(21, 101, 192)   - Dark Blue
rgb(227, 242, 253)  - Light Blue
```

---

**Last Updated:** 2026-05-15  
**Version:** 1.0
