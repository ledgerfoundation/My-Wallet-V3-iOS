//
//  MnemonicTextViewTests.swift
//  PlatformUIKitTests
//
//  Created by AlexM on 10/18/19.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

@testable import PlatformUIKit
import RxBlocking
import RxSwift
import XCTest

final class MnemonicTextViewTests: XCTestCase {

    private var validator: MnemonicValidator!

    override func setUp() {
        super.setUp()
        validator = MnemonicValidator(words: Set(WordList.words))
    }

    override func tearDown() {
        super.tearDown()
        validator = nil
    }

    func testValidMnemonic() {
        validator.valueRelay.accept("client cruel tiny sniff girl crawl snap spice forum talk evidence tourist")
        do {
            guard let result = try validator.score.toBlocking().first() else {
                XCTFail("Expected a MnemonicValidationScore")
                return
            }
            XCTAssertEqual(result, .complete)
        } catch {
            XCTFail("Expected a MnemonicValidationScore")
        }
    }

    func testDuplicateWords() {
        validator.valueRelay.accept("client client tiny possible possible possible snap spice spice spice spice tourist")
        do {
            guard let result = try validator.score.toBlocking().first() else {
                XCTFail("Expected a MnemonicValidationScore")
                return
            }
            XCTAssertEqual(result, .complete)
        } catch {
            XCTFail("Expected a MnemonicValidationScore")
        }
    }

    func testIncompleteMnemonic() {
        validator.valueRelay.accept("client cruel tiny sniff girl crawl snap spice forum talk evidence")
        do {
            guard let result = try validator.score.toBlocking().first() else {
                XCTFail("Expected a MnemonicValidationScore")
                return
            }
            XCTAssertEqual(result, .incomplete)
        } catch {
            XCTFail("Expected a MnemonicValidationScore")
        }
    }

    func testInvalidMnemonic() {
        validator.valueRelay.accept("meow cruel tiny meow girl crawl snap spice forum talk evidence")
        do {
            guard let result = try validator.score.toBlocking().first() else {
                XCTFail("Expected a MnemonicValidationScore")
                return
            }
            let first = NSRange(location: 0, length: 4)
            let second = NSRange(location: 16, length: 4)
            XCTAssertEqual(result, .invalid([first, second]))
        } catch {
            XCTFail("Expected a MnemonicValidationScore")
        }
    }
}

private enum WordList {
    public static var words: [String] {
        "client cruel tiny sniff girl crawl snap spice forum talk evidence tourist possible"
        .components(separatedBy: " ")
    }
}

