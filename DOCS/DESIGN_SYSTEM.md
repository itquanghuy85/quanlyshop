# Design System - HULUCA Shop Manager

Design tokens, colors, typography, spacing, components, styling guidelines.

---

## Color Palette

### Primary Colors
| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| Primary Blue | `#1976D2` | RGB(25, 118, 210) | Buttons, links, highlights |
| Dark Blue | `#1565C0` | RGB(21, 101, 192) | Button hover, selected state |
| Light Blue | `#E3F2FD` | RGB(227, 242, 253) | Background, disabled state |

### Semantic Colors
| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| Success Green | `#4CAF50` | RGB(76, 175, 80) | Success messages, completed status |
| Warning Orange | `#FF9800` | RGB(255, 152, 0) | Warning alerts, in-progress status |
| Error Red | `#F44336` | RGB(244, 67, 54) | Error messages, failed status |
| Info Cyan | `#00BCD4` | RGB(0, 188, 212) | Information, pending status |

### Neutral Colors
| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| White | `#FFFFFF` | RGB(255, 255, 255) | Backgrounds, cards, text areas |
| Light Gray | `#F5F5F5` | RGB(245, 245, 245) | Hover states, dividers |
| Medium Gray | `#E0E0E0` | RGB(224, 224, 224) | Borders, disabled elements |
| Dark Gray | `#757575` | RGB(117, 117, 117) | Secondary text |
| Black | `#212121` | RGB(33, 33, 33) | Primary text, headings |

### Status Colors
| Status | Color | Hex | Usage |
|--------|-------|-----|-------|
| Pending | Info Cyan | `#00BCD4` | Repair pending |
| In Progress | Warning Orange | `#FF9800` | Repair in progress |
| Done | Success Green | `#4CAF50` | Repair completed |
| Cancelled | Error Red | `#F44336` | Repair cancelled |

---

## Typography

### Font Family
- **Primary:** `Roboto` (Google Fonts)
- **Monospace:** `Courier New` (for code/data)

### Font Sizes & Weights

| Role | Size | Weight | Line Height | Usage |
|------|------|--------|-------------|-------|
| **Heading 1** | 32px | Bold (700) | 40px | Page titles |
| **Heading 2** | 28px | Bold (700) | 36px | Section titles |
| **Heading 3** | 24px | SemiBold (600) | 32px | Subsection titles |
| **Heading 4** | 20px | SemiBold (600) | 28px | Card titles |
| **Body Large** | 16px | Regular (400) | 24px | Main text content |
| **Body Normal** | 14px | Regular (400) | 20px | Description text |
| **Body Small** | 12px | Regular (400) | 16px | Labels, captions |
| **Label** | 12px | Medium (500) | 16px | Form labels |
| **Button** | 14px | Medium (500) | 20px | Button text |

### Text Colors
- Primary text (headings, body): `#212121` (Black)
- Secondary text (hints, descriptions): `#757575` (Dark Gray)
- Disabled text: `#BDBDBD` (Light Gray)
- Links: `#1976D2` (Primary Blue)

---

## Spacing System

All spacing based on 8px base unit.

| Level | Value | Multiplier | Usage |
|-------|-------|-----------|-------|
| **XS** | 4px | 0.5x | Minimal spacing |
| **S** | 8px | 1x | Tight spacing |
| **M** | 16px | 2x | Standard spacing |
| **L** | 24px | 3x | Comfortable spacing |
| **XL** | 32px | 4x | Generous spacing |
| **XXL** | 48px | 6x | Large sections |

### Usage Examples
```dart
// Padding
padding: EdgeInsets.all(16),     // M (standard)
padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), // M/S

// Margins
SizedBox(height: 16),            // M (between sections)
SizedBox(width: 8),              // S (between inline items)

// Border radius
borderRadius: BorderRadius.circular(8), // M
borderRadius: BorderRadius.circular(4), // S for small elements
```

---

## Component Specifications

### Buttons

#### Primary Button
```
Size: 48px height
Padding: 16px horizontal, 12px vertical
Background: Primary Blue (#1976D2)
Text: Button (14px, Medium, White)
Border Radius: 4px
Hover: Dark Blue (#1565C0)
Disabled: Light Gray (#E0E0E0), text #BDBDBD
```

#### Secondary Button
```
Size: 48px height
Background: White
Border: 2px Primary Blue
Text: Button (14px, Medium, Primary Blue)
Hover: Light Blue background (#E3F2FD)
```

