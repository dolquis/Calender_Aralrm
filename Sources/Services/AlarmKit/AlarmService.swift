import Foundation

#if canImport(AlarmKit)
import AlarmKit
#endif

/// Thin wrapper around `AlarmManager.shared`. The wrapper isolates AlarmKit symbols so unit tests
/// and platforms that lack the framework can still compile.
public actor AlarmService {
    public init() {}

    public func authorizationState() async -> AlarmAuthorizationState {
        #if canImport(AlarmKit)
        switch AlarmManager.shared.authorizationState {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        @unknown default: return .denied
        }
        #else
        return .denied
        #endif
    }

    @discardableResult
    public func requestAuthorization() async -> AlarmAuthorizationState {
        #if canImport(AlarmKit)
        do {
            let result = try await AlarmManager.shared.requestAuthorization()
            switch result {
            case .authorized: return .authorized
            case .denied: return .denied
            case .notDetermined: return .notDetermined
            @unknown default: return .denied
            }
        } catch {
            return .denied
        }
        #else
        return .denied
        #endif
    }

    @discardableResult
    public func schedule(
        id: UUID,
        fireDate: Date,
        label: String,
        soundID: String
    ) async throws -> UUID {
        #if canImport(AlarmKit)
        let configuration = AlarmConfigurationBuilder.build(
            fireDate: fireDate,
            label: label,
            soundID: soundID
        )
        _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
        return id
        #else
        return id
        #endif
    }

    public func cancel(id: UUID) async throws {
        #if canImport(AlarmKit)
        try AlarmManager.shared.cancel(id: id)
        #endif
    }

    public func cancelAll() async throws {
        #if canImport(AlarmKit)
        for alarm in (try? AlarmManager.shared.alarms) ?? [] {
            try? AlarmManager.shared.cancel(id: alarm.id)
        }
        #endif
    }

    public func listScheduled() async -> [UUID] {
        #if canImport(AlarmKit)
        return ((try? AlarmManager.shared.alarms) ?? []).map(\.id)
        #else
        return []
        #endif
    }
}

public enum AlarmAuthorizationState: Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
}
