# DriveDock SPEC.md

## Product Name

**DriveDock**

## Product Positioning

DriveDock is a beautiful, open-source macOS app for uploading files and folders to Google Drive with a native Mac interface, visual transfer control, multi-account support, fast parallel uploads, background reliability, and safe recovery when uploads fail.

It is not trying to replace the full Google Drive for desktop sync client. It is a focused uploader for people who want a cleaner, faster, more controllable way to send files to Drive without setting up full sync folders, waiting for opaque background behaviour, or guessing whether files completed properly.

**Simple positioning:**

> DriveDock is the cleanest way to upload files to Google Drive from your Mac.

**OSS positioning:**

> An open-source, native macOS uploader for Google Drive, built for speed, clarity, privacy, and control.

---

## Product Goal

Build the best simple-but-powerful Google Drive uploader for macOS.

The app must feel native, light, polished, safe, and reliable. A normal user should understand it in seconds. A power user should still get serious upload controls, queue management, account switching, bandwidth behaviour, folder targeting, background operation, detailed history, and clear recovery.

The winning product experience is:

1. Open DriveDock.
2. Connect Google account.
3. Drop files or folders.
4. Choose destination.
5. Upload fast with visible progress.
6. Continue safely in the background.
7. Know exactly what succeeded, failed, skipped, or needs attention.

---

## Core Product Principles

### 1. Native first

DriveDock should feel like a real macOS app, not a wrapped website. Use native windows, native menus, native permissions, native drag-and-drop, native notifications, native Keychain storage, and proper macOS background behaviour.

### 2. Fast but controlled

The app should support parallel uploads, resumable uploads, adaptive retries, bandwidth-aware behaviour, and smart queue management. Speed matters, but not at the cost of data loss, duplicate chaos, API quota abuse, or battery drain.

### 3. Visual clarity

Users must always understand:

- What is queued
- What is uploading
- What is paused
- What succeeded
- What failed
- Which Google account is being used
- Which Drive folder is receiving the files
- Whether the app is safe to close

### 4. Simple by default, powerful when needed

The primary screen should be minimal. Advanced controls should exist, but not disturb simple users.

### 5. Privacy-respecting OSS

The app should be open-source, transparent, local-first, and clear about what it stores. No hidden analytics. No silent file scanning beyond what is required for upload preparation.

### 6. Safe failure recovery

Uploads fail in real life. Wi-Fi drops. Macs sleep. Google tokens expire. Users close lids. Files move. Quotas happen. DriveDock must treat these as normal situations, not edge cases.

---

## Target Users

### Primary users

- Mac users who often upload large files to Google Drive
- Designers, video editors, marketers, founders, agencies, students, creators, and operators
- People who do not want full Drive sync but still need reliable uploads
- Users managing multiple Google accounts
- Users who upload folders, media files, client assets, exports, documents, zipped project files, and backups

### Secondary users

- Developers and technical users who want OSS control
- Small teams using Shared Drives
- Power users who want faster batch uploads and queue control
- People with unstable internet who need resumable upload recovery

---

## Non-Goals

DriveDock should not become a bloated cloud storage suite in V1.

Do not build these initially:

- Full two-way Google Drive sync
- Local virtual filesystem like Google Drive for desktop
- File editing inside DriveDock
- Team collaboration/chat/comments
- Complex permission management UI
- Full Google Docs editor behaviour
- Enterprise admin console
- Non-Google cloud providers in V1
- Mobile app
- Windows/Linux app in V1

Future extensibility is allowed, but V1 must stay focused.

---

## Recommended Tech Direction

### App platform

**Native macOS app using Swift + SwiftUI + AppKit where needed.**

Rationale:

- Best native feel on macOS
- Best access to Keychain, Finder drag-and-drop, notifications, menu bar, file bookmarks, background behaviour, and system integration
- Better performance and lower memory usage than Electron for a utility app
- Better trust story for an OSS Mac utility
- Cleaner long-term macOS maintenance

### Minimum macOS target

Recommended:

- **macOS 14 Sonoma minimum** for V1
- Support macOS 15 and newer fully

Alternative if broader support is required:

- macOS 13 Ventura minimum, but avoid newer API dependencies that create extra fallback complexity

### Language and frameworks

- Swift
- SwiftUI for primary UI
- AppKit for advanced macOS behaviours where SwiftUI is not enough
- URLSession for networking and upload streaming
- Keychain Services for secure token storage
- FileManager and security-scoped bookmarks for file access
- UserNotifications for local upload notifications
- ServiceManagement / LaunchAgent-style helper where needed for background/menu-bar behaviour
- SQLite or lightweight local persistence via SQLite/GRDB for queue, history, upload sessions, and local app state

