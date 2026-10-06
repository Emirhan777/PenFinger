# PenFinger

An iOS app for writing and drawing in the air with your index finger. The camera
preview is overlaid with a line that follows the detected index fingertip. Draw
with an open hand, a pointing finger, or any other pose except a clenched fist.
Close your hand into a fist to pause without clearing the drawing; opening it
again starts a separate stroke. Losing hand tracking also ends the current
stroke. Drawing continues while the index fingertip is tracked, even if the
wrist or lower palm is outside the camera frame. Fist detection pauses drawing
only when the wrist and all four curled fingers can be recognized. Tap the
colored circle at the bottom left to choose from eight colored swatches: black, white, red,
orange, yellow, green, blue, or purple. The selected swatch has a checkmark.
The palette opens and closes immediately; tapping the colored circle again
closes it. Clean and the camera button work on the first tap while it is open.
New strokes use that color; earlier strokes keep theirs. Tap **Clean**
to clear the drawing while keeping your selected color. Tap the camera button at
the bottom right to take a photo with the colored drawing and automatically
save it to Photos. The first save requests permission to add photos. The preview
shows **Saved to Photos** after saving succeeds, or a message if saving fails;
you can still share the photo if saving is unavailable. The preview offers
**Share** (including **Save Image**) and **Done** to return to drawing.

Sharing includes the photo and this invitation with
[PenFinger's App Store link](https://apps.apple.com/app/id6757021735):
"Try the PenFinger app out and draw with your fingers!"
After the selected activity reports success, a green confirmation appears. Messaging
activities, including WhatsApp, show **Photo sent**; saving shows **Photo saved**.
Cancelling does not show a success message. This confirms the sharing activity
completed, not that the recipient received or read the message. Receiving apps
control how they handle the image and accompanying text.

## Saved versions

| GitHub release | App version | Build | Snapshot date |
| --- | --- | --- | --- |
| [v1.3-build.4](https://github.com/Emirhan777/PenFinger/releases/tag/v1.3-build.4) | 1.3 | 4 | 2026-10-06 |
| [v1.2-build.3](https://github.com/Emirhan777/PenFinger/releases/tag/v1.2-build.3) | 1.2 | 3 | 2026-09-28 |
| [v1.1-build.2](https://github.com/Emirhan777/PenFinger/releases/tag/v1.1-build.2) | 1.1 | 2 | 2026-09-27 |
| [v1.0-build.1](https://github.com/Emirhan777/PenFinger/releases/tag/v1.0-build.1) | 1.0 | 1 | 2026-09-27 |

Each release has a dedicated Git tag and downloadable source archives. Future
development continues on `main`; existing release tags must not be moved or
deleted. See [CHANGELOG.md](CHANGELOG.md) for the contents of each version.

The first release, `v1.0-build.1`, preserves the original local app source, assets, tests, and Xcode
project settings as found on the snapshot date. It also retains the earlier
local Git history and the existing website history. It is a source backup;
correspondence with any App Store binary has not been verified. Signed app
binaries, signing credentials, build products, and local Xcode user settings are
not included in the release source tree.

## Code overview

- `PenFinger/PenFingerApp.swift` opens the SwiftUI `ContentView`.
- `PenFinger/ContentView.swift` contains the camera preview, drawing canvas, and controls.
- `PenFinger/Drawing.swift` stores colored strokes and the selected ink color.
- `PenFinger/HandDrawingGesture.swift` checks finger bends and positions to pause
  on a clenched fist. It accounts for camera aspect ratio and hand roll,
  and allows drawing with a cropped palm. It pauses only when a fist is detected
  or the fingertip cannot be tracked.
- `PenFinger/CameraController.swift` manages the camera session, hand tracking,
  and still photo capture. AVFoundation delivers camera frames to Vision's
  `VNDetectHumanHandPoseRequest`. Outside a closed fist, index fingertip observations
  above 0.6 confidence are converted to screen coordinates and drawn as a
  4-point-wide line in the selected color (black by default).
  The app retains at most 3,000 drawing points in memory.
- `PenFinger/PhotoRenderer.swift` crops the photo to match the preview and composites
  the drawing captured at the moment the photo button was tapped.
- `PenFinger/PhotoLibrarySaver.swift` requests add-only Photos access and saves
  each completed capture asynchronously.
- `PenFinger/PhotoPreview.swift` displays the result and presents the iOS share sheet.
- `PenFinger/PhotoSharing.swift` presents the native share sheet, supplies the photo
  and invitation, and interprets the system sharing completion callback.
- `PenFinger/Assets.xcassets` contains the app icon and color assets.
- `PenFingerTests` checks open/closed-hand gestures, cropped hands, tracking loss, stroke breaks,
  ink colors, photo cropping, orientation, drawing placement, share contents,
  and success/cancellation/failure outcomes.
  `PenFingerUITests` checks color selection, capture, preview, sharing, retaking, and capture failures
  using a synthetic camera image available only in Debug simulator builds.
- `index.html` and `privacy.html` are the existing GitHub Pages support and privacy
  pages.

Camera processing and photo composition happen on the device. Each captured
photo with its drawing is automatically saved to Photos when permission allows.
The preview remains in memory until dismissed. Sharing happens when the user
chooses an action in the system share sheet. The app makes no network requests.

## Open and build

Open `PenFinger.xcodeproj` in Xcode and select the **PenFinger** scheme with an iOS
destination. The current iOS deployment target is **18.5**. Use a physical iPhone
or iPad with camera permission to exercise finger tracking; configure your Apple
development team for device signing as needed. Although the project also lists
other platforms, this snapshot's camera implementation uses UIKit.

Live camera capture, permission prompts, and drawing alignment should also be
checked on a physical iPhone/iPad before an App Store submission.
WhatsApp's handling of the photo and invitation must also be checked on a physical
device with WhatsApp installed; its extension is unavailable in the simulator.

To check an unsigned iOS Release build:

```sh
xcodebuild -project PenFinger.xcodeproj -scheme PenFinger \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/PenFinger-build CODE_SIGNING_ALLOWED=NO build
```

## Retrieve an older version

Open its [GitHub release](https://github.com/Emirhan777/PenFinger/releases) and
download **Source code (zip)**, or clone this exact snapshot into a separate folder:

```sh
git clone --branch v1.0-build.1 https://github.com/Emirhan777/PenFinger.git PenFinger-v1.0-build.1
```

The clone checks out the saved tag. To develop from that version, create a branch
inside the cloned folder with `git switch -c restore-v1.0-build.1`.

## Save future versions

1. Make and validate the changes. Before an App Store upload, update the app's
   version/build in Xcode and add a matching changelog entry and saved-version row.
2. Review `git status` and `git diff`, stage the intended files, and commit them.
3. Create a new annotated tag using `v<app-version>-build.<build-number>` and push
   both the commit and tag. For example, for version 1.3, build 4:

   ```sh
   git tag -a v1.3-build.4 -m "PenFinger 1.3 (build 4)"
   git push --atomic origin main refs/tags/v1.3-build.4
   ```

4. Create a GitHub release for that existing tag, describe the changes and checks,
   and use `--verify-tag` if publishing with `gh release create`. GitHub provides
   source ZIP and tar archives for the tag. Keep every previous release and tag.

Commits can also save intermediate work before a new app version is ready. A
GitHub source release and an App Store submission are separate actions.
