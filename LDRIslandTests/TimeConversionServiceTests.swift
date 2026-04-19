import XCTest
@testable import LDRIsland

final class TimeConversionServiceTests: XCTestCase {
    private let service = TimeConversionService()
    private let local = PersonConfiguration(name: "Me", timeZoneIdentifier: "America/New_York", avatar: .man)
    private let partner = PersonConfiguration(name: "Her", timeZoneIdentifier: "Asia/Kuala_Lumpur", avatar: .woman)

    func testLocalToPartnerRollsIntoTomorrow() {
        let referenceDate = makeUTCDate(year: 2025, month: 1, day: 15, hour: 12, minute: 0)

        let result = service.convert(
            timeOfDay: DateComponents(hour: 21, minute: 0),
            direction: .localToPartner,
            referenceDate: referenceDate,
            local: local,
            partner: partner
        )

        XCTAssertEqual(result.targetTimeText, "10:00 AM")
        XCTAssertEqual(result.shift, .nextDay)
        XCTAssertEqual(result.summaryText, "Her time: 10:00 AM tomorrow")
        XCTAssertEqual(result.detailText, "Thu • GMT+8")
    }

    func testPartnerToLocalRollsIntoYesterday() {
        let referenceDate = makeUTCDate(year: 2025, month: 1, day: 15, hour: 12, minute: 0)

        let result = service.convert(
            timeOfDay: DateComponents(hour: 9, minute: 0),
            direction: .partnerToLocal,
            referenceDate: referenceDate,
            local: local,
            partner: partner
        )

        XCTAssertEqual(result.targetTimeText, "8:00 PM")
        XCTAssertEqual(result.shift, .previousDay)
        XCTAssertEqual(result.summaryText, "Me time: 8:00 PM yesterday")
        XCTAssertEqual(result.detailText, "Tue • EST")
    }

    func testSnapshotShowsOffsetAhead() {
        let referenceDate = makeUTCDate(year: 2025, month: 1, day: 15, hour: 12, minute: 0)

        let snapshot = service.clockSnapshot(
            referenceDate: referenceDate,
            local: local,
            partner: partner
        )

        XCTAssertEqual(snapshot.offsetText, "13h ahead")
        XCTAssertEqual(snapshot.local.zoneText, "EST")
        XCTAssertEqual(snapshot.partner.zoneText, "GMT+8")
    }

    private func makeUTCDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt

        return calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )) ?? Date(timeIntervalSince1970: 0)
    }
}