### Google API integration

Use Google Drive API v3.

Required Drive API capabilities:

- OAuth-based user authorisation
- My Drive support
- Shared Drives support
- Folder listing/searching
- Folder creation
- File creation/upload
- Resumable uploads
- Metadata handling
- Duplicate detection assistance
- MIME type handling
- Error classification
- Quota/rate-limit handling

### Authentication direction

Use OAuth 2.0 for native desktop apps.

Requirements:

- Use browser-based auth, not embedded web views
- Support PKCE where applicable
- Use least-privilege scopes where possible
- Store refresh/access tokens securely in macOS Keychain
- Never store tokens in plain local files
- Allow account disconnect and token removal
- Allow multiple Google accounts
- Show account email/avatar/name after connection
- Handle expired, revoked, or invalid tokens gracefully

Recommended scopes:

- Prefer the narrowest workable Drive scope for files created/opened by the app where possible
- If full folder browsing/upload destination selection requires broader access, clearly explain why before requesting access
- Avoid unnecessary Google profile scopes except what is needed to display account identity

The app must be honest during consent. Do not request more access than the product genuinely needs.

---

## Core Feature Set

## 1. Onboarding

### First launch experience

The first launch must be clean and short.

Screens:

1. Welcome
2. Connect Google Drive
3. Choose default upload behaviour
4. Ready screen

### Welcome screen

Content:

- DriveDock logo
- Short value statement
- “Upload files and folders to Google Drive with speed, clarity, and control.”
- Primary button: Connect Google Drive
- Secondary button: Explore App Demo / Continue without account

### Connect account

Flow:

1. User clicks Connect Google Drive
2. App opens default browser for Google OAuth
3. User grants access
4. App returns to DriveDock
5. Account appears with name/email/avatar if available
6. User lands on main uploader screen

### Default behaviour setup

Options:

- Default destination: Ask every time / Last used folder / Selected folder
- Upload mode: Balanced / Fast / Light
- After upload: Show summary / Open uploaded folder / Do nothing
- Launch at login: On/Off
- Menu bar helper: On/Off

Keep these optional. Do not block the user with too much setup.

---

## 2. Main Window

The main window is the heart of the app.

### Main layout

Recommended layout:

- Left sidebar
- Main drop zone / queue area
- Right inspector panel when item selected
- Bottom status bar

### Left sidebar sections

- Current account selector
- Uploads
  - Queue
  - Active
  - Completed
  - Failed
  - Paused
- Destinations
  - Recent folders
  - Starred destinations
  - Shared Drives
- History
- Settings

### Main area states

#### Empty state

Show a large, beautiful glass-style drop zone:

- “Drop files or folders here”
- “or choose files” button
- “Choose Drive destination” selector
- Small note: “Uploads continue safely in the background when enabled.”

#### Queue state

Show queue grouped by status:

- Uploading now
- Waiting
- Paused
- Completed
- Needs attention

Each queue item should show:

- File/folder icon or thumbnail
- File/folder name
- Local path tooltip
- Destination account
- Destination Drive folder
- Size
- Progress bar
- Speed
- ETA
- Status badge
- Pause/resume/cancel/retry actions

### Right inspector panel

When an item is selected:

- File/folder name
- Local source path
- Destination folder
- Account
- File size
- Upload method
- Current progress
- Uploaded bytes
- Remaining bytes
- Speed graph mini-view
- Retry count
- Error detail if failed
- Actions: pause, resume, cancel, retry, reveal local file, open in Drive after completion

### Bottom status bar

Show:

- Overall queue progress
- Active uploads count
- Total upload speed
- Remaining data
- Estimated time remaining
- Network mode
- Background status

---

## 3. Drag-and-Drop Uploading

### Supported input methods

- Drag files onto main window
- Drag folders onto main window
- Drag files/folders onto menu bar popover
- Right-click Finder extension: Upload with DriveDock
- File picker button
- Paste file paths from clipboard if applicable
- Drop onto Dock icon if feasible

### Drop behaviour

After files are dropped:

1. App validates access and stores security-scoped bookmarks if needed
2. App scans folder structure if folders are included
3. App estimates total size and item count
4. User chooses destination if no default exists
5. App displays upload plan summary
6. User confirms or starts immediately depending on preferences

### Folder upload behaviour

If the user drops a folder:

