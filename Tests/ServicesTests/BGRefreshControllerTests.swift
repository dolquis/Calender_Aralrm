import XCTest
import BackgroundTasks
@testable import ShiftAlarm

final class BGRefreshControllerTests: XCTestCase {
    func testRequestUsesDocumentedIdentifier() {
        let request = BGRefreshController.makeRequest()
        XCTAssertEqual(request.identifier, BGRefreshController.identifier)
    }

    func testRequestEarliestBeginDateIsRoughlyEightHoursOut() {
        let before = Date()
        let request = BGRefreshController.makeRequest()
        let after = Date()
        let earliest = try? XCTUnwrap(request.earliestBeginDate)
        guard let earliest else { return }
        let lower = before.addingTimeInterval(BGRefreshController.earliestRefreshInterval)
        let upper = after.addingTimeInterval(BGRefreshController.earliestRefreshInterval)
        XCTAssertGreaterThanOrEqual(earliest.timeIntervalSinceReferenceDate,
                                    lower.timeIntervalSinceReferenceDate - 1)
        XCTAssertLessThanOrEqual(earliest.timeIntervalSinceReferenceDate,
                                 upper.timeIntervalSinceReferenceDate + 1)
    }

    func testScheduleNextSubmitsBuiltRequest() {
        var submitted: BGTaskRequest?
        BGRefreshController.scheduleNext { request in
            submitted = request
        }
        XCTAssertEqual(submitted?.identifier, BGRefreshController.identifier)
    }

    func testScheduleNextSwallowsSubmitFailures() {
        struct DummyError: Error {}
        // The closure is allowed to throw; the controller must NOT propagate the error
        // because BG submission can legitimately fail in foreground / debugger contexts.
        BGRefreshController.scheduleNext { _ in throw DummyError() }
        // Reaching this line means no exception escaped; pass.
        XCTAssertTrue(true)
    }
}
