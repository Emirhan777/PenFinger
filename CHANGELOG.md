# Changelog

## v1.0-build.1 — 2026-09-27

Initial archived source snapshot of app version **1.0**, build **1**.

- Live camera preview with on-device index fingertip tracking using Apple Vision.
- Black drawing overlay following the fingertip, with a 3,000-point limit.
- **Clean** button to clear the drawing.
- Existing app icon, Xcode project, entitlements, and template tests preserved.
- iOS deployment target: 18.5.
- Existing GitHub Pages support and privacy pages and both Git histories retained.
- Added repository documentation and ignore rules for local/generated files.

No app source, asset, or build-setting changes were made for this backup. The
snapshot date is the backup date, not an asserted App Store release date.

Validation: an unsigned iOS Release build succeeded with Xcode 26.6 (17F113).
Hashes of all 12 original shared project files were checked against the local
snapshot. Live camera/finger tracking was not tested on a physical device during
this backup; the existing tests are templates and do not validate tracking.
