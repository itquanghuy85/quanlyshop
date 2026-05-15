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
**iOS Premium Palette** (updated 2026-05-15)

| Token | Value | Usage |
|---|---|---|
| `AppColors.primary` | `#007AFF` | iOS System Blue |
| `AppColors.primaryDark` | `#0056D6` | Gradient end, selected state |
| `AppColors.background` | `#F5F7FB` | App background |
| `AppColors.surface` | `#FFFFFF` | Cards, sheets |
| `AppColors.textPrimary` | `#1F2937` | Headings, body text |
| `AppColors.textSecondary` | `#6B7280` | Labels, captions |
| `AppColors.success` | `#34A853` | Positive, completed |
| `AppColors.warning` | `#E6A700` | Caution, pending |
| `AppColors.error` | `#EF4444` | Errors, cancelled |
| `AppColors.info` | `#3B82F6` | Informational, links |
| `AppColors.divider` | `#EEF2F7` | Separators |
| `AppColors.outline` | `#E5EAF2` | Card borders |
| `AppColors.grey400` | `#9CA3AF` | Icons, placeholders |
| `AppColors.grey800` | `#1F2937` | Dark text |

Grey scale: Tailwind Gray (warmer than previous Tailwind Slate)

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
