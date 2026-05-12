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

    public static func handle(_ url: URL, dependencies: AppDependencies) {
        switch parse(url) {
        case .importPayload(let bundle):
            dependencies.pendingImport = PendingImportBundle(bundle: bundle)
        case .unknown:
            break
        }
    }
}
