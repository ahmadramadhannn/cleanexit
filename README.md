# CleanExit

> **Leave the computer like you were never here.**

CleanExit is a Flutter desktop app (Windows + Linux) for anyone who uses
computers that aren't theirs — school labs, office hot-desks, a friend's
laptop. It tracks everything a session produced, then helps you keep what
you actually want and make the rest disappear: files **and** website
logins.

## What it does

### Files
- **Watched session (live):** start CleanExit before you begin, optionally
  with a timer (15 min / 30 min / 1 h / custom / "until I stop"). While you
  work, it records every file that is downloaded, pasted or created in your
  monitored folders. When you stop — or the timer ends — you get the
  keep-or-clean review.
- **Retroactive scan:** forgot to start the watcher? Pick a time range
  ("last 30 minutes", "today so far", or a custom range) and CleanExit
  finds everything whose timestamps fall inside it.
- **Review screen:** search, filter by folder/origin, tick the keepers,
  then choose per run what happens to the rest:
  - **Recycle Bin** — recoverable until the bin is emptied (Windows
    Recycle Bin / XDG Trash on Linux),
  - **Vault** — CleanExit hides the files in its own vault; restore them
    any time from the History tab,
  - **Shred** — overwrite with zeroes, then delete. No undo.
- Safety rails: a folder that contains a kept file is skipped
  automatically; CleanExit's own folders are never scanned.

### Browser accounts (Chromium family)
After the file review, an optional step scans **Chrome, Brave, Vivaldi and
Opera** profiles for websites with activity in your session range (cookie
creations/last-access + history visits), and can:

- **log sites out** by deleting *all* cookies for the selected domains
  (that is what actually ends a session), and/or
- **clear history** — visits, searches and downloads inside the range.

Every browser database is **backed up into the vault before any change**,
and the browser must be fully closed first (CleanExit detects running
browsers and blocks until you quit them).

### Signed-in account monitor (new)
Browsers remember who is logged in — in the very preference files they own.
CleanExit reads those files and **detects, records and monitors every
account signed into a browser on the machine**:

- Chromium family via `Local State → profile.info_cache` and per-profile
  `Preferences → account_info` (the files Chrome itself calls "user
  preferences"),
- Firefox Sync via `profiles.ini` + `signedInUser.json` (including
  flatpak/snap installs).

The **Accounts tab** shows who is signed in right now and who was seen
before (with first/last-seen dates — the record survives sign-outs), and
can **log every website out of a profile in one click** (vault-backed
cookie wipe). The dashboard shows a warning banner whenever accounts are
still signed in. Password stores are never touched.

### Trash browser (new)
The **Trash tab** opens the operating system's own trash — the XDG Trash
(`~/.local/share/Trash`) on Linux and the Recycle Bin on Windows (Shell
COM via PowerShell). You can see every deleted item with its original
location and deletion date, **restore** items to where they came from,
delete single items **for good**, or **empty the whole trash**. Files
cleaned with the "Recycle Bin" disposal method land here too.

> Edge and Firefox *cleanup* are intentionally out of v1 per project scope
> (Firefox accounts are detected and recorded; its cookie schema differs),
> but the engine is list-driven — see *Extending* below.

## Architecture (MVVM + BLoC)

```
View (screens/widgets)          — lib/presentation/screens, widgets
ViewModel (Cubit per screen)    — lib/presentation/viewmodels
Model (services + repositories) — lib/data/services, lib/data/models
Platform/DI                     — lib/core, lib/di.dart
```

- `SessionCubit` drives the flow: idle → watching/scanning → reviewing →
  browser step → done.
- The scanner runs in a background isolate; the live watcher uses
  recursive directory streams; both feed the same review model
  (`TrackedFile`).
- Persistence is plain JSON (one file per session, `settings.json`,
  `manifest.json` per vault session) — no database of your own data.
- Chromium databases are read/written through `package:sqlite3`, bundled
  by `sqlite3_flutter_libs`.

## Build & run

Requirements: [Flutter SDK](https://docs.flutter.dev/get-started/install)
3.24+ (developed on 3.47 stable), Windows 10/11 or Linux with GTK 3 dev
packages (`libgtk-3-dev`, `ninja-build`, `cmake`, `clang` on Ubuntu/Debian).

```bash
git clone <this-repo> cleanexit && cd cleanexit
flutter pub get

# run on your desktop
flutter run -d windows     # or: flutter run -d linux

# release builds
flutter build windows      # → build/windows/x64/runner/Release/
flutter build linux --release   # → build/linux/x64/release/bundle/
```

The `windows/` and `linux/` platform runners are committed, so no
`flutter create .` is needed.

## Tests & analysis

```bash
flutter analyze   # zero issues
flutter test      # 26 unit tests (pure logic + file-level IO)
```

## Layout

```
lib/
├── main.dart / app.dart          entry + providers + theme
├── di.dart                       service locator (Model layer wiring)
├── core/                         theme, constants (paths, browser defs), utils
├── data/
│   ├── models/                   TrackedFile, SessionRecord, BrowserAccount, …
│   └── services/
│       ├── file_scanner_service.dart     retro range scan (isolate)
│       ├── file_watcher_service.dart     live session watcher
│       ├── disposal_service.dart         recycle / vault / shred
│       ├── vault_service.dart            quarantine + restore + manifest
│       ├── browser_detector.dart         installed Chromium browsers
│       ├── chromium_cleanup_service.dart cookie/history scan + purge
│       ├── browser_account_service.dart  signed-in account detection
│       ├── browser_account_store.dart    account first/last-seen record
│       ├── os_trash_service.dart         XDG trash / Recycle Bin browser
│       └── session_store.dart            session history persistence
└── presentation/
    ├── viewmodels/               Session/Review/Browser/Accounts/Trash/
    │                             History/Settings cubits
    └── screens/                  shell, dashboard, live, review, browser,
                                  accounts, trash, history, settings
```

## Extending

- **Add a browser:** append a `BrowserDef` to `CeConstants.browsers` —
  detector, scanner and cleaner pick it up automatically (any
  Chromium-based browser with the standard `User Data` layout works).
- **Firefox support** needs a second engine (its own `cookies.sqlite` /
  `places.sqlite` schema) — planned.
- **Installed-apps module** (detect apps launched in the session, clear
  their recents) is the next roadmap item.

## Honest limitations (v1)

- "Shred" is a single zero-pass wipe; guaranteed erasure on SSDs/F2FS is
  out of scope for any app — use disk-encryption for that.
- Local Storage / IndexedDB are not purged (cookies are what keep you
  logged in for the vast majority of sites; the DB backup covers the rest).
- Windows "Recent items" jump lists are not scanned in v1; the scanner
  covers real files in monitored folders.

## Changelog

- **1.1.0** — signed-in browser-account monitoring (detect, record over
  time, one-click "log out all sites" per profile, dashboard warning
  banner), OS trash browser (list / restore / delete forever / empty for
  XDG Trash + Windows Recycle Bin), Nord frost theme, and a batch of
  hardening fixes around session removal and file deletion (vanished
  files no longer produce cleanup errors, no more emit-after-close
  crashes, delete-record confirmation, vault cleanup on record delete).
- **1.0.0** — first working version: hybrid tracking (live watch +
  retroactive scan), keep-or-clean review, recycle/vault/shred disposal,
  Chromium account cleanup with vault backups, session history, settings.
