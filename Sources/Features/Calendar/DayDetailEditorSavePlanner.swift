import Foundation

struct DayAssignmentDraft: Equatable, Sendable {
    var presetID: UUID?
    var overrideAlarmHour: Int?
    var overrideAlarmMinute: Int?
    var skipAlarm: Bool
    var note: String

    init(
        presetID: UUID?,
        overrideAlarmHour: Int? = nil,
        overrideAlarmMinute: Int? = nil,
        skipAlarm: Bool,
        note: String
    ) {
        self.presetID = presetID
        self.overrideAlarmHour = overrideAlarmHour
        self.overrideAlarmMinute = overrideAlarmMinute
        self.skipAlarm = skipAlarm
        self.note = note
    }

    init(assignment: DayAssignment) {
        self.init(
            presetID: assignment.preset?.id,
            overrideAlarmHour: assignment.overrideAlarmHour,
            overrideAlarmMinute: assignment.overrideAlarmMinute,
            skipAlarm: assignment.skipAlarm,
            note: assignment.note
        )
    }

    var isNonEmpty: Bool {
        presetID != nil || overrideAlarmHour != nil || overrideAlarmMinute != nil || skipAlarm
            || !note.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

enum DayAssignmentPersistenceAction: Equatable {
    case none
    case delete
    case upsert(DayAssignmentDraft)
}

enum DayDetailEditorSavePlanner {
    static func assignmentAction(
        currentDraft: DayAssignmentDraft,
        swapEnabled: Bool,
        swapKind: SwapRecord.Kind,
        hasExistingAssignment: Bool,
        existingSwapKind: SwapRecord.Kind?,
        loadedAssignmentDraft: DayAssignmentDraft?
    ) -> DayAssignmentPersistenceAction {
        if !swapEnabled,
            existingSwapKind != nil,
            loadedAssignmentDraft.map({ $0 == currentDraft }) == true
        {
            return hasExistingAssignment ? .delete : .none
        }

        let resolvedDraft = resolvedAssignmentDraft(
            from: currentDraft,
            swapEnabled: swapEnabled,
            swapKind: swapKind
        )
        if hasExistingAssignment {
            return .upsert(resolvedDraft)
        }
        return resolvedDraft.isNonEmpty ? .upsert(resolvedDraft) : .none
    }

    static func resolvedAssignmentDraft(
        from draft: DayAssignmentDraft,
        swapEnabled: Bool,
        swapKind: SwapRecord.Kind
    ) -> DayAssignmentDraft {
        guard swapEnabled else { return draft }

        switch swapKind {
        case .covered:
            return DayAssignmentDraft(
                presetID: nil,
                skipAlarm: true,
                note: draft.note
            )
        case .covering, .exchange:
            var updated = draft
            updated.skipAlarm = false
            return updated
        }
    }
}
