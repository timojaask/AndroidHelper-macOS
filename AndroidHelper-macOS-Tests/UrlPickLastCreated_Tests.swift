import XCTest
import AndroidHelper_macOS

/**
 Design note:
 I don't like the fact that I'm doing I/O in these unit tests, but it was a conscious tradeoff that I made.

 Originally I though I would just create URLs at will with some any date value I want written in creationDateKey resource. Turns out, `URL.setResourceValues` does actual I/O, it checks the filesystem to see if I can set the resource on a file that the URL is pointing at (which is madness if you ask me, why should URL write into file system? Shouldn't that be the FileManager's job? Blah!). So I cannot create URLs with various creation dates at will for the test purposes.

 Another option would be to abstract away URL stuff and have some internal representation that I'd use that would be just a data type and wouldn't do any I/O. However, I don't want to do that at this point, becuase it would introduce unwelcome complexity, I really just want to use the system URL type in the app code. So this is off the table.

 And another option is to actually create temporary files for the purposes of testing. This is fine for now. If this breaks on some machines, then maybe I'd need to choose a different route then. But for now this is what I chose.
 */
class UrlPickLastCreated_Tests: XCTestCase {
    static var urlOlder: URL?
    static var urlNewer: URL?

    override class func setUp() {
        let tempDir = NSTemporaryDirectory()
        urlOlder = URL(fileURLWithPath: "\(tempDir)fileA")
        urlNewer = URL(fileURLWithPath: "\(tempDir)fileB")
        guard let urlA = urlOlder, let urlB = urlNewer else { XCTFail(); return }
        try? "textA".write(to: urlA, atomically: true, encoding: String.Encoding.utf8)
        try? "textB".write(to: urlB, atomically: true, encoding: String.Encoding.utf8)
    }

    override class func tearDown() {
        guard let urlA = urlOlder, let urlB = urlNewer else { return }
        try? FileManager.default.removeItem(at: urlA)
        try? FileManager.default.removeItem(at: urlB)
    }

    func testBothUrlsNil() {
        let lastCreatedUrl = URL.pickLastCreated(urlA: nil, urlB: nil)
        XCTAssertNil(lastCreatedUrl)
    }

    func testUrlANil() {
        let lastCreatedUrl = URL.pickLastCreated(urlA: nil, urlB: UrlPickLastCreated_Tests.urlNewer)
        XCTAssertEqual(UrlPickLastCreated_Tests.urlNewer, lastCreatedUrl)
    }

    func testUrlBNil() {
        let lastCreatedUrl = URL.pickLastCreated(urlA: UrlPickLastCreated_Tests.urlOlder, urlB: nil)
        XCTAssertEqual(UrlPickLastCreated_Tests.urlOlder, lastCreatedUrl)
    }

    func testOlderFirst() {
        let lastCreatedUrl = URL.pickLastCreated(urlA: UrlPickLastCreated_Tests.urlOlder, urlB: UrlPickLastCreated_Tests.urlNewer)
        XCTAssertEqual(UrlPickLastCreated_Tests.urlNewer?.absoluteString, lastCreatedUrl?.absoluteString)
    }

    func testNewerFirst() {
        let lastCreatedUrl = URL.pickLastCreated(urlA: UrlPickLastCreated_Tests.urlNewer, urlB: UrlPickLastCreated_Tests.urlOlder)
        XCTAssertEqual(UrlPickLastCreated_Tests.urlNewer?.absoluteString, lastCreatedUrl?.absoluteString)
    }
}
