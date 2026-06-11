# DriveDock Design System

DriveDock's visual language is native, calm, and premium. Every design decision should feel like it belongs on a Mac — not like a web app wrapped in a window.

---

## Design Principles

| Principle | Meaning |
|-----------|---------|
| **Native** | Use macOS conventions, materials, controls, and behaviours. Never fight the platform. |
| **Glassy** | Translucent materials and soft depth. Not flat, not heavy. |
| **Clean** | Generous whitespace, clear hierarchy, no clutter. |
| **Calm** | Muted tones, smooth motion, no visual noise. Errors are informative, not alarming. |
| **Fast** | Instant feedback. Progress is always visible. Nothing feels stuck. |
| **Visual** | Show state through colour, icon, and motion — not walls of text. |
| **Minimal** | Every element earns its place. Remove anything that doesn't help. |
| **Premium** | Polished details, smooth animations, consistent spacing. Feels like a first-party app. |
| **Trustworthy** | Clear language, honest state, no dark patterns. The app does what it says. |

---

## Colour Palette

### Light Mode

| Role | Colour | Hex | Usage |
|------|--------|-----|-------|
| Background | Warm white | `#FAFAFA` | Window background |
| Surface | Soft grey | `#F0F0F0` | Cards, sidebar |
| Control | Light grey | `#E5E5E5` | Button backgrounds, input fields |
| Border | Subtle grey | `#D1D1D1` | Dividers, strokes |
| Text Primary | Near-black | `#1D1D1F` | Headings, body text |
| Text Secondary | Medium grey | `#6E6E73` | Labels, captions |
| Text Tertiary | Light grey | `#AEAEB2` | Placeholders, hints |
| Accent | Deep blue | `#0071E3` | Primary actions, links, selection |
| Success | Calm green | `#34C759` | Completed states |
| Warning | Soft amber | `#FF9F0A` | Paused, rate-limited |
| Error | Muted red | `#FF3B30` | Failed states |
| Info | Sky blue | `#5AC8FA` | Informational badges |

### Dark Mode

| Role | Colour | Hex | Usage |
|------|--------|-----|-------|
| Background | Near-black | `#1C1C1E` | Window background |
| Surface | Dark charcoal | `#2C2C2E` | Cards, sidebar |
| Control | Charcoal | `#3A3A3C` | Button backgrounds, input fields |
| Border | Subtle dark | `#48484A` | Dividers, strokes |
| Text Primary | White | `#F5F5F7` | Headings, body text |
| Text Secondary | Light grey | `#A1A1A6` | Labels, captions |
| Text Tertiary | Medium grey | `#636366` | Placeholders, hints |
| Accent | Bright blue | `#0A84FF` | Primary actions, links, selection |
| Success | Green | `#30D158` | Completed states |
| Warning | Amber | `#FFD60A` | Paused, rate-limited |
| Error | Red | `#FF453A` | Failed states |
| Info | Blue | `#64D2FF` | Informational badges |

### Semantic Colour Mapping

```
Status:   completed  → green
          uploading  → accent blue
          paused     → amber
          failed     → red
          waiting    → secondary grey
          preparing  → secondary grey
          cancelled  → tertiary grey
```

---

## Typography

### Font Family

- **Primary**: SF Pro (system default)
- **Monospaced**: SF Mono (for speeds, counts, progress)

### Semantic Styles

| Style | Usage | Spec |
|-------|-------|------|
| Large Title | Onboarding headings | `.largeTitle.weight(.bold)` |
| Title 1 | Section headers | `.title.weight(.semibold)` |
| Title 2 | View titles | `.title2.weight(.semibold)` |
| Title 3 | Subheadings | `.title3.weight(.medium)` |
| Headline | Button labels, emphasis | `.headline` |
| Body | Content text | `.body` |
| Callout | Secondary content | `.callout` |
| Subhead | Tertiary content | `.subhead` |
| Caption | Labels, metadata | `.caption` |
| Caption 2 | Fine print, hints | `.caption2` |
| Mono | Speeds, counts, codes | `.caption.monospaced()` |

### Font Weights

- **Bold** (`.bold`): Page titles, primary headings
- **Semibold** (`.semibold`): Section headers, emphasis
- **Medium** (`.medium`): Subheadings, button labels
- **Regular** (`.regular`): Body text, descriptions

---

## Spacing System

DriveDock uses a **4pt base grid**. All spacing is a multiple of 4.

| Token | Value | Usage |
|-------|-------|-------|
| `spacing-xs` | 4pt | Inline icon gaps, tight padding |
| `spacing-sm` | 8pt | Related element gaps, small padding |
| `spacing-md` | 12pt | Standard element gaps, list row padding |
| `spacing-lg` | 16pt | Section gaps, card padding |
| `spacing-xl` | 20pt | Major section padding |
| `spacing-2xl` | 24pt | View-level padding, large gaps |
| `spacing-3xl` | 32pt | Section dividers, onboarding gaps |
| `spacing-4xl` | 40pt | Window margins, large layout padding |

