# Changelog

## [0.1.1] - 2026-05-03

### Features
- **Sidebar Update Badge**: Visual indicator for content updates with auto-scroll to the latest item.
- **In-App Update Check**: Check for new releases, download updates, and platform-specific install support.
- **Settings Update UI**: Update check preview interface in settings with mock data support.
- **Android FileProvider**: Added FileProvider paths for APK installation on Android.

### Fixes
- Resolved test failures related to pending timers, uppercase label assertions, and analyze errors.

### Build
- **Windows Installer**: Replaced MSIX with Inno Setup EXE installer.
- **Release Artifacts**: Renamed artifacts to include app name and version (e.g., `TheArchivist-v0.1.1-setup.exe`).
- **CI Workflow**: Aligned Flutter version with local environment; streamlined build matrix (web removed, Android 64-bit only).

## [0.1.0] - 2026-04-29

### Features
- **Dark Theme**: Complete dark UI with mint accent (#5EEAD4) for comfortable long sessions.
- **Home Dashboard**: Personalized media overview with recently updated and in-progress sections.
- **Library Grid**: Responsive poster grid for browsing your entire media collection.
- **Lists with Poster Mosaic**: Custom collections organized in visually rich 2x2 poster mosaic cards.
- **Media Detail Page**: Rich detail view with metadata, progress tracking, and quick actions.
- **Bangumi Integration**: Connect your Bangumi account to sync watch/read progress.
- **Cloud Sync**: Backup and sync library data via S3-compatible storage.
- **Page Transitions**: Smooth animated transitions between pages.

### Platforms
- Windows (primary)
- Android (64-bit)
