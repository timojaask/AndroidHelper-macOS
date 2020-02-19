import XCTest
import AndroidHelper_macOS

class FileManagerFindLastCreatedFile: XCTestCase {
    static let directory = NSTemporaryDirectory()
    static let fileNames = ["file1.ex1", "file2.ex2", "file3.ex1", "file4.ex3", "file5.ex2", "file6.ex4"]
    static var files: [URL] = []

    override class func setUp() {
        files = fileNames.map { URL(fileURLWithPath: "\(directory)\($0)") }
        files.forEach {
            print("- Creating file \($0)")
            try? "text".write(to: $0, atomically: true, encoding: String.Encoding.utf8)
        }
    }

    override class func tearDown() {
        files.forEach {
            try? FileManager.default.removeItem(at: $0)
        }
    }

    /**
     There's an odd quirk with `/var` folder, turns out it's the same as `/private/var`. This becomes a problem, because in our tests we use `NSTemporaryDirectory()`
     which points to something in `/var/...`. Then when you enumerate this folder using `FileManager.default.enumerator`, it reports the path as `/private/var/...`.
     So then when we're trying to compare the results we get false failures because `/var/...` is not the same as `/private/var/...`, even though
     they are actually the same folders.
     */
    func normalizeVarFolderPath(path: String?) -> String? {
        guard let path = path else { return nil }
        guard path.hasPrefix("/private/var") else { return path }
        return path.replacingOccurrences(of: "/private/var", with: "/var")
    }

    func testOne() {
        let result = FileManager.default.fildLastCreatedFile(directory: FileManagerFindLastCreatedFile.directory, fileExtension: "ex1")
        let expected = FileManagerFindLastCreatedFile.files[2]
        XCTAssertEqual(normalizeVarFolderPath(path: result), expected.path)
    }

    func testTwo() {
        let result = FileManager.default.fildLastCreatedFile(directory: FileManagerFindLastCreatedFile.directory, fileExtension: "ex2")
        let expected = FileManagerFindLastCreatedFile.files[4]
        XCTAssertEqual(normalizeVarFolderPath(path: result), expected.path)
    }
}
