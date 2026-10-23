import XCTest

@MainActor
final class WorkoutFlowTests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  func testCountdownKeepsLayoutAsDigitsChange() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing"]
    app.launch()
    app.buttons["Start session"].tap()
    let countdown = app.staticTexts["countdown"]
    XCTAssertTrue(countdown.waitForExistence(timeout: 3))
    let timerFrame = countdown.frame
    let roundFrame = app.staticTexts["roundCount"].frame
    var values = Set<String>()
    let deadline = Date().addingTimeInterval(22)
    while countdown.exists && Date() < deadline {
      let value = countdown.value as? String ?? ""
      values.insert(value)
      XCTAssertEqual(countdown.frame.minX, timerFrame.minX, accuracy: 0.5, value)
      XCTAssertEqual(countdown.frame.width, timerFrame.width, accuracy: 0.5, value)
      XCTAssertEqual(countdown.frame.height, timerFrame.height, accuracy: 0.5, value)
      XCTAssertEqual(
        app.staticTexts["roundCount"].frame.minY, roundFrame.minY, accuracy: 0.5, value)
      Thread.sleep(forTimeInterval: 0.15)
    }
    XCTAssertTrue(values.contains("00:01"))
    XCTAssertTrue(values.contains("00:02"))
    XCTAssertTrue(app.staticTexts["COMPLETE"].exists)
    capture("12 Stable countdown")
  }

  func testSessionLifecycleAndRepeat() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing"]
    app.launch()
    capture("01 Setup")
    app.buttons["Start session"].tap()
    XCTAssertTrue(app.staticTexts["GET READY"].waitForExistence(timeout: 3))
    capture("02 Preparation")
    XCTAssertTrue(app.staticTexts["ROUND"].waitForExistence(timeout: 6))
    app.buttons["Pause"].tap()
    XCTAssertTrue(app.staticTexts["PAUSED"].waitForExistence(timeout: 2))
    let remaining = app.staticTexts["countdown"].value as? String
    capture("03 Paused")
    // A paused workout must not count down while the user is elsewhere.
    XCUIDevice.shared.press(.home)
    app.activate()
    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    let resume = app.buttons["Resume"]
    let hittable = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "hittable == true"), object: resume)
    XCTAssertEqual(XCTWaiter.wait(for: [hittable], timeout: 5), .completed)
    capture("03b Returned from Home")
    XCTAssertEqual(app.staticTexts["countdown"].value as? String, remaining)
    app.buttons["Resume"].tap()
    XCTAssertTrue(app.staticTexts["ROUND"].waitForExistence(timeout: 2))
    capture("04 Round")
    XCTAssertTrue(app.staticTexts["REST"].waitForExistence(timeout: 8))
    capture("05 Rest")
    XCTAssertTrue(app.staticTexts["COMPLETE"].waitForExistence(timeout: 14))
    capture("06 Finished")
    app.buttons["Repeat"].tap()
    XCTAssertTrue(app.staticTexts["GET READY"].waitForExistence(timeout: 3))
    app.buttons["End"].tap()
    app.buttons["Keep session"].tap()
    XCTAssertTrue(app.buttons["Resume"].exists)
    app.buttons["End"].tap()
    app.buttons["End session"].tap()
    XCTAssertTrue(app.buttons["Start session"].waitForExistence(timeout: 3))
  }

  func testConfigurationSettingsAndEarlyEnd() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing"]
    app.launch()
    app.buttons["Decrease rounds"].tap()
    XCTAssertEqual(app.staticTexts["Rounds"].value as? String, "1")
    app.buttons["Increase rounds"].tap()
    app.buttons["Increase round length"].tap()
    XCTAssertEqual(app.staticTexts["Round length"].value as? String, "0:20")
    app.buttons["Decrease round length"].tap()
    app.buttons["Decrease rest length"].tap()
    XCTAssertEqual(app.staticTexts["Rest length"].value as? String, "0:00")
    app.buttons["Decrease preparation"].tap()
    XCTAssertEqual(app.staticTexts["Preparation"].value as? String, "0:00")
    app.buttons["Settings"].tap()
    XCTAssertTrue(app.buttons["Test bell"].waitForExistence(timeout: 3))
    app.buttons["Test bell"].tap()
    capture("07 Settings")
    app.buttons["Done"].tap()
    app.buttons["Start session"].tap()
    XCTAssertTrue(app.staticTexts["ROUND"].waitForExistence(timeout: 3))
    app.buttons["Settings"].tap()
    app.buttons["Done"].tap()
    XCTAssertTrue(app.staticTexts["PAUSED"].waitForExistence(timeout: 3))
    app.buttons["End"].tap()
    app.buttons["End session"].tap()
    XCTAssertTrue(app.buttons["Start session"].waitForExistence(timeout: 3))
  }

  func testRunningSessionContinuesInBackground() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing"]
    app.launch()
    app.buttons["Start session"].tap()
    XCTAssertTrue(app.staticTexts["ROUND"].waitForExistence(timeout: 8))
    XCUIDevice.shared.press(.home)
    Thread.sleep(forTimeInterval: 4)
    app.activate()
    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    XCTAssertFalse(app.staticTexts["PAUSED"].exists)
    capture("08 Background playback")
    XCTAssertTrue(app.staticTexts["COMPLETE"].waitForExistence(timeout: 15))
    app.buttons["Setup"].tap()
    XCTAssertTrue(app.buttons["Start session"].waitForExistence(timeout: 3))
  }

  func testConfigurationSurvivesRelaunch() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing"]
    app.launch()
    app.buttons["Increase rounds"].tap()
    app.buttons["Increase round length"].tap()
    app.buttons["Decrease rest length"].tap()
    app.buttons["Decrease preparation"].tap()
    app.terminate()
    // No short-workout override on the second launch: read the actual saved settings.
    app.launchArguments = []
    app.launch()
    XCTAssertEqual(app.staticTexts["Rounds"].value as? String, "3")
    XCTAssertEqual(app.staticTexts["Round length"].value as? String, "0:20")
    XCTAssertEqual(app.staticTexts["Rest length"].value as? String, "0:00")
    XCTAssertEqual(app.staticTexts["Preparation"].value as? String, "0:00")
  }

  func testDefaultWorkoutPresentation() {
    let app = XCUIApplication()
    // A malformed argument-domain value exercises the real default-loading path without
    // deleting saved settings. Start persists the chosen default workout normally.
    app.launchArguments = ["-workoutConfiguration", "reset"]
    app.launch()
    XCTAssertEqual(app.staticTexts["Rounds"].value as? String, "6")
    XCTAssertEqual(app.staticTexts["Round length"].value as? String, "3:00")
    capture("09 Default setup")
    app.buttons["Start session"].tap()
    XCTAssertTrue(app.staticTexts["GET READY"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["ROUND"].waitForExistence(timeout: 12))
    app.buttons["Pause"].tap()
    capture("10 Default paused")
    app.buttons["Resume"].tap()
    XCTAssertTrue(app.staticTexts["ROUND"].waitForExistence(timeout: 3))
    capture("11 Default round")
    app.buttons["End"].tap()
    app.buttons["End session"].tap()
  }

  private func capture(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
