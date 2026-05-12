import Foundation

public enum DeepLinkAction: Equatable, Sendable {
    case importPayload(ShiftBundle)
    case unknown
}