- Preserve folder structure by default
- Create a matching root folder in Drive
- Upload nested files into matching subfolders
- Handle empty folders if Drive supports folder creation without files
- Detect inaccessible files and report them before upload starts where possible
- Show folder-level and file-level progress

### Hidden/system files

Default:

- Ignore common macOS junk files such as `.DS_Store`
- Ignore temporary upload/cache files
- Allow user to override in Settings

Settings:

- Ignore hidden files: On by default
- Ignore system metadata files: On by default
- Include package contents: Ask for app bundles and package-like folders

---

## 4. Destination Selection

### Destination picker

The destination picker must be one of the strongest parts of the UX.

Capabilities:

- Browse My Drive
- Browse Shared Drives
- Search folders
- Show recent destinations
- Show starred destinations inside DriveDock
- Create new folder
- Create nested folder path
- Remember last used folder per account
- Remember destination per local folder rule if user creates one

### Destination picker UI

Display:

- Account at top
- Search field
- Breadcrumb path
- Folder list
- Shared Drive switch/section
- New Folder button
- Confirm destination button

### Folder creation

User can:

- Create a folder before uploading
- Create a folder automatically using dropped folder name
- Create date-based folders through templates in future advanced settings

### Recent destinations

DriveDock should remember:

- Folder name
- Drive folder ID
- Account ID
- Shared Drive indicator
- Last used date

Do not rely on folder name alone. Google Drive folder names are not globally unique.

---

## 5. Account Management

### Multi-account support

Required.

Users must be able to connect multiple Google accounts and switch between them easily.

Account screen should show:

- Account name
- Email
- Avatar if available
- Connected date
- Token status
- Default destination
- Storage/quota visibility if feasible
- My Drive and Shared Drive availability
- Disconnect button

### Account switching

When uploading:

- User can choose account per upload batch
- Default account is remembered
- Queue items must remain tied to the account selected at creation
- Switching account should not accidentally move existing queued uploads to another account

### Account errors

Handle:

- Token expired
- Token revoked
- Account permission changed
- Workspace admin restrictions
- Shared Drive access removed
- OAuth consent not verified in development builds

User-friendly error examples:

- “DriveDock needs you to reconnect this account.”
- “You no longer have access to this Shared Drive folder.”
- “Google rejected this upload because of quota or permission limits.”

---

## 6. Upload Engine

The upload engine is the most important technical system in the app.

### Upload modes

Provide three simple modes:

#### Balanced

Default mode. Good speed without overwhelming the network or Google API.

- Moderate parallel uploads
- Adaptive speed
- Battery/network aware
- Best for most users

#### Fast

For users who want maximum throughput.

- Higher parallelism
- Larger chunks where appropriate
- More aggressive queue processing
- Warning if on battery or poor network

#### Light

For working while uploading.

- Lower parallelism
- Lower network pressure
- Better for calls, browsing, battery, and weak Wi-Fi

### Parallel upload behaviour

DriveDock must support parallel uploads across multiple files.

Important rule:

- Parallelise across files, not uncontrolled chunks of the same file unless the Drive resumable protocol and implementation safely support it.
- Large individual files should use resumable upload sessions.
- Many small files should be batched logically through controlled concurrency.

Recommended initial concurrency:

- Balanced: 3 active file uploads
- Fast: 5 to 8 active file uploads, adaptive
- Light: 1 to 2 active file uploads

The exact values can be tuned after real testing.

### Adaptive concurrency

The engine should automatically reduce or increase concurrency based on:

- Error rate
- HTTP 429/403 quota/rate responses
- Network instability
- Upload speed trend
- Battery state
- User-selected mode
- File sizes
- Number of small files

### Resumable uploads

Required for:

- Large files
- Unstable connections
- Background safety
- Pause/resume
- Recovery after app restart

DriveDock should use Google Drive resumable uploads for reliability. Store resumable session state locally so interrupted uploads can continue where possible.

For each resumable upload, persist:

- Local file reference
- File size
- Last known uploaded byte range
- Resumable session URL if valid
- Destination folder ID
- Account ID
- Metadata
- Created time
- Last activity time
- Retry count
- Error status

### Upload chunk strategy

Chunk size should be configurable internally and adjusted by file size/network mode.

Guidelines:

- Small files can use simpler upload methods when safe
- Medium/large files should use resumable upload
- Avoid loading entire large files into memory
- Stream from disk
- Keep memory predictable
- Use chunk sizes aligned with Google resumable upload requirements
- Track per-chunk success/failure

### Small file optimisation

