import Foundation
import Observation

@Observable
@MainActor
public final class AlarmAuthorization {
    public private(set) var state: AlarmAuthorizationState = .notDetermined
    private let service: AlarmService

    public init(service: AlarmService) {
        self.service = service
    }

    public func refresh() async {
        state = await service.authorizationState()
    }

    @discardableResult
    public func requestIfNeeded() async -> AlarmAuthorizationState {
        if state == .notDetermined {
            state = await service.requestAuthorization()
        }
        return state
    }

    @discardableResult
    public func request() async -> AlarmAuthorizationState {
        state = await service.requestAuthorization()
        return state
    }
}
