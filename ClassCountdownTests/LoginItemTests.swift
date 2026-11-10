import XCTest
@testable import ClassCountdown

// Checks when ClassCountdown switches "start at login" on by itself.
final class LoginItemTests: XCTestCase {

    // Only an installed copy does it, and only the first time it runs.
    func testInstalledCopyEnablesItselfOnce() {
        XCTAssertTrue(LoginItem.shouldEnableAutomatically(bundlePath: "/Applications/ClassCountdown.app", alreadyDone: false))
        XCTAssertTrue(LoginItem.shouldEnableAutomatically(bundlePath: "/Users/someone/Applications/ClassCountdown.app", alreadyDone: false))
        XCTAssertFalse(LoginItem.shouldEnableAutomatically(bundlePath: "/Applications/ClassCountdown.app", alreadyDone: true))
    }

    // A copy in a build folder (Xcode, tests) must never add itself to the login items.
    func testBuildFolderCopyNeverEnablesItself() {
        let path = "/Users/someone/Developer/class-countdown/build/Build/Products/Debug/ClassCountdown.app"
        XCTAssertFalse(LoginItem.shouldEnableAutomatically(bundlePath: path, alreadyDone: false))
    }
}
