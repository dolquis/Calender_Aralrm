import Foundation
import CryptoKit

/// Detects repeating shift cycles from manual-assignment history and proposes a RotationPattern.
public struct ShiftPatternDetector: Sendable {

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public var windowDays: Int = 90
        public var minCycleLength: Int = 2
        public var maxCycleLength: Int = 35
        public var minCycles: Int = 2
        public var minMatchRate: Double = 0.85
        public var minDensityPerSlot: Double = 0.5

        public init() {}
    }

    // MARK: - Symbol

    public enum Symbol: Equatable, Hashable, Sendable {
        case preset(UUID)
        case off
    }

    // MARK: - Output

    public struct SuggestedRotation: Equatable, Sendable {
        public let anchorDate: Date
        public let cycleLength: Int
        /// nil element = rest / off day.
        public let slots: [UUID?]
        public let confidence: Double
        public let observedDays: Int
        /// SHA-256 hex of "\(cycleLength)|\(slots)" — used for snooze matching.
        public let fingerprint: String

        public init(
            anchorDate: Date,
            cycleLength: Int,
            slots: [UUID?],
            confidence: Double,
            observedDays: Int,
            fingerprint: String
        ) {
            self.anchorDate = anchorDate
            self.cycleLength = cycleLength
            self.slots = slots
            self.confidence = confidence
            self.observedDays = observedDays
            self.fingerprint = fingerprint
        }
    }

    // MARK: - Init

    public let configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    // MARK: - Detection

    /// Detects the best-fitting cycle from `manualAssignments`.
    ///
    /// Only manual assignments are inspected; rotation-derived days are never persisted
    /// as `DayAssignment` rows, so they are implicitly excluded.
    public func detect(
        manualAssignments: [Date: DayAssignmentSnapshot],
        presets: [UUID: ShiftPresetSnapshot],
        today: Date,
        calendar: Calendar
    ) -> SuggestedRotation? {
        let windowStart = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: -configuration.windowDays, to: today)!
        )
        let normalizedAssignments = manualAssignments
            .sorted { $0.key < $1.key }
            .reduce(into: [Date: DayAssignmentSnapshot]()) { result, entry in
                result[calendar.startOfDay(for: entry.key)] = entry.value
            }

        // Build ordered series [Symbol?] length windowDays; nil = wildcard
        var series: [Symbol?] = Array(repeating: nil, count: configuration.windowDays)
        for i in 0..<configuration.windowDays {
            let day = calendar.date(byAdding: .day, value: i, to: windowStart)!
            if let snap = normalizedAssignments[day] {
                series[i] = symbol(for: snap, presets: presets)
            }
        }
        let observedCount = series.compactMap { $0 }.count
        guard observedCount > 0 else { return nil }

        var bestRotation: SuggestedRotation?
        var bestMatchRate: Double = -1

        for cycleLength in configuration.minCycleLength...configuration.maxCycleLength {
            let possibleOccurrencesBySlot = (0..<cycleLength).map { slot in
                possibleOccurrences(slot: slot, cycleLength: cycleLength, windowDays: configuration.windowDays)
            }
            guard possibleOccurrencesBySlot.allSatisfy({ $0 >= configuration.minCycles }) else { continue }

            var slotObs: [[Symbol]] = Array(repeating: [], count: cycleLength)
            for i in 0..<configuration.windowDays {
                guard let sym = series[i] else { continue }
                slotObs[i % cycleLength].append(sym)
            }

            var totalMatches = 0
            var totalObserved = 0
            var modeSymbols: [Symbol?] = Array(repeating: nil, count: cycleLength)
            var densityOk = true

            for s in 0..<cycleLength {
                let obs = slotObs[s]
                let density = Double(obs.count) / Double(possibleOccurrencesBySlot[s])
                guard density >= configuration.minDensityPerSlot else { densityOk = false; break }

                // Find mode; tiebreak = first occurrence wins (lower series index = earlier)
                var counts: [Symbol: Int] = [:]
                var firstIdx: [Symbol: Int] = [:]
                for (idx, sym) in obs.enumerated() {
                    counts[sym, default: 0] += 1
                    if firstIdx[sym] == nil { firstIdx[sym] = idx }
                }
                let mode = counts.max { a, b in
                    a.value != b.value ? a.value < b.value : (firstIdx[a.key] ?? 0) > (firstIdx[b.key] ?? 0)
                }?.key
                modeSymbols[s] = mode
                let matchCount = mode.map { m in obs.filter { $0 == m }.count } ?? 0
                totalMatches += matchCount
                totalObserved += obs.count
            }

            guard densityOk else { continue }
            let overallMatchRate = totalObserved > 0 ? Double(totalMatches) / Double(totalObserved) : 0
            guard overallMatchRate >= configuration.minMatchRate else { continue }

            // Prefer higher match rate; tiebreak = shorter cycle (simpler)
            guard overallMatchRate > bestMatchRate
                || (overallMatchRate == bestMatchRate && cycleLength < (bestRotation?.cycleLength ?? Int.max))
            else { continue }

            // Normalize anchor to the first Monday on or after windowStart (α-U12)
            let anchorDate = firstMonday(onOrAfter: windowStart, calendar: calendar)
            let phaseShift = calendar.dateComponents([.day], from: windowStart, to: anchorDate).day ?? 0
            let rotatedModes = rotate(modeSymbols, by: phaseShift % cycleLength)

            let slots: [UUID?] = rotatedModes.map {
                if case .preset(let id) = $0 { return id }
                return nil
            }
            bestRotation = SuggestedRotation(
                anchorDate: anchorDate,
                cycleLength: cycleLength,
                slots: slots,
                confidence: overallMatchRate,
                observedDays: observedCount,
                fingerprint: fingerprint(cycleLength: cycleLength, slots: slots)
            )
            bestMatchRate = overallMatchRate
        }
        return bestRotation
    }

    // MARK: - Drift Detection (A1)

    /// Returns a new `SuggestedRotation` if the active pattern has drifted beyond `threshold`.
    public func detectDrift(
        pattern: RotationPatternSnapshot,
        recentManualAssignments: [Date: DayAssignmentSnapshot],
        presets: [UUID: ShiftPresetSnapshot],
        today: Date,
        calendar: Calendar,
        threshold: Double
    ) -> SuggestedRotation? {
        let windowStart = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: -30, to: today)!
        )
        var mismatches = 0
        var observed = 0
        for i in 0..<30 {
            let day = calendar.date(byAdding: .day, value: i, to: windowStart)!
            guard let manual = recentManualAssignments[day] else { continue }
            let expected = RotationExpander.presetID(for: day, pattern: pattern, calendar: calendar)
            let manualPresetID = manual.skipAlarm ? nil : manual.presetID
            if manualPresetID != expected { mismatches += 1 }
            observed += 1
        }
        guard observed > 0 else { return nil }
        let mismatchRate = Double(mismatches) / Double(observed)
        guard mismatchRate >= threshold else { return nil }
        return detect(
            manualAssignments: recentManualAssignments,
            presets: presets,
            today: today,
            calendar: calendar
        )
    }

    // MARK: - Helpers

    private func symbol(for assignment: DayAssignmentSnapshot, presets: [UUID: ShiftPresetSnapshot]) -> Symbol? {
        guard !assignment.skipAlarm else { return .off }
        guard let presetID = assignment.presetID else { return .off }
        guard presets[presetID] != nil else { return nil }
        return .preset(presetID)
    }

    private func possibleOccurrences(slot: Int, cycleLength: Int, windowDays: Int) -> Int {
        guard slot < windowDays else { return 0 }
        return ((windowDays - 1 - slot) / cycleLength) + 1
    }

    private func firstMonday(onOrAfter date: Date, calendar: Calendar) -> Date {
        var current = date
        // weekday 2 = Monday in Gregorian with firstWeekday=1 (Sun)
        // We use 2 consistently; Swift Calendar weekday is 1(Sun)..7(Sat)
        while calendar.component(.weekday, from: current) != 2 {
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        return current
    }

    /// Left-rotates `array` by `shift` positions so that element at index `shift`
    /// moves to index 0. Used to align the anchor date with slot 0.
    private func rotate(_ array: [Symbol?], by shift: Int) -> [Symbol?] {
        guard !array.isEmpty, shift > 0 else { return array }
        let n = array.count
        let s = ((shift % n) + n) % n
        guard s > 0 else { return array }
        return Array(array.suffix(from: s) + array.prefix(s))
    }

    private func fingerprint(cycleLength: Int, slots: [UUID?]) -> String {
        let raw = "\(cycleLength)|\(slots.map { $0?.uuidString ?? "nil" }.joined(separator: ","))"
        let hash = SHA256.hash(data: Data(raw.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
