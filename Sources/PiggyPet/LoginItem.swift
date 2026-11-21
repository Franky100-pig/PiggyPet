import Foundation
import ServiceManagement

/// Launch-at-login, wrapped so the menu can flip it either way at any time.
///
/// `SMAppService.mainApp` is the macOS 13+ API: registering adds PiggyPet to
/// the user's Login Items, unregistering removes it again. The status is read
/// fresh every time instead of being cached in UserDefaults, so if the user
/// turns the pig off in System Settings the menu shows that truth too.
enum LoginItem {
    static var status: SMAppService.Status { SMAppService.mainApp.status }

    static var isEnabled: Bool { status == .enabled }

    /// macOS may require the user to flip a switch in System Settings before a
    /// freshly registered item is actually live.
    static var needsApproval: Bool { status == .requiresApproval }

    /// Returns whether the login item is enabled afterwards.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else if service.status == .enabled || service.status == .requiresApproval {
                try service.unregister()
            }
        } catch {
            NSLog("[PiggyPet] login item %@ failed: %@",
                  enabled ? "register" : "unregister", String(describing: error))
        }
        return enabled ? service.status == .enabled : service.status != .enabled
    }

    static var statusDescription: String {
        switch status {
        case .enabled: return "enabled"
        case .requiresApproval: return "requiresApproval"
        case .notRegistered: return "notRegistered"
        case .notFound: return "notFound"
        @unknown default: return "unknown"
        }
    }
}
