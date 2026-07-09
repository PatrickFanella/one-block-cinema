//
//  OneBlockCinemaUITests.swift
//  OneBlockCinemaUITests
//
//  Created by Rork on March 7, 2026.
//

import XCTest

final class OneBlockCinemaUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsOfflineTemplateCatalog() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["home.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["template.first-block-story"].exists)
        XCTAssertTrue(app.buttons["template.before-and-after-transformation"].exists)
    }

    @MainActor
    func testAccessibilityTextSizeKeepsTemplateActionReachable() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()

        let firstTemplate = app.buttons["template.first-block-story"]
        XCTAssertTrue(firstTemplate.waitForExistence(timeout: 5))
        XCTAssertTrue(firstTemplate.isHittable)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
