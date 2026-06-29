import Foundation
import Testing

@testable import ShiftAlarm

struct DayDetailEditorSavePlannerTests {
    @Test
    func testCoveredSwapMutesAndClearsPresetAndTime() {
        let presetID = UUID()
        let draft = DayAssignmentDraft(
            presetID: presetID,
            overrideAlarmHour: 7,
            overrideAlarmMinute: 30,
            skipAlarm: false,
            note: "keep"
        )

        let action = DayDetailEditorSavePlanner.assignmentAction(
            currentDraft: draft,
            swapEnabled: true,
            swapKind: .covered,
            hasExistingAssignment: false
        )

        #expect(
            action
                == .upsert(
                    DayAssignmentDraft(
                        presetID: nil,
                        skipAlarm: true,
                        note: "keep"
                    )))
    }

    @Test
    func testCoveringSwapRegistersSelectedPreset() {
        let presetID = UUID()
        let draft = DayAssignmentDraft(
            presetID: presetID,
            overrideAlarmHour: nil,
            overrideAlarmMinute: nil,
            skipAlarm: true,
            note: ""
        )

        let action = DayDetailEditorSavePlanner.assignmentAction(
            currentDraft: draft,
            swapEnabled: true,
            swapKind: .covering,
            hasExistingAssignment: false
        )

        #expect(
            action
                == .upsert(
                    DayAssignmentDraft(
                        presetID: presetID,
                        skipAlarm: false,
                        note: ""
                    )))
    }

    @Test
    func testDisablingExistingSwapKeepsUnchangedLoadedAssignment() {
        let presetID = UUID()
        let loadedDraft = DayAssignmentDraft(
            presetID: presetID,
            skipAlarm: false,
            note: ""
        )

        let action = DayDetailEditorSavePlanner.assignmentAction(
            currentDraft: loadedDraft,
            swapEnabled: false,
            swapKind: .covering,
            hasExistingAssignment: true
        )

        #expect(action == .upsert(loadedDraft))
    }

    @Test
    func testDisablingExistingSwapKeepsUserEditedManualAssignment() {
        let presetID = UUID()
        let editedDraft = DayAssignmentDraft(
            presetID: presetID,
            skipAlarm: false,
            note: "manual"
        )

        let action = DayDetailEditorSavePlanner.assignmentAction(
            currentDraft: editedDraft,
            swapEnabled: false,
            swapKind: .covering,
            hasExistingAssignment: true
        )

        #expect(action == .upsert(editedDraft))
    }
}
