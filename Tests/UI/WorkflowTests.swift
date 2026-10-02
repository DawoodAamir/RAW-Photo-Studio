import XCTest

@MainActor final class WorkflowTests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  func testImportAdjustAndReopen() throws {
    let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().appendingPathComponent("Fixtures/ColorChart.dng")
    let app = XCUIApplication()
    app.launchEnvironment["RAW_TEST_STORE"] = UUID().uuidString
    app.launch()
    app.activate()
    XCTAssertTrue(app.buttons["Import RAW"].waitForExistence(timeout: 15), app.debugDescription)
    app.buttons["Import RAW"].click()
    app.typeKey("g", modifierFlags: [.command, .shift])
    let path = app.textFields["PathTextField"]
    XCTAssertTrue(path.waitForExistence(timeout: 5), app.debugDescription)
    path.click()
    path.typeText(fixture.path)
    app.typeKey(.return, modifierFlags: [])
    let open = app.sheets["open-panel"].buttons["OKButton"]
    XCTAssertTrue(open.waitForExistence(timeout: 5), app.debugDescription)
    open.click()
    let exposure = app.sliders["Exposure"]
    XCTAssertTrue(exposure.waitForExistence(timeout: 20), app.debugDescription)
    exposure.click()
    exposure.typeKey(.rightArrow, modifierFlags: [])
    XCTAssertTrue(
      app.staticTexts["Unsaved changes"].waitForExistence(timeout: 5), app.debugDescription)
    app.buttons["Save adjustments"].click()
    XCTAssertTrue(app.staticTexts["Saved"].waitForExistence(timeout: 10), app.debugDescription)
    let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
    attachment.name = "RAW adjustments"
    attachment.lifetime = .keepAlways
    add(attachment)
    app.terminate()
    app.launch()
    app.activate()
    let row = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "raw-project-")
    ).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 15), app.debugDescription)
    row.click()
    XCTAssertTrue(app.staticTexts["Saved"].waitForExistence(timeout: 10), app.debugDescription)
    XCTAssertTrue(app.buttons["Reset adjustments"].exists)
  }
}