Many users upload folders with hundreds or thousands of small files.

Optimisations:

- Controlled concurrency
- Avoid excessive metadata calls
- Cache destination folder IDs during a batch
- Create folder tree once before uploading files
- Avoid duplicate folder creation
- Show aggregate folder progress
- Avoid blocking UI while scanning

### Large file optimisation

For large files:

- Always stream from disk
- Use resumable upload
- Show accurate progress
- Survive network drops
- Resume after app restart where possible
- Avoid duplicate Drive files after interrupted attempts
- Validate final metadata after completion

### Background uploads

Required.

DriveDock should continue uploading when:

- Main window is closed
- App is minimised
- Menu bar mode is active
- User switches apps

DriveDock should gracefully pause or recover when:

- Mac sleeps
- Network disconnects
- VPN changes
- User logs out/restarts
- Token expires

The app should not mislead users into thinking uploads continue if macOS suspends all app activity. It should clearly show “Paused while Mac was asleep” or “Resuming after wake”.

### Menu bar helper

DriveDock should include a menu bar component.

Menu bar popover should show:

- Current upload status
- Active upload count
- Overall progress
- Drop zone
- Pause all / resume all
- Open main window
- Recent completed uploads
- Quick account switch
- Quit DriveDock

Optional setting:

- Hide Dock icon and run primarily in menu bar mode

### Launch at login

Setting:

- Launch DriveDock at login

Behaviour:

- Start quietly in menu bar
- Resume pending queue if allowed
- Never start uploading after login without respecting user preferences

---

## 7. Queue Management

### Queue states

Each item can be:

- Preparing
- Waiting
- Uploading
- Paused
- Completed
- Failed
- Cancelled
- Needs account reconnect
- Needs destination permission
- Skipped

### Batch states

A batch can be:

- Preparing
- Ready
- Uploading
- Partially completed
- Completed
- Paused
- Failed
- Cancelled

### Queue actions

User can:

- Pause individual item
- Resume individual item
- Cancel individual item
- Retry failed item
- Pause all
- Resume all
- Clear completed
- Clear failed
- Reorder queue
- Prioritise selected upload
- Move item to top
- Remove item before upload
- Change destination before upload starts

### Queue persistence

The queue must persist across app restarts.

After reopening:

- Completed items remain in history
- Pending items remain queued
- Interrupted resumable uploads attempt recovery
- Failed items show clear reason
- Missing local files show “local file not found”

---

## 8. Duplicate Handling

Google Drive allows files with the same name in the same folder. Normal users may not understand this. DriveDock needs clear duplicate behaviour.

### Duplicate modes

Before upload, user can choose:

1. **Keep both**
   - Upload anyway
   - Google Drive may show same-name files

2. **Rename new file**
   - Add suffix like `filename 2.ext`

3. **Skip existing**
   - Do not upload if a likely matching file already exists

4. **Replace/update existing**
   - Advanced mode only
   - Requires careful confirmation
   - Should update the existing Drive file where possible

Default:

- For simple users: Keep both or Ask when duplicate is detected
- For safety: Do not replace by default

### Duplicate detection

Use Drive folder search by name and metadata.

Compare:

- Name
- Size where available
- MIME type
- Modified date where useful
- Parent folder ID

Do not overpromise perfect duplicate detection because Google Drive semantics and user permissions can affect visibility.

---

## 9. Folder Rules and Quick Actions

V1 should support simple quality-of-life rules without becoming complex.

### Recent destination rules

Optional:

- “Always upload files from this local folder to this Drive folder”

Example:

- Local `Desktop/Client Exports` → Google Drive `Client Uploads`

### Quick upload presets

User can create presets:

- Account
- Destination folder
- Duplicate behaviour
- Upload mode

Example presets:

- Client Files
- Personal Backup
- Shared Drive Uploads
- Video Exports

### Finder integration

A Finder extension should be considered a strong feature.

Right-click actions:

- Upload with DriveDock
- Upload to recent destination
- Upload to default Drive folder

Keep Finder extension optional. The app must work perfectly without it.

---

## 10. History and Completion

### Upload history

History screen should show:

- Date/time
- File/folder name
- Account
- Destination
- Size
- Status
- Duration
- Speed average
- Drive link if available
- Error if failed

### Completion summary

After a batch completes:

Show:

- Total files uploaded
- Total size uploaded
- Failed/skipped count
- Destination folder
- Account used
- Duration
- Open in Drive button
- Copy Drive links button
- Export report option

### Copy links

User can copy:

