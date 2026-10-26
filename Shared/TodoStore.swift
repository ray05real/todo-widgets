import Foundation
import Security

/// Where the list is kept. The app and the widgets each look for a place they can both reach, in this order:
/// an App Group folder, then a shared keychain group, else the app's own folder (then the widgets can't see it).
enum TodoStore {
    enum Method: String {
        case appGroup = "App Group"
        case keychain = "Shared keychain"
        case local = "Not shared"
    }

    static let fileName = "todo.json"

    static let groupContainer: URL? = {
        for group in Signing.appGroups {
            if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) {
                return url
            }
        }
        return nil
    }()

    /// "<team>.todo.shared" if the certificate allows it (wildcard profiles allow "<team>.*").
    static let sharedKeychainGroup: String? = {
        guard let prefix = Signing.teamPrefix else { return nil }
        let candidate = prefix + ".todo.shared"
        let allowed = Signing.keychainGroups.contains { group in
            group == candidate || (group.hasSuffix("*") && candidate.hasPrefix(String(group.dropLast())))
        }
        return allowed ? candidate : nil
    }()

    static let method: Method = {
        if groupContainer != nil { return .appGroup }
        if sharedKeychainGroup != nil { return .keychain }
        return .local
    }()

    /// The last keychain result (0 = fine, -34018 = not allowed by the certificate).
    static var lastKeychainStatus: OSStatus = errSecSuccess

    static func load() -> [TodoItem] {
        guard let data = readData(),
              let items = try? JSONDecoder().decode([TodoItem].self, from: data)
        else { return TodoItem.samples }
        return items
    }

    static func save(_ items: [TodoItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        writeData(data)
    }

    /// Ticks or unticks one item and returns the new list.
    static func toggle(_ id: String) -> [TodoItem] {
        var items = load()
        if let i = items.firstIndex(where: { $0.id == id }) { items[i].done.toggle() }
        save(items)
        return items
    }

    // MARK: - Files and keychain

    private static var localURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    private static var fileURL: URL? {
        switch method {
        case .appGroup: return groupContainer?.appendingPathComponent(fileName)
        case .local: return localURL
        case .keychain: return nil
        }
    }

    private static func readData() -> Data? {
        if method == .keychain { return keychainRead() }
        guard let url = fileURL else { return nil }
        return try? Data(contentsOf: url)
    }

    private static func writeData(_ data: Data) {
        if method == .keychain { return keychainWrite(data) }
        guard let url = fileURL else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    private static func keychainQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "todo.list",
            kSecAttrAccount as String: "list",
            kSecAttrAccessGroup as String: sharedKeychainGroup ?? "",
        ]
    }

    private static func keychainRead() -> Data? {
        var query = keychainQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status != errSecItemNotFound { lastKeychainStatus = status }
        return status == errSecSuccess ? result as? Data : nil
    }

    private static func keychainWrite(_ data: Data) {
        let query = keychainQuery()
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        guard status == errSecItemNotFound else {
            lastKeychainStatus = status
            return
        }
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        lastKeychainStatus = SecItemAdd(add as CFDictionary, nil)
    }
}
