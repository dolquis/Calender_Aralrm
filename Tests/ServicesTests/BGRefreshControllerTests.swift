import BackgroundTasks
import Foundation
import Testing

@testable import ShiftAlarm

struct BGRefreshControllerTests {
    @Test
    func testRequestUsesDocumentedIdentifier() {
        let request = BGRefreshController.makeRequest()
        #expect(request.identifier == BGRefreshController.identifier)
    }
    @Test
    func testRequestEarliestBeginDateIsRoughlyEightHoursOut() {
        let before = Date()
        let request = BGRefreshController.makeRequest()
        let after = Date()
        guard let earliest = request.earliestBeginDate else {
            Issue.record("earliestBeginDate should be set")
            return
        }
        let lower = before.addingTimeInterval(BGRefreshController.earliestRefreshInterval)
        let upper = after.addingTimeInterval(BGRefreshController.earliestRefreshInterval)
        #expect(
            earliest.timeIntervalSinceReferenceDate >= lower.timeIntervalSinceReferenceDate - 1)
        #expect(
            earliest.timeIntervalSinceReferenceDate <= upper.timeIntervalSinceReferenceDate + 1)
    }
    @Test
    func testScheduleNextSubmitsBuiltRequest() {
        var submitted: BGTaskRequest?
        BGRefreshController.scheduleNext { request in
            submitted = request
        }
        #expect(submitted?.identifier == BGRefreshController.identifier)
    }
    @Test
    func testScheduleNextSwallowsSubmitFailures() {
        struct DummyError: Error {}
        // The closure is allowed to throw; the controller must NOT propagate the error
        // because BG submission can legitimately fail in foreground / debugger contexts.
        BGRefreshController.scheduleNext { _ in throw DummyError() }
    }
}
