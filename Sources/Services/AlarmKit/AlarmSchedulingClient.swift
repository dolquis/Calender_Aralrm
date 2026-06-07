import Foundation

public enum ScheduledAlarmKind: Sendable, Equatable {
    case main
    case bedtime
}

public protocol AlarmSchedulingClient: Sendable {
    @discardableResult
    func schedule(
        id: UUID,
        fireDate: Date,
        label: String,
        soundID: String,
        kind: ScheduledAlarmKind
    ) async throws -> UUID

    func cancel(id: UUID) async throws
    func scheduledIDs() async throws -> Set<UUID>
    func authorizationState() async -> AlarmAuthorizationState
}
