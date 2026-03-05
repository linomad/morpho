import Foundation
import ServiceManagement

enum LaunchAtLoginControllerError: LocalizedError {
    case unsupportedSystem
    case registrationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSystem:
            return "当前系统版本不支持开机启动配置。"
        case .registrationFailed(let reason):
            return reason
        }
    }
}

enum LaunchAtLoginController {
    static func isEnabled() -> Bool {
        guard #available(macOS 13.0, *) else {
            return false
        }
        return SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        guard #available(macOS 13.0, *) else {
            throw LaunchAtLoginControllerError.unsupportedSystem
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            throw LaunchAtLoginControllerError.registrationFailed(error.localizedDescription)
        }
    }
}
