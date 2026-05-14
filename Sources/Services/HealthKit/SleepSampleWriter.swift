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

    /// Bulk-writes sleep samples for past windows. Skips any window that already has a matching
    /// sample (strict start-date match) so revisiting the view never creates duplicates.
    public func writePastSamples(from windows: [SleepWindow]) async {
        #if canImport(HealthKit)
        for window in Self.pastWindows(from: windows, now: .now) {
            guard !(await sampleExists(at: window.bedtime)) else { continue }
            try? await writeSleepSample(bedtime: window.bedtime, wakeTime: window.wakeTime)
        }
        #endif
    }

    /// Pure filter: a window counts as "past" once its wake time has already elapsed.
    /// Exposed for unit tests so the selection rule can be verified without HealthKit.
    nonisolated static func pastWindows(from windows: [SleepWindow], now: Date) -> [SleepWindow] {
        windows.filter { $0.wakeTime <= now }
    }

    #if canImport(HealthKit)
    /// Returns true when HealthKit already contains a sleep-analysis sample starting at `bedtime`.
    private func sampleExists(at bedtime: Date) async -> Bool {
        let predicate = HKQuery.predicateForSamples(
            withStart: bedtime,
            end: bedtime.addingTimeInterval(1),
            options: .strictStartDate
        )
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: !(samples ?? []).isEmpty)
            }
            self.store.execute(query)
        }
    }
    #endif
}
