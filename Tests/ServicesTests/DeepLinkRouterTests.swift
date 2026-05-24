import Foundation
import Testing

@testable import ShiftAlarm

@MainActor
struct DeepLinkRouterTests {

    private func encodeBundle(_ bundle: ShiftBundle) throws -> String {
        let data = try ShiftBundleCodec.encode(bundle)
        return data.base64EncodedString()
    }
    @Test
    func testParseValidImportURL() throws {
        let presetID = UUID()
        let bundle = ShiftBundle(
            presets: [
                ShiftBundle.PresetDTO(
                    id: presetID,
                    name: "Night",
                    colorHex: "#E53935",
                    defaultAlarmHour: 22,
                    defaultAlarmMinute: 0,
                    soundID: AlarmSound.systemDefault.id,
                    note: ""
                )
            ]
        )
        let payload = try encodeBundle(bundle)
        let url = URL(string: "shiftalarm://import?payload=\(payload)")!
        let action = DeepLinkRouter.parse(url)

        if case .importPayload(let parsed) = action {
            #expect(parsed.presets.count == 1)
            #expect(parsed.presets.first?.id == presetID)
            #expect(parsed.presets.first?.name == "Night")
        } else {
            Issue.record("Expected importPayload, got \(action)")
        }
    }
    @Test
    func testParseUnknownScheme() {
        let url = URL(string: "https://example.com/import?payload=abc")!
        #expect(DeepLinkRouter.parse(url) == .unknown)
    }
    @Test
    func testParseUnknownHost() {
        let url = URL(string: "shiftalarm://export?payload=abc")!
        #expect(DeepLinkRouter.parse(url) == .unknown)
    }
    @Test
    func testParseMissingPayload() {
        let url = URL(string: "shiftalarm://import")!
        #expect(DeepLinkRouter.parse(url) == .unknown)
    }
    @Test
    func testParseInvalidBase64Payload() {
        let url = URL(string: "shiftalarm://import?payload=!!!notbase64!!!")!
        #expect(DeepLinkRouter.parse(url) == .unknown)
    }
    @Test
    func testParseCorruptedJSONPayload() throws {
        let corrupt = Data("{ not valid json }".utf8).base64EncodedString()
        let url = URL(string: "shiftalarm://import?payload=\(corrupt)")!
        #expect(DeepLinkRouter.parse(url) == .unknown)
    }
    @Test
    func testURLEncodedPayloadRoundTrip() throws {
        let bundle = ShiftBundle(
            patterns: [
                ShiftBundle.RotationDTO(
                    id: UUID(),
                    name: "3on1off",
                    anchorDate: CalendarDay(year: 2026, month: 1, day: 1),
                    cycleLength: 4,
                    slots: [nil, nil, nil, nil],
                    startDate: nil,
                    endDate: nil,
                    priority: 1,
                    isActive: true
                )
            ]
        )
        let raw = try encodeBundle(bundle)
        // URL-encode the payload to handle + and = characters
        let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw
        let url = URL(string: "shiftalarm://import?payload=\(encoded)")!
        let action = DeepLinkRouter.parse(url)

        if case .importPayload(let parsed) = action {
            #expect(parsed.patterns.count == 1)
            #expect(parsed.patterns.first?.name == "3on1off")
        } else {
            Issue.record("Expected importPayload, got \(action)")
        }
    }
}