- Link to uploaded folder
- Links to selected uploaded files
- Plain text summary
- Markdown summary

### Export upload report

Support export as:

- CSV
- JSON
- Plain text

This is useful for agencies and teams proving files were uploaded.

---

## 11. Notifications

Use native macOS notifications.

Notification types:

- Batch completed
- Batch completed with failures
- Upload failed and needs attention
- Account reconnect required
- Network lost
- Upload resumed
- Large upload completed

Notifications should be respectful. Avoid noisy per-file notifications unless user enables them.

Settings:

- Notify when all uploads finish
- Notify only on errors
- Notify per large file
- Disable notifications

---

## 12. Settings

Settings should be clear and grouped.

### General

- Launch at login
- Show menu bar icon
- Show Dock icon
- Default start screen
- Theme: System / Light / Dark
- Accent style
- Confirm before quitting with active uploads

### Uploads

- Default upload mode: Balanced / Fast / Light
- Default destination behaviour
- Parallel upload limit
- Bandwidth limit
- Duplicate handling
- Ignore hidden files
- Ignore `.DS_Store`
- Preserve folder structure
- Auto-retry failed uploads
- Resume uploads on app launch

### Accounts

- Connected accounts
- Add account
- Remove account
- Reconnect account
- Default account
- Per-account default destination

### Network

- Pause on metered/hotspot-like network if detectable
- Pause on VPN change if enabled
- Retry behaviour
- Proxy support if needed in future
- Bandwidth schedule in future

### Privacy and Security

- Clear local history
- Clear queue cache
- Remove all local app data
- Remove tokens from Keychain
- Show data stored locally
- Enable/disable diagnostics logs

### Advanced

- Chunk size policy: Auto recommended
- Max active uploads
- Max retry count
- Debug logs
- Export logs
- Reset app state

---

## 13. Design Direction

## Visual Style

DriveDock should look premium but calm. The design should feel like a native Mac utility from 2026, not a generic SaaS dashboard.

### Style keywords

- Native
- Glassy
- Clean
- Calm
- Fast
- Visual
- Minimal
- Premium
- Trustworthy

### UI direction

- Use SwiftUI-native macOS materials
- Use translucent panels carefully, not excessively
- Use soft rounded corners
- Use clear hierarchy
- Use smooth micro-interactions
- Use compact but readable spacing
- Avoid heavy gradients everywhere
- Avoid childish colours
- Avoid cluttered settings

### Recommended colour direction

Primary:

- Deep Drive blue
- Clean white
- Soft graphite

Dark mode:

- Near-black graphite
- Deep blue accents
- Subtle green for success
- Amber for warnings
- Red only for genuine failure

Light mode:

- Warm white/soft grey backgrounds
- Blue primary actions
- Calm borders
- Soft shadows

### Icon direction

DriveDock icon should combine:

- A dock/base shape
- Upward file movement
- Subtle Google Drive-inspired triangular energy without copying Google’s trademark too directly
- Native macOS rounded app icon style

Avoid using Google Drive logo directly unless trademark usage is fully reviewed.

### Motion

Use motion to clarify state, not to decorate.

Good motion examples:

- Drop zone glow when files hover
- Queue item smoothly entering
- Progress bar easing
- Completed check animation
- Error shake should be subtle
- Menu bar progress ring

Avoid:

- Excessive bouncing
- Slow animations that delay work
- Overly flashy startup animations

---

## 14. Key User Flows

## Flow 1: First upload

1. User opens DriveDock
2. User clicks Connect Google Drive
3. Browser OAuth flow opens
4. User grants access
5. App shows connected account
6. User drops files onto window
7. App asks destination
8. User selects folder or creates new folder
9. User clicks Upload
10. Queue starts
11. Progress shown visually
12. Upload completes
13. User sees summary with Open in Drive button

## Flow 2: Upload a folder

1. User drops a folder
2. App scans folder structure
3. App shows count and size summary
4. App asks whether to preserve folder structure
5. User selects destination
6. App creates folder tree in Drive
7. App uploads files with parallel queue
8. Failed files are isolated, not blocking completed files
9. User gets completion report

## Flow 3: Background upload

1. User starts upload
2. User closes main window
3. App continues in menu bar
4. Menu bar icon shows progress
5. User opens popover to check progress
6. Upload completes
7. Notification appears
8. User opens Drive folder from notification/popover

## Flow 4: Network failure recovery

