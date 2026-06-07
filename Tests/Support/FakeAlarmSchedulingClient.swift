import Foundation

@testable import ShiftAlarm

actor FakeAlarmSchedulingClient: AlarmSchedulingClient {
    struct ScheduleCall: Equatable, Sendable {
        let id: UUID
        let fireDate: Date
        let label: String
        let soundID: String
        let kind: ScheduledAlarmKind
    }

    enum Operation: Equatable, Sendable {
        case scheduledIDs
        case schedule(ScheduleCall)
        case cancel(UUID)
    }

    enum Failure: Error {
        case scheduleFailed
        case cancelFailed
    }

    private var liveIDs: Set<UUID>
    private var operations: [Operation] = []
    private var shouldFailSchedule: Bool
    private var shouldFailCancel: Bool
    private var cancelFailures: Set<UUID>
    private var state: AlarmAuthorizationState

    init(
        scheduledIDs: Set<UUID> = [],
        shouldFailSchedule: Bool = false,
        shouldFailCancel: Bool = false,
        cancelFailures: Set<UUID> = [],
        authorizationState: AlarmAuthorizationState = .authorized
    ) {
        self.liveIDs = scheduledIDs
        self.shouldFailSchedule = shouldFailSchedule
        self.shouldFailCancel = shouldFailCancel
        self.cancelFailures = cancelFailures
        self.state = authorizationState
    }

    @discardableResult
    func schedule(
        id: UUID,
        fireDate: Date,
        label: String,
        soundID: String,
        kind: ScheduledAlarmKind
    ) async throws -> UUID {
        operations.append(
            .schedule(
                ScheduleCall(id: id, fireDate: fireDate, label: label, soundID: soundID, kind: kind)
            ))
        if shouldFailSchedule {
            throw Failure.scheduleFailed
        }
        liveIDs.insert(id)
        return id
    }

    func cancel(id: UUID) async throws {
        operations.append(.cancel(id))
        if shouldFailCancel || cancelFailures.contains(id) {
            throw Failure.cancelFailed
        }
        liveIDs.remove(id)
    }

    func scheduledIDs() async throws -> Set<UUID> {
        operations.append(.scheduledIDs)
        return liveIDs
    }

    func authorizationState() async -> AlarmAuthorizationState {
        state
    }

    func recordedOperations() -> [Operation] {
        operations
    }

    func scheduledIDSet() -> Set<UUID> {
        liveIDs
    }

    func setCancelFailures(_ failures: Set<UUID>) {
        cancelFailures = failures
    }

    func setShouldFailCancel(_ shouldFail: Bool) {
        shouldFailCancel = shouldFail
    }
}
