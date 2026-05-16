//
//  EasingTests.swift
//  CreativeDrawingTests
//
//  Tests for Easing functions
//

import XCTest
@testable import Little_Canvas

final class EasingTests: XCTestCase {

    // MARK: - Linear Tests

    func testLinearAtZero() {
        XCTAssertEqual(Easing.linear(0), 0)
    }

    func testLinearAtOne() {
        XCTAssertEqual(Easing.linear(1), 1)
    }

    func testLinearAtHalf() {
        XCTAssertEqual(Easing.linear(0.5), 0.5)
    }

    // MARK: - Ease In Tests

    func testEaseInAtZero() {
        XCTAssertEqual(Easing.easeIn(0), 0)
    }

    func testEaseInAtOne() {
        XCTAssertEqual(Easing.easeIn(1), 1)
    }

    func testEaseInSlowerThanLinearAtHalf() {
        let eased = Easing.easeIn(0.5)
        let linear = Easing.linear(0.5)
        XCTAssertLessThan(eased, linear)
    }

    // MARK: - Ease Out Tests

    func testEaseOutAtZero() {
        XCTAssertEqual(Easing.easeOut(0), 0)
    }

    func testEaseOutAtOne() {
        XCTAssertEqual(Easing.easeOut(1), 1)
    }

    func testEaseOutFasterThanLinearAtHalf() {
        let eased = Easing.easeOut(0.5)
        let linear = Easing.linear(0.5)
        XCTAssertGreaterThan(eased, linear)
    }

    // MARK: - Ease In Out Tests

    func testEaseInOutAtZero() {
        XCTAssertEqual(Easing.easeInOut(0), 0)
    }

    func testEaseInOutAtOne() {
        XCTAssertEqual(Easing.easeInOut(1), 1)
    }

    func testEaseInOutAtHalf() {
        XCTAssertEqual(Easing.easeInOut(0.5), 0.5, accuracy: 0.001)
    }

    func testEaseInOutSymmetric() {
        let firstQuarter = Easing.easeInOut(0.25)
        let thirdQuarter = Easing.easeInOut(0.75)
        XCTAssertEqual(firstQuarter + thirdQuarter, 1.0, accuracy: 0.001)
    }

    // MARK: - Cubic Ease In Tests

    func testEaseInCubicAtZero() {
        XCTAssertEqual(Easing.easeInCubic(0), 0)
    }

    func testEaseInCubicAtOne() {
        XCTAssertEqual(Easing.easeInCubic(1), 1)
    }

    func testEaseInCubicSlowerThanEaseIn() {
        let cubic = Easing.easeInCubic(0.5)
        let quadratic = Easing.easeIn(0.5)
        XCTAssertLessThan(cubic, quadratic)
    }

    // MARK: - Cubic Ease Out Tests

    func testEaseOutCubicAtZero() {
        XCTAssertEqual(Easing.easeOutCubic(0), 0)
    }

    func testEaseOutCubicAtOne() {
        XCTAssertEqual(Easing.easeOutCubic(1), 1)
    }

    func testEaseOutCubicFasterThanEaseOut() {
        let cubic = Easing.easeOutCubic(0.5)
        let quadratic = Easing.easeOut(0.5)
        XCTAssertGreaterThan(cubic, quadratic)
    }

    // MARK: - Cubic Ease In Out Tests

    func testEaseInOutCubicAtZero() {
        XCTAssertEqual(Easing.easeInOutCubic(0), 0)
    }

    func testEaseInOutCubicAtOne() {
        XCTAssertEqual(Easing.easeInOutCubic(1), 1)
    }

    func testEaseInOutCubicAtHalf() {
        XCTAssertEqual(Easing.easeInOutCubic(0.5), 0.5, accuracy: 0.001)
    }

    // MARK: - Elastic Out Tests

    func testElasticOutAtZero() {
        XCTAssertEqual(Easing.elasticOut(0), 0, accuracy: 0.01)
    }

    func testElasticOutAtOne() {
        XCTAssertEqual(Easing.elasticOut(1), 1, accuracy: 0.001)
    }

    func testElasticOutOvershoots() {
        // Elastic easing should overshoot 1.0 at some point
        var foundOvershoot = false
        for i in stride(from: 0.0, through: 1.0, by: 0.01) {
            let value = Easing.elasticOut(CGFloat(i))
            if value > 1.0 {
                foundOvershoot = true
                break
            }
        }
        XCTAssertTrue(foundOvershoot)
    }

    // MARK: - Back Out Tests

    func testBackOutAtZero() {
        XCTAssertEqual(Easing.backOut(0), 0, accuracy: 0.001)
    }

    func testBackOutAtOne() {
        XCTAssertEqual(Easing.backOut(1), 1, accuracy: 0.001)
    }

    func testBackOutOvershoots() {
        // Back easing should overshoot 1.0 at some point
        var foundOvershoot = false
        for i in stride(from: 0.0, through: 1.0, by: 0.01) {
            let value = Easing.backOut(CGFloat(i))
            if value > 1.0 {
                foundOvershoot = true
                break
            }
        }
        XCTAssertTrue(foundOvershoot)
    }

    // MARK: - Range Tests

    func testAllEasingFunctionsHaveValidRange() {
        let easingFunctions: [(String, (CGFloat) -> CGFloat)] = [
            ("linear", Easing.linear),
            ("easeIn", Easing.easeIn),
            ("easeOut", Easing.easeOut),
            ("easeInOut", Easing.easeInOut),
            ("easeInCubic", Easing.easeInCubic),
            ("easeOutCubic", Easing.easeOutCubic),
            ("easeInOutCubic", Easing.easeInOutCubic)
        ]

        for (name, fn) in easingFunctions {
            // Test at boundaries
            XCTAssertEqual(fn(0), 0, accuracy: 0.001, "\(name) should return 0 at t=0")
            XCTAssertEqual(fn(1), 1, accuracy: 0.001, "\(name) should return 1 at t=1")

            // Test middle range is within [0, 1] for non-bouncy functions
            for t in stride(from: 0.0, through: 1.0, by: 0.1) {
                let value = fn(CGFloat(t))
                XCTAssertGreaterThanOrEqual(value, 0, "\(name) should be >= 0 at t=\(t)")
                XCTAssertLessThanOrEqual(value, 1, "\(name) should be <= 1 at t=\(t)")
            }
        }
    }
}