1. Upload is active
2. Internet drops
3. App detects failure
4. Uploads move to waiting/retrying state
5. User sees “Waiting for connection”
6. Internet returns
7. App resumes resumable uploads
8. Completed files are not re-uploaded
9. Summary explains interruption and recovery

## Flow 5: Multiple accounts

1. User connects personal Google account
2. User connects work Google account
3. User drops files
4. Destination picker asks account/folder
5. User selects work Shared Drive
6. Queue items are locked to work account
7. User can still switch UI to personal account without affecting active upload

## Flow 6: Failed upload

1. File fails due to permission/quota/network issue
2. Item moves to Needs Attention
3. User sees readable reason
4. User can retry, change destination, reconnect account, or skip
5. Completed items remain completed
6. Failed items can be exported in report

---

## 15. Google Drive Behaviour Requirements

### My Drive

Support:

- Folder browsing
- Folder creation
- Upload to folder
- File links after upload
- Duplicate handling

### Shared Drives

Support:

- Listing Shared Drives where available
- Browsing folders in Shared Drives
- Uploading to Shared Drive folders where user has permission
- Using Drive API parameters required for Shared Drive support
- Clear permission errors

### Google Docs conversion

V1 should upload files as files by default.

Optional future setting:

- Convert compatible Office files to Google Docs/Sheets/Slides

Do not enable conversion by default. Many users expect the exact file to upload unchanged.

### Metadata

Set useful metadata:

- Name
- Parent folder
- MIME type where known
- Modified time if supported and appropriate

Do not alter file contents.

---

## 16. Error Handling

DriveDock must classify errors clearly.

### Error categories

- Network error
- Google API quota/rate limit
- Authentication error
- Permission error
- Destination missing
- Local file missing
- Local file changed during upload
- File too large or unsupported
- Storage quota exceeded
- Shared Drive restriction
- Unknown Google API error

### User-facing error rules

Never show raw API errors as the only message.

Show:

- Human-readable summary
- Technical details expandable
- Suggested action
- Retry button where useful

Example:

**Upload paused because Google is limiting requests.**
DriveDock will slow down and retry automatically. You do not need to restart the upload.

### Retry strategy

Use exponential backoff with jitter for retryable errors.

Retryable:

- Temporary network failures
- 429 rate limit
- 5xx server errors
- Some 403 quota/rate cases depending on error reason

Not retryable without user action:

- Permission denied
- Invalid credentials after refresh fails
- Local file missing
- Destination removed
- Account disconnected
- Storage quota exceeded

### Backoff behaviour

- Start with short delay
- Increase delay on repeated failures
- Add jitter to prevent retry storms
- Cap maximum delay
- Reset backoff after stable success
- Reduce parallelism when rate-limited

---

## 17. Performance Requirements

### App performance

- Main window should open quickly
- Drag/drop should respond instantly
- Folder scanning should not freeze UI
- Queue updates should remain smooth with thousands of files
- Memory must remain stable during large file uploads
- Uploads must stream from disk instead of loading full files into memory

### Upload performance

- Parallel uploads across files
- Resumable upload for large files
- Adaptive concurrency
- Controlled retries
- Efficient folder tree creation
- Minimal unnecessary metadata calls
- Cached folder lookups during active batch

### Large batch performance

The app should handle:

- 1 huge file
- 10 huge files
- 1,000 small files
- Mixed folders
- Nested folder trees
- Interrupted uploads
- App restart recovery

### Performance metrics to track locally

- Current upload speed
- Average upload speed
- Time to first byte
- Retry count
- API throttling events
- Queue processing rate
- Folder scanning time
- Memory usage in debug builds

---

## 18. Security and Privacy

### Token storage

- Store tokens only in macOS Keychain
- Never store tokens in logs
- Never store tokens in plain SQLite/files
- Remove tokens when account is disconnected

### Local state storage

Allowed local storage:

- Queue metadata
- Upload session references
- File bookmarks
- History
- Preferences
- Logs if enabled

Sensitive local data must be minimised.

### Logs

Default logs should avoid:

- OAuth tokens
- Full personal file contents
- Private Drive URLs unless necessary
- Sensitive file paths in shareable diagnostics unless user approves

Debug logs should be exportable with a privacy warning.

### OSS privacy promise

The README and app should clearly state:

- DriveDock uploads only to the Google account selected by the user
- DriveDock does not sell data
- DriveDock does not run hidden analytics by default
- DriveDock stores credentials in Keychain
- DriveDock is open-source so behaviour can be inspected

### App permissions

Request macOS permissions only when needed.

- File access through user-selected files/folders
- Notifications only after explaining value or when first needed
- Login item only when user enables it

