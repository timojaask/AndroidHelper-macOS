import Foundation

extension FileManager {
    public func fildLastCreatedFile(directory: String, fileExtension: String) -> String? {
        let url = URL(fileURLWithPath: directory)

        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: nil) else { return nil }

        return enumerator
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == fileExtension }
            .reduce(nil, URL.pickLastCreated)?
            .path
    }
}
