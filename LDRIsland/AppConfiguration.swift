import Foundation

enum AvatarStyle: String, CaseIterable, Equatable {
    case man
    case woman

    var displayName: String {
        switch self {
        case .man: return "Male"
        case .woman: return "Female"
        }
    }
}

enum RelationshipRole: String, CaseIterable {
    case boyfriend
    case girlfriend

    var displayName: String {
        rawValue.capitalized
    }

    var defaultPartnerAvatar: AvatarStyle {
        switch self {
        case .boyfriend: return .woman
        case .girlfriend: return .man
        }
    }

    var defaultLocalAvatar: AvatarStyle {
        switch self {
        case .boyfriend: return .man
        case .girlfriend: return .woman
        }
    }
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

struct AppConfiguration: Equatable {
    let local: PersonConfiguration
    let partner: PersonConfiguration
    let startsExpanded: Bool
    let showsDockIcon: Bool
    let relationshipRole: RelationshipRole
    let showsReunionCountdown: Bool
    let reunionDate: Date?

    static let `default` = AppConfiguration(
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
        showsDockIcon: true,
        relationshipRole: .boyfriend,
        showsReunionCountdown: false,
        reunionDate: nil
    )

    static var current: AppConfiguration {
        AppSettingsStore.shared.configuration
    }
}

final class AppSettingsStore {
    static let shared = AppSettingsStore()
    static let didChangeNotification = Notification.Name("AppSettingsStoreDidChange")

    private enum Keys {
        static let localTimeZoneIdentifier = "localTimeZoneIdentifier"
        static let partnerTimeZoneIdentifier = "partnerTimeZoneIdentifier"
        static let partnerAvatar = "partnerAvatar"
        static let relationshipRole = "relationshipRole"
        static let showsReunionCountdown = "showsReunionCountdown"
        static let reunionDate = "reunionDate"
    }

    private let defaults = UserDefaults.standard

    var configuration: AppConfiguration {
        let base = AppConfiguration.default
        let role = RelationshipRole(rawValue: defaults.string(forKey: Keys.relationshipRole) ?? "") ?? base.relationshipRole
        let partnerAvatar = AvatarStyle(rawValue: defaults.string(forKey: Keys.partnerAvatar) ?? "") ?? role.defaultPartnerAvatar
        let localTimeZoneIdentifier = defaults.string(forKey: Keys.localTimeZoneIdentifier)
        let partnerTimeZoneIdentifier = defaults.string(forKey: Keys.partnerTimeZoneIdentifier) ?? base.partner.timeZoneIdentifier

        return AppConfiguration(
            local: PersonConfiguration(
                name: base.local.name,
                timeZoneIdentifier: localTimeZoneIdentifier,
                avatar: role.defaultLocalAvatar
            ),
            partner: PersonConfiguration(
                name: base.partner.name,
                timeZoneIdentifier: partnerTimeZoneIdentifier,
                avatar: partnerAvatar
            ),
            startsExpanded: base.startsExpanded,
            showsDockIcon: base.showsDockIcon,
            relationshipRole: role,
            showsReunionCountdown: defaults.object(forKey: Keys.showsReunionCountdown) as? Bool ?? base.showsReunionCountdown,
            reunionDate: defaults.object(forKey: Keys.reunionDate) as? Date
        )
    }

    func update(
        relationshipRole: RelationshipRole,
        localTimeZoneIdentifier: String?,
        partnerTimeZoneIdentifier: String?,
        partnerAvatar: AvatarStyle,
        showsReunionCountdown: Bool,
        reunionDate: Date?
    ) {
        defaults.set(relationshipRole.rawValue, forKey: Keys.relationshipRole)
        defaults.set(localTimeZoneIdentifier, forKey: Keys.localTimeZoneIdentifier)
        defaults.set(partnerTimeZoneIdentifier, forKey: Keys.partnerTimeZoneIdentifier)
        defaults.set(partnerAvatar.rawValue, forKey: Keys.partnerAvatar)
        defaults.set(showsReunionCountdown, forKey: Keys.showsReunionCountdown)
        defaults.set(reunionDate, forKey: Keys.reunionDate)
        NotificationCenter.default.post(name: AppSettingsStore.didChangeNotification, object: nil)
    }
}
