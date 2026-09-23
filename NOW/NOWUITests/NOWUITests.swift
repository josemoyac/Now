//
//  NOWUITests.swift
//  NOWUITests
//
//  Created by Jose Moya Carrasco on 9/21/26.
//

import XCTest

final class NOWUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launchEnvironment["NOW_API_URL"] = "http://127.0.0.1:4000"
        app.launchEnvironment["NOW_UI_TEST_RESET"] = "1"
        app.launch()
        XCTAssertTrue(app.staticTexts["NOW."].waitForExistence(timeout: 5))
        let firstNow = app.buttons["Probar mi primer NOW ↗"]
        XCTAssertTrue(firstNow.exists)
        firstNow.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "¿Qué te apetece, José?")).firstMatch.waitForExistence(timeout: 10))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