---

## 19. Accessibility

DriveDock must be accessible.

Requirements:

- Keyboard navigable main flows
- VoiceOver labels for queue items and controls
- Clear colour contrast in light/dark mode
- Status not conveyed by colour alone
- Reduced motion support
- Scalable text support
- Focus states
- Accessible error messages

---

## 20. OSS Project Requirements

DriveDock should look like a serious OSS product from day one.

Repository should include:

- README.md
- SPEC.md
- DESIGN.md later if needed
- CONTRIBUTING.md
- CODE_OF_CONDUCT.md
- SECURITY.md
- LICENSE
- CHANGELOG.md
- GitHub issue templates
- Pull request template
- Roadmap section
- Clear build instructions
- Clear Google OAuth setup instructions for contributors

### Licence

Recommended:

- MIT licence for maximum adoption

Alternative:

- Apache 2.0 if stronger patent language is desired

### Contribution approach

- Keep core upload engine carefully reviewed
- Require tests for upload/session/retry logic
- Mark good first issues
- Keep UI polish high
- Avoid random feature creep

---

## 21. Release and Distribution

### Distribution options

V1 OSS distribution:

- GitHub Releases with signed/notarised `.dmg`
- Homebrew Cask if possible
- Website download later

### macOS signing and notarisation

Production builds should be:

- Code signed
- Notarised by Apple
- Distributed in a clean DMG

Unsigned builds are acceptable only for contributor/dev builds.

### Auto-update

Recommended:

- Sparkle for macOS auto-updates

Requirements:

- Secure update feed
- Signed updates
- User-controlled update preferences
- Clear release notes

---

## 22. Testing Requirements

### Unit tests

Cover:

- Queue state transitions
- Retry policy
- Backoff calculations
- Duplicate handling decisions
- Destination model behaviour
- Account state behaviour
- Upload session persistence

### Integration tests

Cover:

- OAuth mock flow where possible
- Google Drive API mock server
- Resumable upload success
- Resumable upload interruption/recovery
- Rate limit handling
- Shared Drive parameter behaviour
- Folder tree creation

### UI tests

Cover:

- First launch flow
- Drop files flow
- Destination picker flow
- Queue controls
- Account switching
- Settings changes
- Failed upload recovery UI

### Manual QA scenarios

Must test:

- Upload one small file
- Upload one huge file
- Upload folder with nested folders
- Upload folder with many small files
- Pause/resume upload
- Quit and reopen during upload
- Sleep/wake Mac during upload
- Disconnect internet during upload
- Revoke Google account access
- Upload to Shared Drive
- Upload with duplicate file name
- Upload from external drive
- Upload when local file is deleted mid-upload
- Upload on battery
- Upload while app window is closed

---

## 23. Analytics and Telemetry

Default OSS behaviour:

- No invasive analytics
- No hidden tracking

Optional future diagnostics:

- Opt-in crash reports
- Opt-in anonymous performance diagnostics
- Clear privacy explanation
- Ability to disable anytime

For V1, local diagnostics are enough.

---

## 24. V1 Scope

### Must have

- Native macOS app
- Beautiful main window
- Menu bar helper
- Google OAuth account connection
- Multi-account support
- My Drive destination picker
- Shared Drive support
- Drag-and-drop files/folders
- Folder structure preservation
- Parallel uploads
- Resumable large file uploads
- Pause/resume/cancel/retry
- Background upload while app is running
- Queue persistence
- Upload history
- Completion summary
- Duplicate handling basics
- Native notifications
- Settings
- Keychain token storage
- Error handling with retry/backoff
- OSS-ready repository files
- Signed/notarised release target

### Should have

- Finder right-click extension
- Bandwidth limit
- Upload mode selector
- Copy uploaded links
- Export upload report
- Recent/starred destinations
- Launch at login
- Menu bar drop zone
- Debug log export

### Could have

- Quick upload presets
- Per-folder upload rules
- Speed mini-graph
- App icon progress indicator
- File thumbnail previews
- Batch templates
- Office-to-Google Docs conversion setting

### Not in V1

- Full Drive sync
- Other cloud providers
- Team admin console
- Permission sharing management
- Web dashboard
- Windows/Linux support

---

## 25. Recommended App Architecture

### Major modules

1. **App Shell**
   - Window management
   - Menu bar app
   - Global app state

2. **Authentication Module**
   - OAuth flow
   - Token refresh
   - Keychain storage
   - Account management

