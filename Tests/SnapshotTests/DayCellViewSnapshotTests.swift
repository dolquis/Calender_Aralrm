import SnapshotTesting
import SwiftUI
import XCTest

@testable import ShiftAlarm

@MainActor
final class DayCellViewSnapshotTests: XCTestCase {
    private func fixedDate() -> Date {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        var dc = DateComponents()
        dc.year = 2026
        dc.month = 5
        dc.day = 14
        return c.date(from: dc)!
    }

    private func host(
        _ view: some View, size: CGSize = CGSize(width: 56, height: 80)
    ) -> UIViewController {
        let host = UIHostingController(rootView: view)
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.layoutIfNeeded()
        return host
    }

    func testCellWithAlarm_lightMode() throws {
        try SnapshotTestGate.skipIfDisabled()
        let view = DayCellView(
            date: fixedDate(),
            inCurrentMonth: true,
            presetName: "Day",
            presetColorHex: "#1E88E5",
            alarmTime: DateComponents(hour: 6, minute: 30),
            holidayLabel: nil
        )
        .environment(\.colorScheme, .light)
        assertSnapshot(of: host(view), as: .image)
    }

    func testCellWithAlarm_darkMode() throws {
        try SnapshotTestGate.skipIfDisabled()
        let view = DayCellView(
            date: fixedDate(),
            inCurrentMonth: true,
            presetName: "Day",
            presetColorHex: "#1E88E5",
            alarmTime: DateComponents(hour: 6, minute: 30),
            holidayLabel: nil
        )
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: host(view), as: .image)
    }

    func testCellWithHoliday() throws {
        try SnapshotTestGate.skipIfDisabled()
        let view = DayCellView(
            date: fixedDate(),
            inCurrentMonth: true,
            presetName: nil,
            presetColorHex: nil,
            alarmTime: nil,
            holidayLabel: "祝"
        )
        assertSnapshot(of: host(view), as: .image)
    }

    func testCellOutOfMonth_dimmed() throws {
        try SnapshotTestGate.skipIfDisabled()
        let view = DayCellView(
            date: fixedDate(),
            inCurrentMonth: false,
            presetName: nil,
            presetColorHex: nil,
            alarmTime: nil,
            holidayLabel: nil
        )
        assertSnapshot(of: host(view), as: .image)
    }

    func testCellDynamicType_XL() throws {
        try SnapshotTestGate.skipIfDisabled()
        let view = DayCellView(
            date: fixedDate(),
            inCurrentMonth: true,
            presetName: "Night",
            presetColorHex: "#8E24AA",
            alarmTime: DateComponents(hour: 22, minute: 0),
            holidayLabel: nil
        )
        .environment(\.dynamicTypeSize, .accessibility3)
        assertSnapshot(of: host(view, size: CGSize(width: 80, height: 120)), as: .image)
    }
}
