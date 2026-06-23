import Foundation

public enum VacationAwareRotation {
    private static let daytimeAlarmHours = 4...12

    public static func presetID(
        for day: Date,
        pattern: RotationPatternSnapshot,
        vacations: [VacationPeriodSnapshot],
        presets: [UUID: ShiftPresetSnapshot],
        calendar: Calendar = .current
    ) -> UUID? {
        presetID(
            for: day,
            pattern: pattern,
            normalizedVacations: Self.normalizedVacations(vacations, calendar: calendar),
            presets: presets,
            calendar: calendar
        )
    }

    static func presetID(
        for day: Date,
        pattern: RotationPatternSnapshot,
        normalizedVacations: [VacationPeriodSnapshot],
        presets: [UUID: ShiftPresetSnapshot],
        calendar: Calendar = .current
    ) -> UUID? {
        guard pattern.cycleLength > 0, pattern.slots.count == pattern.cycleLength else {
            return nil
        }

        let target = calendar.startOfDay(for: day)

        if normalizedVacations.contains(where: { $0.startDate <= target && target <= $0.endDate }) {
            return nil
        }

        let effectiveStart = calendar.startOfDay(for: pattern.startDate ?? pattern.anchorDate)
        let cycle = pattern.cycleLength
        var shift = 0
        var phase = 0

        for index in normalizedVacations.indices {
            let vacation = normalizedVacations[index]
            guard vacation.endDate < target else { continue }
            guard vacation.endDate >= effectiveStart else { continue }

            let vacationStart = max(vacation.startDate, effectiveStart)
            let previousVacationEnd: Date? = {
                guard index > normalizedVacations.startIndex else { return nil }
                return normalizedVacations[index - 1].endDate
            }()
            let lowerBound: Date
            if let previousVacationEnd,
                let dayAfterPrevious = calendar.date(
                    byAdding: .day, value: 1, to: previousVacationEnd)
            {
                lowerBound = max(effectiveStart, dayAfterPrevious)
            } else {
                lowerBound = effectiveStart
            }

            let previousWorkingIndex = lastWorkingSlotIndex(
                before: vacationStart,
                lowerBound: lowerBound,
                pattern: pattern,
                shift: shift,
                phase: phase,
                calendar: calendar
            )
            let policy = policyFor(
                previousWorkingIndex: previousWorkingIndex,
                pattern: pattern,
                presets: presets
            )

            let duration =
                calendar.dateComponents(
                    [.day],
                    from: vacationStart,
                    to: vacation.endDate
                ).day ?? 0
            shift -= duration + 1

            switch effectivePolicy(policy, cycleLength: cycle) {
            case .continue:
                break
            case .invert:
                phase += cycle / 2
            case .resetToDay:
                guard let dayAfter = calendar.date(byAdding: .day, value: 1, to: vacation.endDate)
                else {
                    break
                }
                let indexAfterContinue = slotIndex(
                    for: dayAfter,
                    pattern: pattern,
                    shift: shift,
                    phase: phase,
                    calendar: calendar
                )
                phase += positiveModulo(
                    effectiveDayStartSlot(pattern: pattern, presets: presets) - indexAfterContinue,
                    cycle
                )
            }
        }

        let index = slotIndex(
            for: target,
            pattern: pattern,
            shift: shift,
            phase: phase,
            calendar: calendar
        )
        return pattern.slots[index]
    }

    static func normalizedVacations(
        _ vacations: [VacationPeriodSnapshot],
        calendar: Calendar
    ) -> [VacationPeriodSnapshot] {
        let sorted =
            vacations
            .map {
                VacationPeriodSnapshot(
                    startDate: calendar.startOfDay(for: $0.startDate),
                    endDate: calendar.startOfDay(for: $0.endDate),
                    label: $0.label
                )
            }
            .filter { $0.startDate <= $0.endDate }
            .sorted {
                if $0.startDate == $1.startDate {
                    return $0.endDate < $1.endDate
                }
                return $0.startDate < $1.startDate
            }

        var output: [VacationPeriodSnapshot] = []
        for vacation in sorted {
            guard let last = output.last,
                let dayAfterLast = calendar.date(byAdding: .day, value: 1, to: last.endDate),
                vacation.startDate <= dayAfterLast
            else {
                output.append(vacation)
                continue
            }
            output[output.count - 1] = VacationPeriodSnapshot(
                startDate: last.startDate,
                endDate: max(last.endDate, vacation.endDate),
                label: last.label
            )
        }
        return output
    }

    private static func lastWorkingSlotIndex(
        before date: Date,
        lowerBound: Date,
        pattern: RotationPatternSnapshot,
        shift: Int,
        phase: Int,
        calendar: Calendar
    ) -> Int? {
        guard var probe = calendar.date(byAdding: .day, value: -1, to: date) else { return nil }
        var remainingLookbackDays = pattern.cycleLength
        while probe >= lowerBound && remainingLookbackDays > 0 {
            let index = slotIndex(
                for: probe,
                pattern: pattern,
                shift: shift,
                phase: phase,
                calendar: calendar
            )
            if pattern.slots[index] != nil {
                return index
            }
            remainingLookbackDays -= 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: probe) else {
                return nil
            }
            probe = previous
        }
        return nil
    }

    private static func policyFor(
        previousWorkingIndex: Int?,
        pattern: RotationPatternSnapshot,
        presets: [UUID: ShiftPresetSnapshot]
    ) -> CrossVacationPolicy {
        guard let previousWorkingIndex,
            let presetID = pattern.slots[previousWorkingIndex],
            let override = presets[presetID]?.crossVacationPolicy
        else {
            return pattern.crossVacationPolicy
        }
        return override
    }

    private static func effectivePolicy(
        _ policy: CrossVacationPolicy,
        cycleLength: Int
    ) -> CrossVacationPolicy {
        policy == .invert && !cycleLength.isMultiple(of: 2) ? .continue : policy
    }

    private static func effectiveDayStartSlot(
        pattern: RotationPatternSnapshot,
        presets: [UUID: ShiftPresetSnapshot]
    ) -> Int {
        if let explicit = pattern.dayStartSlotIndex,
            (0..<pattern.cycleLength).contains(explicit)
        {
            return explicit
        }
        return pattern.slots.enumerated()
            .compactMap { index, presetID -> (index: Int, hour: Int)? in
                guard let presetID,
                    let hour = presets[presetID]?.alarmTime?.hour,
                    Self.daytimeAlarmHours.contains(hour)
                else { return nil }
                return (index, hour)
            }
            .min {
                if $0.hour == $1.hour {
                    return $0.index < $1.index
                }
                return $0.hour < $1.hour
            }?.index ?? 0
    }

    private static func slotIndex(
        for day: Date,
        pattern: RotationPatternSnapshot,
        shift: Int,
        phase: Int,
        calendar: Calendar
    ) -> Int {
        let anchor = calendar.startOfDay(for: pattern.anchorDate)
        let target = calendar.startOfDay(for: day)
        let dayDelta = calendar.dateComponents([.day], from: anchor, to: target).day ?? 0
        return positiveModulo(dayDelta + shift + phase, pattern.cycleLength)
    }

    private static func positiveModulo(_ value: Int, _ divisor: Int) -> Int {
        ((value % divisor) + divisor) % divisor
    }
}
