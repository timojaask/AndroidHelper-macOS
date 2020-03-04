import XCTest
import AndroidHelper_macOS
@testable import AndroidHelper_macOS

extension BuildErrorParser.BuildError: Equatable {
    public static func == (lhs: BuildErrorParser.BuildError, rhs: BuildErrorParser.BuildError) -> Bool {
        return lhs.filePath == rhs.filePath &&
            lhs.lineNumber == rhs.lineNumber &&
            lhs.columnNumber == rhs.columnNumber &&
            lhs.errorMessage == rhs.errorMessage
    }
}

class ParseBuildError_Tests: XCTestCase {

    func testOneError() {
        let input = BuildErrorSampleOneError
        let result = BuildErrorParser.parseBuildErrors(fromString: input)
        let expected = [
            BuildErrorParser.BuildError(
                filePath: "/Users/timojaask/projects/temp/testAndroidApp/app/src/main/java/com/example/testandroidapp/MainActivity.kt",
                lineNumber: 12,
                columnNumber: 9,
                errorMessage: "Unresolved reference: lolbal"
            )
        ]
        XCTAssertEqual(result, expected)
    }

    func testMultipleErrors() {
        let input = BuildErrorMultipleErrors
        let result = BuildErrorParser.parseBuildErrors(fromString: input)
        let expected = [
            BuildErrorParser.BuildError(
                filePath: "/Users/timojaask/projects/temp/testAndroidApp/app/src/main/java/com/example/testandroidapp/MainActivity.kt",
                lineNumber: 12,
                columnNumber: 9,
                errorMessage: "Unresolved reference: lolbal"
            ),
            BuildErrorParser.BuildError(
                filePath: "/Users/timojaask/projects/temp/testAndroidApp/app/src/main/java/com/example/testandroidapp/MainActivity.kt",
                lineNumber: 15,
                columnNumber: 5,
                errorMessage: "'applyOverrideConfiguration' overrides nothing"
            ),
            BuildErrorParser.BuildError(
                filePath: "/Users/timojaask/projects/temp/testAndroidApp/app/src/main/java/com/example/testandroidapp/TestFile.kt",
                lineNumber: 8,
                columnNumber: 5,
                errorMessage: "A 'return' expression required in a function with a block body ('{...}')"
            )
        ]
        XCTAssertEqual(result, expected)
    }

    func testXmlError() {
        let input = BuildErrorSampleXmlOne
        let result = BuildErrorParser.parseBuildErrors(fromString: input)
        let expected = [
            BuildErrorParser.BuildError(
                filePath: "/Users/timojaask/projects/temp/testAndroidApp/app/src/main/res/layout/activity_main.xml",
                lineNumber: 9,
                columnNumber: nil,
                errorMessage: "attribute android:doesntExist not found."
            )
        ]
        XCTAssertEqual(result, expected)
    }

    func testMultileXmlErrors() {
        let input = BuildErrorSampleXmlMultiple
        let result = BuildErrorParser.parseBuildErrors(fromString: input)
        let expected = [
        BuildErrorParser.BuildError(
            filePath: "/Users/timojaask/projects/temp/testAndroidApp/app/src/main/res/layout/activity_main.xml",
            lineNumber: 15,
            columnNumber: nil,
            errorMessage: "not well-formed (invalid token)."
        ),
        BuildErrorParser.BuildError(
            filePath: "/Users/timojaask/projects/temp/testAndroidApp/app/src/main/res/layout/activity_main.xml",
            lineNumber: nil,
            columnNumber: nil,
            errorMessage: "file failed to compile."
        )
        ]
        XCTAssertEqual(result, expected)
    }
}



var BuildErrorSampleOneError = """
e: /Users/timojaask/projects/temp/testAndroidApp/app/src/main/java/com/example/testandroidapp/MainActivity.kt: (12, 9): Unresolved reference: lolbal

FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':app:compileDebugKotlin'.
> Compilation error. See log for more details

* Try:
Run with --stacktrace option to get the stack trace. Run with --info or --debug option to get more log output. Run with --scan to get full insights.

* Get more help at https://help.gradle.org

BUILD FAILED in 1s
"""

var BuildErrorMultipleErrors = """
e: /Users/timojaask/projects/temp/testAndroidApp/app/src/main/java/com/example/testandroidapp/MainActivity.kt: (12, 9): Unresolved reference: lolbal
e: /Users/timojaask/projects/temp/testAndroidApp/app/src/main/java/com/example/testandroidapp/MainActivity.kt: (15, 5): 'applyOverrideConfiguration' overrides nothing
e: /Users/timojaask/projects/temp/testAndroidApp/app/src/main/java/com/example/testandroidapp/TestFile.kt: (8, 5): A 'return' expression required in a function with a block body ('{...}')

FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':app:compileDebugKotlin'.
> Compilation error. See log for more details

* Try:
Run with --stacktrace option to get the stack trace. Run with --info or --debug option to get more log output. Run with --scan to get full insights.

* Get more help at https://help.gradle.org

BUILD FAILED in 1s
"""

var BuildErrorSampleXmlOne = """

FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':app:processDebugResources'.
> A failure occurred while executing com.android.build.gradle.internal.tasks.Workers$ActionFacade
   > Android resource linking failed
     /Users/timojaask/projects/temp/testAndroidApp/app/src/main/res/layout/activity_main.xml:9: AAPT: error: attribute android:doesntExist not found.


* Try:
Run with --stacktrace option to get the stack trace. Run with --info or --debug option to get more log output. Run with --scan to get full insights.

* Get more help at https://help.gradle.org

BUILD FAILED in 1s
"""

var BuildErrorSampleXmlMultiple = """

FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':app:mergeDebugResources'.
> A failure occurred while executing com.android.build.gradle.internal.tasks.Workers$ActionFacade
   > Android resource compilation failed
     /Users/timojaask/projects/temp/testAndroidApp/app/src/main/res/layout/activity_main.xml:15: AAPT: error: not well-formed (invalid token).

     /Users/timojaask/projects/temp/testAndroidApp/app/src/main/res/layout/activity_main.xml: AAPT: error: file failed to compile.


* Try:
Run with --stacktrace option to get the stack trace. Run with --info or --debug option to get more log output. Run with --scan to get full insights.

* Get more help at https://help.gradle.org

BUILD FAILED in 1s
"""
