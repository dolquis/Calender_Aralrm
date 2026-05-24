import Foundation

/// Snapshot tests are gated behind the `SNAPSHOT_TESTING_ENABLED` environment variable so CI runs
/// stay green even when no reference images are present in the repo yet. To record / verify
/// locally:
///
///     SNAPSHOT_TESTING_ENABLED=1 xcodebuild test \
///       -project ShiftAlarm.xcodeproj -scheme ShiftAlarm \
///       -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
///
/// The first run records snapshots into `Tests/SnapshotTests/__Snapshots__/`. Commit those
/// references and subsequent runs will fail if a view drifts.
enum SnapshotTestGate {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["SNAPSHOT_TESTING_ENABLED"] == "1"
    }
}
