import XCTest
@testable import ShiftAlarm

final class AppRuntimeConfigurationTests: XCTestCase {
    func testValueUsesInfoPlistValueWhenResolved() throws {
        let bundle = try makeBundle(info: ["ShiftAlarmAppGroupIdentifier": "group.com.example.test"])

        let value = AppRuntimeConfiguration.value(
            forInfoKey: "ShiftAlarmAppGroupIdentifier",
            fallback: "group.fallback",
            bundle: bundle
        )

        XCTAssertEqual(value, "group.com.example.test")
    }

    func testValueFallsBackWhenBuildSettingIsUnresolved() throws {
        let bundle = try makeBundle(info: ["ShiftAlarmAppGroupIdentifier": "$(SHIFTALARM_APP_GROUP_ID)"])

        let value = AppRuntimeConfiguration.value(
            forInfoKey: "ShiftAlarmAppGroupIdentifier",
            fallback: "group.fallback",
            bundle: bundle
        )

        XCTAssertEqual(value, "group.fallback")
    }

    func testValueFallsBackWhenKeyIsMissing() throws {
        let bundle = try makeBundle(info: [:])

        let value = AppRuntimeConfiguration.value(
            forInfoKey: "ShiftAlarmAppGroupIdentifier",
            fallback: "group.fallback",
            bundle: bundle
        )

        XCTAssertEqual(value, "group.fallback")
    }

    private func makeBundle(info: [String: Any]) throws -> Bundle {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bundle")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: url.appendingPathComponent("Info.plist"))
        return try XCTUnwrap(Bundle(url: url))
    }
}