### Corner Radii

| Token | Value | Usage |
|-------|-------|-------|
| `radius-sm` | 6pt | Badges, small buttons |
| `radius-md` | 8pt | Cards, inputs, dropdowns |
| `radius-lg` | 12pt | Panels, sheets |
| `radius-xl` | 16pt | Large cards, drop zones |
| `radius-2xl` | 20pt | Drop zone border |

---

## Component Library

### Buttons

| Type | Style | Usage |
|------|-------|-------|
| Primary | `.borderedProminent` | Main actions: Connect, Upload, Start |
| Secondary | `.bordered` | Alternative actions: Choose Folder, Cancel |
| Plain | `.plain` | Inline links: Explore without account |
| Icon | `.borderless` | Toolbar actions: Pause, Resume, Cancel, Retry |

**Sizes**: `.large` for onboarding primary actions, `.regular` for standard, `.small` for inline/compact.

### Status Badges

Capsule shape with SF Symbol + label text.

| Status | Colour | Icon |
|--------|--------|------|
| Preparing | Secondary | `gearshape` |
| Waiting | Secondary | `clock` |
| Uploading | Accent blue | `arrow.up.circle` |
| Paused | Amber | `pause.circle` |
| Completed | Green | `checkmark.circle.fill` |
| Failed | Red | `exclamationmark.circle.fill` |
| Cancelled | Tertiary | `xmark.circle` |
| Needs Reconnect | Amber | `person.crop.circle.badge.exclamationmark` |
| Permission Needed | Amber | `lock.shield` |
| Skipped | Tertiary | `forward.circle` |

### Status Indicators

**Pulsing Dot**: 8pt circle with breathing animation (1.0s ease-in-out, repeat forever). Used for active upload status. Replaced by static dot when reduced motion is enabled.

**Progress Bar**: 8pt rounded rectangle. Track is accent at 15% opacity. Fill is solid accent. Animates width changes with 0.3s ease-in-out.

**Status Dot (Static)**: 6pt circle. Green for active, yellow for paused, secondary for idle.

### Cards

**GlassCard**: `.ultraThinMaterial` background, 12pt corner radius, subtle shadow (`Color.primary.opacity(0.05)`, radius 4, y-offset 2), standard padding.

### Empty States

Use `ContentUnavailableView` with:
- SF Symbol icon at 40pt
- Title in `.title3.weight(.medium)`
- Description in `.caption` with `.secondary` foreground
- Action button if applicable

---

## Animation Guidelines

### Timing

| Duration | Easing | Usage |
|----------|--------|-------|
| 0.15s | ease-in-out | Hover states, micro-interactions |
| 0.2s | ease-in-out | Drop zone response |
| 0.3s | ease-in-out | Standard transitions, progress bars |
| 0.5s | ease-out | Counter animations, value changes |
| 0.6s | spring (damping 0.6) | Checkmark celebration |
| 1.0–1.5s | ease-in-out, repeat forever | Pulsing dots, breathing icons |

### When to Animate

**Do animate**:
- Drop zone glow when files hover over it
- Queue items entering/leaving the list
- Progress bar width changes
- Completed checkmark appearance
- Menu bar progress ring
- Status badge transitions
- Onboarding step transitions

**Do not animate**:
- Text content changes
- Number updates (use monospaced font instead)
- Settings toggles
- Navigation between sidebar items
- Error messages appearing

### Reduced Motion

All animations must respect `@Environment(\.accessibilityReduceMotion)`. When enabled:

- Replace pulsing dots with static circles
- Remove all `.repeatForever` animations
- Replace spring animations with instant state changes
- Keep essential state transitions (opacity, position) but remove decorative motion
- Pattern: `.animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: x)`

---

## Iconography

### SF Symbols

DriveDock uses SF Symbols exclusively. No custom icons.

| Context | Size | Weight |
|---------|------|--------|
| Sidebar items | 16pt | Regular |
| Toolbar actions | 14pt | Regular |
| Status badges | 12pt | Regular |
| Empty state icons | 40pt | Regular |
| Onboarding hero | 64pt | Regular |
| Queue row file type | 16pt | Regular |

### Common Icons

| Action | SF Symbol |
|--------|-----------|
| Upload | `arrow.up.doc` |
| Folder | `folder.fill` |
| Image | `photo` |
| Video | `video` |
| Audio | `music.note` |
| Document | `doc` |
| Pause | `pause.fill` |
| Resume | `play.fill` |
| Retry | `arrow.clockwise` |
| Cancel | `xmark.circle` |
| Settings | `gearshape` |
| History | `clock.arrow.circlepath` |
| Account | `person.crop.circle` |
| Destination | `folder.badge.gearshape` |
| Starred | `star.fill` |
| Shared Drive | `person.3` |
| Completed | `checkmark.circle.fill` |
| Failed | `exclamationmark.circle.fill` |
| Warning | `exclamationmark.triangle.fill` |

