import XCTest

final class PenFingerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCapturePreviewShareAndRetake() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-camera"]
        app.launch()

        let shutter = app.buttons["takePhotoButton"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 10))
        XCTAssertTrue(shutter.isEnabled)
        XCTAssertGreaterThan(shutter.frame.midX, app.frame.midX)
        XCTAssertGreaterThan(shutter.frame.midY, app.frame.height * 0.7)
        attachScreenshot(app, name: "Camera controls")
        shutter.tap()
        XCTAssertTrue(app.images["capturedPhoto"].waitForExistence(timeout: 5))
        attachScreenshot(app, name: "Photo preview with drawing")
        let share = app.buttons["sharePhotoButton"]
        XCTAssertTrue(share.exists)
        share.tap()
        // An image is handed to the system share sheet, which offers Save Image.
        let save = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Save Image")).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 30))
        attachScreenshot(app, name: "Photo share sheet")
        save.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(shutter.waitForExistence(timeout: 5))
        app.buttons["Clean"].tap()
        shutter.tap()
        XCTAssertTrue(app.images["capturedPhoto"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
    }

    @MainActor
    func testCaptureFailureCanBeDismissedAndRetried() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-camera", "--uitest-capture-failure"]
        app.launch()
        let shutter = app.buttons["takePhotoButton"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 10))
        shutter.tap()
        XCTAssertTrue(app.alerts["Couldn't take photo"].waitForExistence(timeout: 5))
        app.alerts.buttons["OK"].tap()
        XCTAssertTrue(shutter.isEnabled)
        shutter.tap()
        XCTAssertTrue(app.alerts["Couldn't take photo"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
