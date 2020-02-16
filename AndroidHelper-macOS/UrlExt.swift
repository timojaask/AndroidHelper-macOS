import Foundation

extension URL {
    /**
     * Return the URL that last created by comparing the creation date attributes.
     * If one of the URLs is `nil` or is missing the `creationDateKey` attribute, the other URL will be returned.
     * If both URLs are `nil` or both are missing the `creationDateKey` attribute, `nil` will be returned.
    */
    public static func pickLastCreated(urlA: URL?, urlB: URL?) -> URL? {
        func getCreationDate(url: URL?) -> Date? {
            let attributes = try? url?.resourceValues(forKeys: [.creationDateKey])
            return attributes?.creationDate
        }

        let creationDateA = getCreationDate(url: urlA)
        let creationDateB = getCreationDate(url: urlB)
        switch (creationDateA, creationDateB) {
        case (nil, nil):
            return nil
        case (_, nil):
            return urlA
        case (nil, _):
            return urlB
        case let (someDateA?, someDateB?):
            return someDateA > someDateB ? urlA : urlB
        }
    }
}