---

## Layout Patterns

### Main Window

```
+------------------------------------------+
|  Toolbar (title, actions, inspector btn) |
+--------+---------------------------------+
|        |                                 |
| Side-  |  Main Content Area              |
| bar    |  (Drop Zone / Queue / History)  |
| 200pt  |                                 |
|        |                                 |
|        +---------------------------------+
|        |  Status Bar                     |
+--------+---------------------------------+
```

- **Sidebar**: Fixed 200pt width, `.sidebar` material
- **Main Area**: Flexible, expands with window
- **Inspector**: 280pt fixed width, right side, toggleable
- **Status Bar**: Full width bottom bar, `.bar` material, 6pt vertical padding

### Sidebar Sections

1. **Account Selector** — Top of sidebar, shows active account
2. **Uploads** — Queue, Active, Completed, Failed, Paused
3. **Destinations** — Recent, Starred, Shared Drives
4. **Other** — History, Settings

### Queue View

- `Table` for data-heavy views with sortable columns
- `List(selection:)` for selectable sidebar items
- Group by status: Uploading → Waiting → Paused → Failed → Completed
- Each row: Status badge (24pt) | File icon + name + metadata | Progress/actions

### Inspector Panel

Right-side detail pane (280pt) with:
- File name and icon at top
- Metadata section (size, type, destination, account)
- Progress section (bar, speed, ETA, uploaded bytes)
- Error section (if failed: category, message, user action)
- Actions section (pause, resume, cancel, retry, reveal, open in Drive)

### Sheets & Modals

| Sheet | Size | Content |
|-------|------|---------|
| Destination Picker | 500×450 | Tabbed: Browse, Recent, Starred, Shared Drives |
| Settings | 620×500 | TabView: General, Uploads, Accounts, Network, Privacy, Advanced |
| Onboarding | 500×400 min | Multi-step wizard |

---

## Accessibility

### Requirements

- **VoiceOver**: Every interactive element has `.accessibilityLabel` and `.accessibilityHint`
- **Keyboard Navigation**: All flows navigable via keyboard
- **Reduced Motion**: All animations respect `@Environment(\.accessibilityReduceMotion)`
- **Colour Contrast**: Minimum 4.5:1 for text, 3:1 for UI elements
- **Status Not by Colour Alone**: Always pair colour with icon or text label
- **Scalable Text**: Support Dynamic Type where practical
- **Focus States**: Visible focus rings on all interactive elements
- **Accessibility Labels**: Combine related elements with `.accessibilityElement(children: .combine)`

### Patterns

```swift
// Combine related elements
.accessibilityElement(children: .combine)
.accessibilityLabel("Status: Uploading")

// Button with descriptive hint
.accessibilityLabel("Choose files to upload")
.accessibilityHint("Opens a file picker to select files for uploading")

// Progress with percentage
.accessibilityLabel("Upload progress: \(item.progressPercent) percent")

// Decorative elements hidden
.accessibilityHidden(true)
```

---

## Dark / Light Mode

### Guidelines

- Use semantic system colours (`.primary`, `.secondary`, `.tertiary`) for text
- Use `Color(nsColor: .controlBackgroundColor)` for controls
- Use `Color(nsColor: .windowBackgroundColor)` for window backgrounds
- Use `.ultraThinMaterial` / `.bar` for overlays and bars
- Never hardcode hex colours in views — define semantic colours in the asset catalog
- Test all states in both modes: uploading, paused, failed, completed, empty
- Status colours (green, amber, red) are tuned per mode to maintain legibility

### Materials

| Material | Usage |
|----------|-------|
| `.ultraThinMaterial` | Glass cards, floating panels |
| `.bar` | Status bar, toolbar backgrounds |
| `.sidebar` | Sidebar background |
| `.windowBackgroundColor` | Main window background |
| `.controlBackgroundColor` | Input fields, control backgrounds |

---

## Spacing & Layout Constants

```swift
// Window
static let sidebarWidth: CGFloat = 200
static let inspectorWidth: CGFloat = 280
static let minWindowWidth: CGFloat = 780
static let minWindowHeight: CGFloat = 500

// Drop Zone
static let dropZoneWidth: CGFloat = 360
static let dropZoneHeight: CGFloat = 220
static let dropZoneCornerRadius: CGFloat = 20

// Cards
static let cardCornerRadius: CGFloat = 12
static let cardPadding: CGFloat = 16

// Status Bar
static let statusBarHeight: CGFloat = 28

// Queue Row
static let queueRowVerticalPadding: CGFloat = 4
static let statusBadgeWidth: CGFloat = 24

// Spacing Tokens
static let spacingXS: CGFloat = 4
static let spacingSM: CGFloat = 8
static let spacingMD: CGFloat = 12
static let spacingLG: CGFloat = 16
static let spacingXL: CGFloat = 20
static let spacing2XL: CGFloat = 24
static let spacing3XL: CGFloat = 32
static let spacing4XL: CGFloat = 40
```
