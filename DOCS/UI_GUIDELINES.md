# UI Guidelines - HULUCA Shop Manager

Hướng dẫn thiết kế UI, layout patterns, color usage, interaction patterns, best practices.

---

## Layout Principles

### Mobile-First Approach
1. Design for mobile (320px - 480px)
2. Adapt for tablet (600px - 1024px)
3. Adapt for desktop (1024px+)

### Responsive Breakpoints
```
Mobile:  0px - 599px
Tablet:  600px - 1023px
Desktop: 1024px+
```

### Safe Areas
- **Mobile:** 16px margin on sides, 8px top/bottom
- **Tablet:** 24px margin, consider notch
- **Desktop:** 32px margin, max content width 1200px

---

## Navigation Patterns

### Bottom Navigation (Mobile)
- Used for primary navigation (max 5 items)
- Icons + labels
- Current item highlighted in Primary Blue
- Height: 56px

### Top AppBar
- Contains: Back button, title, action buttons
- Height: 56px
- Shadow: elevation 2
- Safe area: include notch/status bar

### Drawer Menu (Optional)
- Slide from left
- Width: min 256px, max 320px
- Safe area: include notch
- Close on selection or swipe out

---

## Screen Layout Patterns

### List Screen
```
┌─────────────────────────────┐
│  [Back] Title       [Search]│  ← AppBar
├─────────────────────────────┤
│ [Filters] [Sort]            │  ← Optional toolbar
├─────────────────────────────┤
│  • Item 1                   │
│  • Item 2                   │
│  • Item 3                   │  ← Main content (scrollable)
│  • Item 4                   │
│  • Item 5                   │
├─────────────────────────────┤
│ [Home] [Menu] [Repairs]     │  ← Bottom nav
└─────────────────────────────┘
```

### Detail Screen
```
┌─────────────────────────────┐
│  [Back] Repair #123 [Edit]  │  ← AppBar
├─────────────────────────────┤
│  Status: In Progress        │
│  Customer: John             │  ← Content sections
│  Phone: 0912...             │
│  Estimated: 500,000₫        │
├─────────────────────────────┤
│  [Cancel] [Save]            │  ← Action buttons
├─────────────────────────────┤
│ [Home] [Menu] [Repairs]     │  ← Bottom nav
└─────────────────────────────┘
```

### Form Screen
```
┌─────────────────────────────┐
│  [Back] Create Repair       │  ← AppBar
├─────────────────────────────┤
│  Customer Name              │
│  ┌───────────────────────┐  │
│  │ [text input]          │  │  ← Form fields
│  └───────────────────────┘  │
│                             │
│  Phone Number               │
│  ┌───────────────────────┐  │
│  │ 0912...               │  │
│  └───────────────────────┘  │
│                             │
│  Description                │
│  ┌───────────────────────┐  │
│  │ [multi-line text]     │  │
│  │                       │  │
│  └───────────────────────┘  │
├─────────────────────────────┤
│       [Cancel] [Submit]     │  ← Actions
├─────────────────────────────┤
│ [Home] [Menu] [Repairs]     │  ← Bottom nav
└─────────────────────────────┘
```

---

## Color Usage Guidelines

