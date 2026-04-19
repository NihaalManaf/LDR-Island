import Foundation

enum ConversionDirection: Int {
    case localToPartner = 0
    case partnerToLocal = 1
}

enum RelativeDayShift: Equatable {
    case previousDay
    case sameDay
    case nextDay
    case days(Int)

    var descriptionText: String {
        switch self {
        case .previousDay:
            return "yesterday"
        case .sameDay:
            return "same day"
        case .nextDay:
            return "tomorrow"
        case .days(let value) where value > 0:
            return "\(value) days later"
        case .days(let value):
            return "\(abs(value)) days earlier"
        }
    }

    var inlineSuffix: String {
        switch self {
        case .sameDay:
            return ""
        default:
            return " \(descriptionText)"
        }
    }
}

struct ClockLineSnapshot: Equatable {
    let name: String
    let timeText: String
    let dayText: String
    let zoneText: String
}

struct ClockSnapshot: Equatable {
    let local: ClockLineSnapshot
    let partner: ClockLineSnapshot
    let offsetText: String
}

struct ConversionResult: Equatable {
    let sourceName: String
    let targetName: String
    let targetTimeText: String
    let targetDayText: String
    let targetZoneText: String
    let shift: RelativeDayShift
    let summaryText: String
    let detailText: String
}

final class TimeConversionService {
    private let neutralCalendar: Calendar
    private let locale = Locale(identifier: "en_US_POSIX")

    init(calendarIdentifier: Calendar.Identifier = .gregorian) {
        self.neutralCalendar = Calendar(identifier: calendarIdentifier)
    }

    func clockSnapshot(
        referenceDate: Date,
        local: PersonConfiguration,
        partner: PersonConfiguration
    ) -> ClockSnapshot {
        let localZone = local.resolvedTimeZone
        let partnerZone = partner.resolvedTimeZone

        return ClockSnapshot(
            local: ClockLineSnapshot(
                name: local.name,
                timeText: formattedTime(for: referenceDate, timeZone: localZone),
                dayText: formattedDay(for: referenceDate, timeZone: localZone),
                zoneText: zoneLabel(for: localZone, at: referenceDate)
            ),
            partner: ClockLineSnapshot(
                name: partner.name,
                timeText: formattedTime(for: referenceDate, timeZone: partnerZone),
                dayText: formattedDay(for: referenceDate, timeZone: partnerZone),
                zoneText: zoneLabel(for: partnerZone, at: referenceDate)
            ),
            offsetText: offsetText(referenceDate: referenceDate, from: localZone, to: partnerZone)
        )
    }

    func convert(
        timeOfDay: DateComponents,
        direction: ConversionDirection,
        referenceDate: Date,
        local: PersonConfiguration,
        partner: PersonConfiguration
    ) -> ConversionResult {
        let source = direction == .localToPartner ? local : partner
        let target = direction == .localToPartner ? partner : local

        let sourceTimeZone = source.resolvedTimeZone
        let targetTimeZone = target.resolvedTimeZone

        var sourceCalendar = neutralCalendar
        sourceCalendar.timeZone = sourceTimeZone

        var sourceDay = sourceCalendar.dateComponents([.year, .month, .day], from: referenceDate)
        sourceDay.hour = min(max(timeOfDay.hour ?? 0, 0), 23)
        sourceDay.minute = min(max(timeOfDay.minute ?? 0, 0), 59)
        sourceDay.second = 0

        let sourceDate = sourceCalendar.date(from: sourceDay) ?? referenceDate
        let shift = relativeDayShift(for: sourceDate, sourceTimeZone: sourceTimeZone, targetTimeZone: targetTimeZone)
        let targetTimeText = formattedTime(for: sourceDate, timeZone: targetTimeZone)
        let targetDayText = formattedDay(for: sourceDate, timeZone: targetTimeZone)
        let targetZoneText = zoneLabel(for: targetTimeZone, at: sourceDate)

        return ConversionResult(
            sourceName: source.name,
            targetName: target.name,
            targetTimeText: targetTimeText,
            targetDayText: targetDayText,
            targetZoneText: targetZoneText,
            shift: shift,
            summaryText: "\(target.name) time: \(targetTimeText)\(shift.inlineSuffix)",
            detailText: "\(targetDayText) • \(targetZoneText)"
        )
    }

    private func formattedTime(for date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func formattedDay(for date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func zoneLabel(for timeZone: TimeZone, at date: Date) -> String {
        if let abbreviation = timeZone.abbreviation(for: date) {
            return abbreviation
        }

        let seconds = timeZone.secondsFromGMT(for: date)
        let hours = seconds / 3600
        return hours >= 0 ? "UTC+\(hours)" : "UTC\(hours)"
    }

    private func offsetText(referenceDate: Date, from source: TimeZone, to target: TimeZone) -> String {
        let difference = target.secondsFromGMT(for: referenceDate) - source.secondsFromGMT(for: referenceDate)

        guard difference != 0 else {
            return "same time"
        }

        let direction = difference > 0 ? "ahead" : "behind"
        let absolute = abs(difference)
        let hours = absolute / 3600
        let minutes = (absolute % 3600) / 60

        if minutes == 0 {
            return "\(hours)h \(direction)"
        }

        return "\(hours)h \(minutes)m \(direction)"
    }

    private func relativeDayShift(for date: Date, sourceTimeZone: TimeZone, targetTimeZone: TimeZone) -> RelativeDayShift {
        var sourceCalendar = neutralCalendar
        sourceCalendar.timeZone = sourceTimeZone

        var targetCalendar = neutralCalendar
        targetCalendar.timeZone = targetTimeZone

        let sourceComponents = sourceCalendar.dateComponents([.year, .month, .day], from: date)
        let targetComponents = targetCalendar.dateComponents([.year, .month, .day], from: date)

        var utcCalendar = neutralCalendar
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt

        let sourceDay = utcCalendar.date(from: DateComponents(
            year: sourceComponents.year,
            month: sourceComponents.month,
            day: sourceComponents.day
        )) ?? date

        let targetDay = utcCalendar.date(from: DateComponents(
            year: targetComponents.year,
            month: targetComponents.month,
            day: targetComponents.day
        )) ?? date

        let dayDifference = utcCalendar.dateComponents([.day], from: sourceDay, to: targetDay).day ?? 0

        switch dayDifference {
        case -1:
            return .previousDay
        case 0:
            return .sameDay
        case 1:
            return .nextDay
        default:
            return .days(dayDifference)
        }
    }
}
