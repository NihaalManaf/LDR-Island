import Foundation

enum AvatarStyle: Equatable {
    case man
    case woman
}

struct PersonConfiguration: Equatable {
    let name: String
    let timeZoneIdentifier: String?
    let avatar: AvatarStyle

    var resolvedTimeZone: TimeZone {
        if let timeZoneIdentifier, let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            return timeZone
        }

        return .autoupdatingCurrent
    }
}

// Edit partner name + partnerTimeZoneIdentifier before first run.
// Use IANA timezone IDs, e.g. "America/New_York" or "Asia/Kuala_Lumpur".
struct AppConfiguration {
    let local: PersonConfiguration
    let partner: PersonConfiguration
    let startsExpanded: Bool
    let showsDockIcon: Bool

    static let current = AppConfiguration(
        local: PersonConfiguration(
            name: "You",
            timeZoneIdentifier: nil,
            avatar: .man
        ),
        partner: PersonConfiguration(
            name: "Her",
            timeZoneIdentifier: "Asia/Kuala_Lumpur",
            avatar: .woman
        ),
        startsExpanded: false,
        showsDockIcon: true
    )
}
