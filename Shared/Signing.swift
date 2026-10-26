import Foundation

/// What this copy of the app was allowed when the sideloading certificate signed it, read from its own signature
/// and from the profile the signer put in the app. The widgets can only see the list if the certificate lets the
/// app and the widgets share a place to keep it.
enum Signing {
    /// The entitlements of the running app (or widget extension).
    static let own: [String: Any] = entitlements(ofExecutable: Bundle.main.executableURL)

    static var appGroups: [String] { own["com.apple.security.application-groups"] as? [String] ?? [] }

    static var keychainGroups: [String] { own["keychain-access-groups"] as? [String] ?? [] }

    /// The team prefix the certificate signs with, e.g. "AB12CD34EF".
    static var teamPrefix: String? {
        (own["application-identifier"] as? String)?.split(separator: ".").first.map(String.init)
    }

    /// Reads the entitlements plist out of a signed Mach-O file (the code signature's 0xFADE7171 blob).
    static func entitlements(ofExecutable url: URL?) -> [String: Any] {
        guard let url, let data = try? Data(contentsOf: url, options: .alwaysMapped) else { return [:] }
        let magic = Data([0xFA, 0xDE, 0x71, 0x71])
        var searchEnd = data.endIndex
        while let range = data.range(of: magic, options: .backwards, in: data.startIndex..<searchEnd) {
            searchEnd = range.lowerBound
            let lengthStart = range.upperBound
            guard lengthStart + 4 <= data.endIndex else { continue }
            let length = data[lengthStart..<lengthStart + 4].reduce(0) { ($0 << 8) | Int($1) }
            let bodyStart = lengthStart + 4
            let bodyEnd = range.lowerBound + length
            guard length > 8, bodyEnd <= data.endIndex else { continue }
            let plist = try? PropertyListSerialization.propertyList(from: data[bodyStart..<bodyEnd], format: nil)
            if let dict = plist as? [String: Any] { return dict }
        }
        return [:]
    }

    /// The provisioning profile the signer embedded in a bundle (its XML part).
    static func profile(in bundle: Bundle) -> [String: Any] {
        guard let url = bundle.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex)
        else { return [:] }
        let plist = try? PropertyListSerialization.propertyList(from: data[start.lowerBound..<end.upperBound], format: nil)
        return plist as? [String: Any] ?? [:]
    }
}