#### Outline Button
```
Similar to Secondary but thinner border (1px)
```

### Cards
```
Background: White (#FFFFFF)
Border: 1px Light Gray (#E0E0E0)
Border Radius: 8px
Padding: 16px (M)
Shadow: elevation 2 (iOS) or elevation 2 (Android)
Hover: Shadow elevation 4
```

### Input Fields
```
Height: 48px
Padding: 12px
Border: 1px Medium Gray (#E0E0E0)
Border Radius: 4px
Font: Body Normal (14px)
Hint Color: Dark Gray (#757575)
Focused: Border 2px Primary Blue
Error: Border 2px Error Red
```

### Dialogs & Modals
```
Width: 90% of screen (max 600px on tablet)
Border Radius: 8px
Padding: 24px (L)
Shadow: elevation 8
Backdrop: Black with 50% opacity
```

### Chips & Tags
```
Height: 32px
Padding: 8px horizontal
Border Radius: 16px
Background: Light Gray (#F5F5F5)
Text: Body Small (12px)
```

---

## Layout Grid

### Desktop (Web)
```
Grid: 12-column
Gutter: 16px (M)
Container width: 1200px max
Margin: 24px (L) on sides
```

### Tablet
```
Grid: 8-column
Gutter: 16px (M)
Container width: 100% - 48px (XXL margin total)
```

### Mobile
```
Grid: 4-column (or single column)
Gutter: 8px (S)
Container width: 100% - 32px (M margin total)
Padding: 16px (M) per side
```

---

## Elevation / Shadow System

| Level | Usage | Shadow |
|-------|-------|--------|
| **0** | Flat, no elevation | None |
| **1** | Hover states, subtle depth | Light shadow |
| **2** | Cards, containers | Standard shadow |
| **4** | Floating action buttons, hovering cards | Medium shadow |
| **8** | Dialogs, modals, dropdowns | Deep shadow |
| **16** | Full-screen overlays, critical dialogs | Very deep shadow |

---

## Dark Mode (If Applicable)

**Status:** Not currently implemented  
**Planned:** Future release

### When Implemented
- Primary: `#121212`
- Surface: `#1E1E1E`
- Secondary text: `#E0E0E0`
- Accent: Same (Primary Blue)

---

## Animations & Transitions

### Duration
- **Quick:** 150ms (state changes, hover)
- **Standard:** 300ms (screen transitions, modal open)
- **Slow:** 500ms (complex animations)

### Easing
- **Standard:** `Curves.easeInOut` (default)
- **Entrance:** `Curves.easeOut` (fade in, slide in)
- **Exit:** `Curves.easeIn` (fade out, slide out)

### Examples
```dart
// Quick transition
AnimatedContainer(
  duration: Duration(milliseconds: 150),
  curve: Curves.easeInOut,
  color: isSelected ? Colors.blue : Colors.gray,
)

// Page transition
PageRouteBuilder(
  transitionDuration: Duration(milliseconds: 300),
  pageBuilder: (context, animation, secondaryAnimation) => NewPage(),
  transitionsBuilder: (context, animation, secondaryAnimation, child) =>
    FadeTransition(opacity: animation, child: child),
)
```

---

## Accessibility (A11y)

### Text Contrast
- Minimum ratio: 4.5:1 (normal text)
- Minimum ratio: 3:1 (large text)

### Touch Targets
- Minimum size: 48px × 48px
- Spacing between targets: 8px min

### Color Accessibility
- Don't rely on color alone (use text labels)
- Icons should have text alternatives
- Red/Green color blind safe palette

---

## Component Library

### Common Components (Already Implemented)
- ✓ AppBar (custom)
- ✓ NavigationBar (bottom navigation)
- ✓ DrawerMenu (left sidebar)
- ✓ Button (primary, secondary, outlined)
- ✓ TextField (text input)
- ✓ Card (container)
- ✓ Dialog (modal)
- ✓ SnackBar (notification)
- ✓ FloatingActionButton (FAB)

### Planned Components
- ⏳ DatePicker (custom)
- ⏳ TimePicker (custom)
- ⏳ Dropdown (custom)
- ⏳ DataTable (custom)
- ⏳ Chart widgets

---

## References

- **Material Design 3:** https://m3.material.io/
- **Flutter Material Design:** https://flutter.dev/docs/development/ui/widgets/material
- **Design Tokens:** See `DESIGN_TOKENS_REFERENCE.md`

---

**Last Updated:** 2026-05-15  
**Version:** 1.0
