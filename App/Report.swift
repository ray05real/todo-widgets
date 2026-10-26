import ActivityKit
import Foundation
import UIKit

/// The test report the owner copies and sends back: what the sideloading certificate allowed, and whether the
/// widgets can see the list.
enum Report {
    static func text() -> String {
        let widgetBundle = Bundle.main.builtInPlugInsURL
            .flatMap { Bundle(url: $0.appendingPathComponent("TodoWidgets.appex")) }
        let app = Signing.own
        let widget = Signing.entitlements(ofExecutable: widgetBundle?.executableURL)
        let profile = Signing.profile(in: Bundle.main)
        let profileEntitlements = profile["Entitlements"] as? [String: Any] ?? [:]

        var lines: [String] = [
            "iOS \(UIDevice.current.systemVersion)",
            "App id: \(Bundle.main.bundleIdentifier ?? "?")",
            "Widget id: \(widgetBundle?.bundleIdentifier ?? "MISSING")",
            "List kept in: \(TodoStore.method.rawValue)",
            "Groups (app): \(list(app["com.apple.security.application-groups"]))",
            "Groups (widget): \(list(widget["com.apple.security.application-groups"]))",
            "Groups (profile): \(list(profileEntitlements["com.apple.security.application-groups"]))",
            "Keychain (app): \(list(app["keychain-access-groups"]))",
            "Keychain (widget): \(list(widget["keychain-access-groups"]))",
            "Keychain status: \(TodoStore.lastKeychainStatus)",
            "Profile: \(profile["Name"] as? String ?? "none")",
            "Enterprise: \(profile["ProvisionsAllDevices"] as? Bool == true ? "yes" : "no")",
            "Card allowed: \(ActivityAuthorizationInfo().areActivitiesEnabled ? "yes" : "no")",
            "Card showing: \(LiveCard.isRunning ? "yes" : "no")",
        ]
        if let expires = profile["ExpirationDate"] as? Date {
            lines.append("Certificate ends: \(expires.formatted(date: .abbreviated, time: .omitted))")
        }
        return lines.joined(separator: "\n")
    }

    private static func list(_ value: Any?) -> String {
        guard let array = value as? [String], !array.isEmpty else { return "none" }
        return array.joined(separator: ", ")
    }
}