### Text
- **Primary (Body):** Black (#212121)
- **Secondary (Hints):** Dark Gray (#757575)
- **Disabled:** Light Gray (#BDBDBD)
- **Links:** Primary Blue (#1976D2)

### Backgrounds
- **Primary:** White (#FFFFFF)
- **Hover/Focus:** Light Gray (#F5F5F5)
- **Disabled:** Light Gray (#E0E0E0)
- **Overlays:** Black with 50% opacity

### Status Indicators
```
✓ Done:          Success Green (#4CAF50)
⚠ Pending:       Info Cyan (#00BCD4)
⏳ In Progress:  Warning Orange (#FF9800)
✗ Cancelled:     Error Red (#F44336)
```

### Interactive Elements
- **Buttons:** Primary Blue (#1976D2)
- **Hover:** Dark Blue (#1565C0)
- **Disabled:** Light Gray (#BDBDBD)
- **Focus Ring:** Primary Blue border

---

## Component Usage Patterns

### Buttons

**Primary Button** (main action)
- Background: Primary Blue
- Text: White, bold
- Use for: Save, Submit, Create, Confirm

**Secondary Button** (alternative)
- Background: White, border Primary Blue
- Text: Primary Blue
- Use for: Cancel, Back, Optional actions

**Outline Button**
- Background: Transparent
- Border: 1px Primary Blue
- Text: Primary Blue
- Use for: Less important actions

**Danger Button**
- Background: Error Red
- Text: White
- Use for: Delete, Discard, Destructive actions

### Input Fields

**TextField**
- Height: 48px
- Padding: 12px
- Border: 1px Medium Gray
- Focused: 2px Primary Blue border
- Error: 2px Error Red border

**Required Fields**
- Label with asterisk (*) in Error Red
- Example: "Customer Name *"

**Validation Feedback**
- Error below field in Error Red
- Success checkmark in Success Green
- Character counter for text limits

### Cards

**Standard Card**
- Background: White
- Border: 1px Light Gray
- Shadow: elevation 2
- Padding: 16px
- Border Radius: 8px

**Tappable Card**
- Add hover effect (elevation 4)
- Ripple effect on tap
- Change cursor to pointer

### Chips/Tags

**Status Chip**
```
Example: [Pending]  [In Progress]  [Done]

Background: Status color (semi-transparent)
Text: Status color (full opacity)
Border Radius: 16px
Padding: 8px 12px
```

---

## Typography Usage

### Headings
- **H1 (32px, Bold):** Page titles only
- **H2 (28px, Bold):** Section headers
- **H3 (24px, SemiBold):** Card titles
- **H4 (20px, SemiBold):** Subsection titles

### Body Text
- **Body Large (16px):** Main content
- **Body Normal (14px):** Descriptions, form labels
- **Body Small (12px):** Captions, hints

### Constraints
- **Max line length:** 60-75 characters for readability
- **Min line height:** 1.5x font size
- **All text:** Use Vietnamese diacritics where applicable

---

## Spacing Guidelines

### Padding
- **Inside containers:** 16px (M) standard
- **Inside buttons/chips:** 12px (S/M mix)
- **Large sections:** 24px (L)

### Margins
- **Between sections:** 24px (L)
- **Between items in list:** 8px (S)
- **Between form fields:** 16px (M)

### Examples
```dart
// Standard card padding
Padding(padding: EdgeInsets.all(16), child: content)

// Section spacing
SizedBox(height: 24)

// Form field spacing
Padding(
  padding: EdgeInsets.only(bottom: 16),
  child: TextField(),
)
```

---

## Interaction Patterns

### Tap Targets
- Minimum size: 48px × 48px
- Spacing between: 8px minimum

### Loading States
- Show circular progress indicator
- Disable buttons during loading
- Clear loading message

### Error States
- Show error icon + message below field
- Highlight field with Error Red border
- Provide clear, actionable error text

### Empty States
- Show empty icon + message
- Provide call-to-action button
- Example: "No repairs yet. [Create Repair]"

### Confirmation Dialogs
- Title + message
- Action buttons (Cancel, Confirm)
- Warning icon for destructive actions

---

## Keyboard & Input

### Keyboard Types
```dart
TextInputType.text       // Standard keyboard
TextInputType.phone      // Phone keyboard (numbers)
TextInputType.emailAddress // Email keyboard
TextInputType.number     // Number keyboard
TextInputType.multiline  // Multi-line text
```

### Input Formatting
- **Phone:** Display as 0912-xxx-xxx format
- **Currency:** Show ₫ symbol, format with commas
- **Date:** Show dd/MM/yyyy or use DatePicker
- **Decimal:** Show 2 decimal places

---

## Accessibility (A11y) Checklist

- [ ] All text has sufficient contrast (4.5:1 minimum)
- [ ] All interactive elements are 48px × 48px minimum
- [ ] All icons have text alternatives
- [ ] Form labels are associated with inputs
- [ ] Color is not the only indicator (use text/icons too)
- [ ] Focus states are visible
- [ ] Touch targets have 8px spacing
- [ ] Vietnamese text uses proper diacritics

---

## Dark Mode Preparation

**Status:** Not implemented yet  
**When implementing:**
- Invert color palette
- Use `MediaQuery.of(context).platformBrightness`
- Maintain contrast ratios
- Test in device dark mode settings

---

## Common Mistakes to Avoid

❌ Using colors without checking contrast ratio  
❌ Touch targets smaller than 48px × 48px  
❌ Text without proper hierarchy  
❌ Too many font sizes in one screen  
❌ Inconsistent spacing and padding  
❌ Breaking safe areas on notched devices  
❌ Overusing animations (keep it subtle)  
❌ Not testing on multiple device sizes  

---

## References

- **Material Design 3:** https://m3.material.io/
- **Design Tokens:** See `docs/DESIGN_TOKENS_REFERENCE.md`
- **Design System:** See `docs/DESIGN_SYSTEM.md`

---

**Last Updated:** 2026-05-15  
**Version:** 1.0
