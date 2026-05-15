# Design Tokens Reference

## Typography (`lib/theme/app_typography.dart`)
- Display Large: 34 / W700 / 1.2
- Headline Large: 28 / W700 / 1.25
- Headline Medium: 24 / W700 / 1.25
- Headline Small: 20 / W600 / 1.3
- Title Large: 22 / W600 / 1.3
- Title Medium: 18 / W600 / 1.35
- Title Small: 16 / W600 / 1.35
- Body Large: 16 / W400 / 1.5
- Body Medium: 14 / W400 / 1.45
- Body Small: 12 / W400 / 1.4
- Label Large: 14 / W500 / 1.3
- Label Medium: 12 / W500 / 1.3
- Label Small: 11 / W500 / 1.25
- Caption: 10 / W400 / 1.3

## Spacing (`lib/theme/app_spacing.dart`)
- xs = 4
- sm = 8
- md = 12
- lg = 16
- xl = 24
- xxl = 32

Helper:
- Padding: `pXs`, `pSm`, `pMd`, `pLg`, `pXl`
- Horizontal: `phSm`, `phMd`, `phLg`, `phXl`
- Vertical: `pvXs`, `pvSm`, `pvMd`, `pvLg`
- Gaps: `gapXs`, `gapSm`, `gapMd`, `gapLg`, `gapXl`, `gapXxl`

## Colors (`lib/theme/app_colors.dart`)
**Original Legacy Palette** (restored 2026-05-15 from commit `3d6b3109`)

| Token | Value | Usage |
|---|---|---|
| `AppColors.primary` | `#4D8EE9` | Soft blue — chips, buttons, links |
| `AppColors.primaryDark` | `#0068FF` | Zalo Blue — AppBar, gradient |
| `AppColors.background` | `#F8FAFF` | Blue-tinted app background |
| `AppColors.surface` | `#FFFFFF` | Cards, sheets |
| `AppColors.textPrimary` | `#1C1B1F` | Near-black |
| `AppColors.textSecondary` | `#616161` | Grey 700 |
| `AppColors.success` | `#388E3C` | Green 700 |
| `AppColors.warning` | `#F57C00` | Orange 700 |
| `AppColors.error` | `#D32F2F` | Red 700 |
| `AppColors.info` | `#0068FF` | Zalo Blue |
| `AppColors.divider` | `#E0E0E0` | Grey 300 |
| `AppColors.outline` | `#E0E0E0` | Grey 300 |
| `AppColors.grey400` | `#BDBDBD` | Material Grey 400 |
| `AppColors.grey800` | `#424242` | Material Grey 800 |

Grey scale: Material Design Grey (not Tailwind)
AppBar gradient: `#0068FF → #0084FF` (Zalo Blue)

## Core Tokens (`lib/theme/design_tokens.dart`)
- Minimum touch target: 44
- Radius: 8 / 12 / 16
- Icon size: 16 / 20 / 24
- Icon-text gap: 8
- Motion: 150ms / 220ms

## Component Integration
- Theme: `lib/theme/app_theme.dart`
- Buttons: `lib/theme/app_button_styles.dart`
- Legacy typography compatibility: `lib/theme/app_text_styles.dart`
