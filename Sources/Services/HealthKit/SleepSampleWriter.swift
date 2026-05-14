import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

/// Writes planned sleep windows as HealthKit sleep analysis samples.
/// This populates the Health app's Sleep chart but does NOT modify the system Sleep Schedule.
@MainActor
public final class SleepSampleWriter {
    #if canImport(HealthKit)
    private let store = HKHealthStore()
    private let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    #endif

    public init() {}

    public var isAvailable: Bool {
        #if canImport(HealthKit)
        return HKHealthStore.isHealthDataAvailable()
        #else
        return false
        #endif
    }

    /// Requests HealthKit write authorization. Returns true only if the user granted sharing.
    /// Note: HealthKit's requestAuthorization() succeeds even when the user denies access,
    /// so we must query authorizationStatus afterward to confirm the actual grant.
    public func requestAuthorization() async -> Bool {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        do {
            try await store.requestAuthorization(toShare: [sleepType], read: [])
        } catch {
            return false
        }
        return store.authorizationStatus(for: sleepType) == .sharingAuthorized
        #else
        return false
        #endif
    }

    /// Writes a sleep analysis sample for the given window.
    /// Call this after a wake alarm fires to record the intended sleep for that night.
    public func writeSleepSample(bedtime: Date, wakeTime: Date) async throws {
        #if canImport(HealthKit)
        guard bedtime < wakeTime else { return }
        let sample = HKCategorySample(
            type: sleepType,
            value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            start: bedtime,
            end: wakeTime,
            metadata: [HKMetadataKeyWasUserEntered: true]
        )
        try await store.save(sample)
        #endif
    }

    /// Bulk-writes sleep samples for upcoming windows that haven't been recorded yet.
    /// Skips windows whose bedtime is in the future to avoid writing speculative data.
    public func writePastSamples(from windows: [SleepWindow]) async {
        #if canImport(HealthKit)
        let now = Date.now
        let past = windows.filter { $0.wakeTime <= now }
        for window in past {
            try? await writeSleepSample(bedtime: window.bedtime, wakeTime: window.wakeTime)
        }
        #endif
    }
}
