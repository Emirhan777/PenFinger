# Changelog

## v1.1-build.2 — 2026-09-27

- Added a photo button at the bottom right of the drawing screen.
- Captures a still photo with the drawing as it appeared when the button was tapped,
  cropped and oriented to match the camera preview. Controls are excluded.
- Opens a photo preview with **Share** and **Done**; the system share sheet also
  offers saving the photo to the user's library.
- Handles camera permission, unavailable cameras, and photo capture errors.
- Freezes the drawing while taking or previewing a photo.
- Uses preview-layer coordinate conversion so finger positions account for camera
  cropping and rotation, and stops the camera while the app is inactive.
- Added image composition and simulator UI tests, and updated permission text and
  privacy pages to describe user-initiated capture, saving, and sharing.

Validation: unsigned iOS Release build succeeded with Xcode 26.6 (17F113).
Four image-composition tests passed on iOS 26.5 and iOS 18.5 simulators. Both iPhone
UI tests passed, covering capture, preview, sharing, Save Image, dismissal,
clearing/retaking, and capture-error recovery with a synthetic camera image.
Live camera alignment, capture, and permissions still require physical-device
validation before an App Store submission. iPad UI testing was not completed.

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
