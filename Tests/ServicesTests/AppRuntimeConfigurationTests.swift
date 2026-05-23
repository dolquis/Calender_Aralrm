import Foundation
import Testing

@testable import ShiftAlarm

struct AppRuntimeConfigurationTests {
    @Test
    func testValueUsesInfoPlistValueWhenResolved() throws {
        let bundle = try makeBundle(info: ["ShiftAlarmAppGroupIdentifier": "group.com.example.test"]
        )

        let value = AppRuntimeConfiguration.value(
            forInfoKey: "ShiftAlarmAppGroupIdentifier",
            fallback: "group.fallback",
            bundle: bundle
        )

        #expect(value == "group.com.example.test")
    }
    @Test
    func testValueFallsBackWhenBuildSettingIsUnresolved() throws {
        let bundle = try makeBundle(info: [
            "ShiftAlarmAppGroupIdentifier": "$(SHIFTALARM_APP_GROUP_ID)"
        ])

        let value = AppRuntimeConfiguration.value(
            forInfoKey: "ShiftAlarmAppGroupIdentifier",
            fallback: "group.fallback",
            bundle: bundle
        )

        #expect(value == "group.fallback")
    }
    @Test
    func testValueFallsBackWhenKeyIsMissing() throws {
        let bundle = try makeBundle(info: [:])

        let value = AppRuntimeConfiguration.value(
            forInfoKey: "ShiftAlarmAppGroupIdentifier",
            fallback: "group.fallback",
            bundle: bundle
        )

        #expect(value == "group.fallback")
    }

    private func makeBundle(info: [String: Any]) throws -> Bundle {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bundle")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(
            fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: url.appendingPathComponent("Info.plist"))
        return try #require(Bundle(url: url))
    }
}
