//
//  QuickIconsUITests.swift
//  QuickIconsUITests
//
//  Disabled: these tests launch XCUIApplication which steals focus during
//  local development. Re-enable when ready for full UI automation.
//

import XCTest

final class QuickIconsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

//    @MainActor
//    func testExample() throws {
//        let app = XCUIApplication()
//        app.launch()
//    }
//
//    @MainActor
//    func testLaunchPerformance() throws {
//        measure(metrics: [XCTApplicationLaunchMetric()]) {
//            XCUIApplication().launch()
//        }
//    }
}
