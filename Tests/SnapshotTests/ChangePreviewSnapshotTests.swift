import Foundation
import SnapshotTesting
import SwiftUI
import Testing

@testable import ShiftAlarm

@MainActor
@Suite(.serialized, .snapshots(record: .missing))
struct ChangePreviewSnapshotTests {
    private func samplePreview() -> ChangePreview {
        let day = Date(timeIntervalSince1970: 1_779_552_000)
        return ChangePreview(sections: [
            ChangePreviewSection(
                sourcePath: "snapshot:presets", title: "Presets",
                items: [
                    ChangePreviewItem(
                        sourcePath: "shiftalarm:presets[0]",
                        entityKind: .preset,
                        changeKind: .add,
                        afterText: "Day · alarm 07:00"
                    )
                ]),
            ChangePreviewSection(
                sourcePath: "snapshot:assignments", title: "Assignments",
                items: [
                    ChangePreviewItem(
                        sourcePath: "shiftalarm:assignments[0]",
                        date: day,
                        entityKind: .dayAssignment,
                        changeKind: .update,
                        beforeText: "2026-05-14 · Night · alarm 22:00",
                        afterText: "2026-05-14 · Day · alarm 07:00",
                        warnings: [
                            "Color at presets[0].colorHex is invalid and will use the default color."
                        ]
                    ),
                    ChangePreviewItem(
                        sourcePath: "shiftalarm:assignments[1].date",
                        entityKind: .dayAssignment,
                        changeKind: .conflict,
                        afterText: "Duplicate date at assignments[1].date."
                    ),
                ]),
        ])
    }

    private func host(
        _ view: some View,
        size: CGSize = CGSize(width: 390, height: 720)
    ) -> UIViewController {
        let host = UIHostingController(rootView: view)
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.layoutIfNeeded()
        return host
    }

    @Test(.enabled { SnapshotTestGate.isEnabled })
    func testChangePreviewDynamicTypeXL() {
        let preview = samplePreview()
        let view = ChangePreviewSnapshotHarness(preview: preview)
            .environment(\.dynamicTypeSize, .accessibility3)

        assertSnapshot(of: host(view), as: .image)
    }
}

private struct ChangePreviewSnapshotHarness: View {
    let preview: ChangePreview
    @State private var selectedItemIDs: Set<UUID>

    init(preview: ChangePreview) {
        self.preview = preview
        self._selectedItemIDs = State(initialValue: preview.selectedItemIDs)
    }

    var body: some View {
        NavigationStack {
            Form {
                ChangePreviewView(preview: preview, selectedItemIDs: $selectedItemIDs)
            }
            .navigationTitle("Preview")
        }
    }
}
