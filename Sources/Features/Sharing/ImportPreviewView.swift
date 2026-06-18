import SwiftUI

public struct ImportPreviewView: View {
    let preview: ImportPreview
    @Binding var selectedItemIDs: Set<UUID>

    public init(preview: ImportPreview, selectedItemIDs: Binding<Set<UUID>>) {
        self.preview = preview
        self._selectedItemIDs = selectedItemIDs
    }

    public var body: some View {
        ChangePreviewView(
            preview: preview.changePreview,
            selectedItemIDs: $selectedItemIDs
        )
    }
}
