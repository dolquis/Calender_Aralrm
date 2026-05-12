import Foundation
import SwiftData

@MainActor
public enum DeepLinkRouter {
    public static func parse(_ url: URL) -> DeepLinkAction {
        guard url.scheme == "shiftalarm" else { return .unknown }
        guard url.host == "import" else { return .unknown }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let payload = components?.queryItems?.first(where: { $0.name == "payload" })?.value else {
            return .unknown
        }
        guard let data = Data(base64Encoded: payload),
              let bundle = try? ShiftBundleCodec.decode(data) else {
            return .unknown
        }
        return .importPayload(bundle)
    }

    /// Applies a parsed action. The import flow defers UI confirmation to ImportView, so this entry
    /// is intentionally conservative: it stores the bundle into a transient holder.
    public static func handle(_ url: URL, dependencies: AppDependencies) {
        let action = parse(url)
        switch action {
        case .importPayload(let bundle):
            DeepLinkInbox.shared.pending = bundle
        case .unknown:
            break
        }
    }
}

@MainActor
public final class DeepLinkInbox {
    public static let shared = DeepLinkInbox()
    public var pending: ShiftBundle?
    private init() {}
}
