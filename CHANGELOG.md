# Changelog

## v1.2-build.3 — 2026-09-28

- Shares the captured photo with the invitation "Try the PenFinger app out and draw
  with your fingers!" and the verified App Store URL https://apps.apple.com/app/id6757021735.
- Shows a green checkmark and **Photo sent** after WhatsApp or another messaging
  activity reports successful completion. Saving, copying, printing, and other
  sharing activities receive action-specific confirmation text.
- Cancelling a share shows no success message. Sharing errors offer a retry;
  previous confirmation is cleared when starting another share.
- Retains the image-only behavior for Save Image, Copy, Print, and Assign to Contact.
- Presents the native share sheet from the Share button, including a photo thumbnail
  and an anchored popover where supported.
- Records this version separately while preserving all earlier source releases.

Validation: unsigned iOS Release build succeeded with Xcode 26.6 (17F113). Seven
unit tests passed, covering image composition, share contents, and successful,
cancelled, and failed activity results. iPhone simulator UI checks passed for
capture, sharing, green save confirmation, cancellation, clearing/retaking, and
capture-error recovery with a synthetic camera image. The full photo-sharing flow,
including saving, green confirmation, cancellation, and retaking, also passed on
an iPad simulator after a clean rebuild. Simulator validation used iOS 26.5.

The confirmation reflects the sharing app's completion callback; it cannot verify
recipient delivery or read status. WhatsApp's handling of the image and accompanying
text requires physical-device validation with WhatsApp installed.

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
