import XCTest
import AndroidHelper_macOS
@testable import AndroidHelper_macOS

class ParseModules_Tests: XCTestCase {
    func testParseModules() {
        let input = gradleTasksSampleOutput
        let result = parseInstallableModules(fromString: input)
        let expected = [
            Module(name: "app",
                   buildVariants: ["AmazonLeanbackDebug", "AmazonLeanbackDev", "AmazonLeanbackRelease", "AmazonMobileDebug", "AmazonMobileDev", "AmazonMobileRelease", "LeanbackDebug", "LeanbackDev", "LeanbackRelease", "MobileDebug", "MobileDev", "MobileRelease", "OculusLeanbackRelease", "PortalLeanbackDebug", "PortalLeanbackDev", "PortalLeanbackRelease"]),
            Module(name: "app-leanback",
                   buildVariants: ["AmazonDebug", "AmazonRelease", "GoogleDebug", "GoogleRelease"]),
            Module(name: "app-mobile",
                   buildVariants: ["AmazonDebug", "AmazonRelease", "GoogleDebug", "GoogleRelease"])
        ]
        XCTAssertEqual(result, expected)
    }
}