3. **Drive API Module**
   - Folder listing
   - Folder creation
   - File metadata
   - Upload initiation
   - Shared Drive support
   - Error mapping

4. **Upload Engine**
   - Queue scheduler
   - Parallel workers
   - Resumable sessions
   - Pause/resume/cancel
   - Retry/backoff
   - Speed tracking

5. **Local Persistence**
   - Queue state
   - Upload sessions
   - History
   - Settings
   - Account references without secrets

6. **File Access Module**
   - Drag/drop handling
   - Security-scoped bookmarks
   - Folder scanning
   - MIME detection
   - Local file validation

7. **UI Module**
   - Main window
   - Destination picker
   - Queue list
   - Inspector
   - Settings
   - Onboarding

8. **Notification Module**
   - Local notifications
   - Menu bar status
   - User alerts

9. **Diagnostics Module**
   - Logs
   - Error reports
   - Export debug bundle

---

## 26. Data Safety Behaviour

### If app quits during upload

- Save queue state
- Save resumable session state where valid
- Stop cleanly if possible
- On next launch, show recovery screen or resume based on settings

### If Mac sleeps

- Detect interruption on wake
- Mark active uploads as interrupted
- Resume safely
- Do not duplicate completed files

### If internet drops

- Pause/retry automatically
- Keep queue visible
- Do not spam notifications

### If token expires

- Refresh silently if possible
- If refresh fails, pause affected account’s uploads
- Ask user to reconnect

### If user removes local file

- Mark item as local file missing
- Do not silently skip without recording

### If destination disappears

- Pause affected uploads
- Ask user to choose new destination or retry after access restored

---

## 27. UX Copy Direction

Tone should be calm, clear, and useful.

Avoid technical panic.

Good:

- “Upload paused. Waiting for your connection to return.”
- “This account needs to be reconnected before uploads can continue.”
- “Some files uploaded successfully. 3 files need attention.”
- “Google is slowing requests, so DriveDock is retrying safely.”

Bad:

- “Fatal API error.”
- “403 userRateLimitExceeded.”
- “Upload failed.” with no next action
- “Unknown error occurred.” as the only message

---

## 28. Success Metrics

### Product success

- User can complete first upload in under 60 seconds after installing
- Large upload can recover after network interruption
- Folder upload preserves structure correctly
- Multi-account upload is understandable
- Failed uploads are recoverable without restarting everything
- App feels native and light

### Technical success

- Stable memory usage during huge files
- Queue does not corrupt after restart
- Resumable uploads recover where Google session remains valid
- Rate limits reduce concurrency instead of repeatedly failing
- Tokens are never stored outside Keychain
- UI remains responsive during folder scanning and uploads

---

## 29. Future Roadmap

### V1.1

- Finder extension polish
- More upload presets
- Better duplicate comparison
- Improved report export
- More Shared Drive features
- Auto-update support if not shipped in V1

### V1.2

- Scheduled uploads
- Watch folders
- Upload rules
- Bandwidth schedules
- Apple Shortcuts support

### V2

- Other cloud providers as optional plugins
- Team presets
- End-to-end upload audit reports
- CLI companion
- Advanced automation

Only move into these after V1 is stable.

---

## 30. Final Build Standard

DriveDock should be judged against this standard:

- Does it feel native on Mac?
- Can a non-technical user upload files without confusion?
- Can a power user trust it for large folder uploads?
- Does it recover from real-world failures?
- Is account management clear and safe?
- Does it respect Google API limits?
- Does it avoid unnecessary complexity?
- Does it look premium enough to be memorable?
- Is the OSS repo credible enough for developers to trust?

If the answer is yes, DriveDock can become the best focused Google Drive uploader for macOS.

---

## Implementation Notes for AI/Agent Developers

- Use the latest stable macOS, Swift, SwiftUI, and Google Drive API documentation at implementation time.
- Do not invent deprecated Google API flows.
- Do not use embedded web views for Google login.
- Do not store secrets in app config files.
- Do not sacrifice upload correctness for fake speed.
- Do not build full sync in V1.
- Keep the UI simple but make the upload engine serious.
- Prefer clear user-facing behaviour over hidden magic.
- Build the upload engine with testability from the beginning.
- Treat sleep/wake, token refresh, network loss, and API limits as normal product flows.

---

## Reference Notes

This spec is based on current product requirements and current best-practice direction from Apple macOS app development patterns, Google Drive API upload guidance, Google OAuth native app guidance, macOS Keychain storage, and Google API quota/backoff guidance. Implementation must still verify latest official documentation before final code decisions.
