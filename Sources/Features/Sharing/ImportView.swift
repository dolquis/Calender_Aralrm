import SwiftData
import SwiftUI
import UniformTypeIdentifiers

public struct ImportView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var pickerPresented = false
    @State private var loadedBundle: ShiftBundle?
    @State private var preview: ImportPreview?
    @State private var selectedItemIDs: Set<UUID> = []
    @State private var errorMessage: String?
    @State private var applied = false

    private let initialBundle: ShiftBundle?

    public init(initialBundle: ShiftBundle? = nil) {
        self.initialBundle = initialBundle
    }

    private var bundleType: UTType {
        UTType(filenameExtension: "shiftalarm") ?? UTType.json
    }

    public var body: some View {
        Form {
            Section("import.pick_section") {
                Button {
                    pickerPresented = true
                } label: {
                    Label("import.pick_file", systemImage: "doc.badge.plus")
                }
            }
            if let preview {
                ImportPreviewView(preview: preview, selectedItemIDs: $selectedItemIDs)
                Section {
                    Button("import.apply", action: apply)
                        .disabled(!preview.canApply(selectedItemIDs: selectedItemIDs) || applied)
                    if applied {
                        Text("import.applied")
                            .foregroundStyle(.green)
                    }
                }
            }
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
        .navigationTitle("settings.import")
        .fileImporter(
            isPresented: $pickerPresented,
            allowedContentTypes: [bundleType, .json],
            allowsMultipleSelection: false
        ) { result in
            handlePicker(result)
        }
        .task {
            if let bundle = initialBundle, loadedBundle == nil {
                load(bundle: bundle)
            }
        }
    }

    private func load(bundle: ShiftBundle) {
        loadedBundle = bundle
        let nextPreview = ShareImporter.preview(
            bundle: bundle, container: dependencies.modelContainer)
        preview = nextPreview
        selectedItemIDs = nextPreview.changePreview.selectedItemIDs
        applied = false
        errorMessage = nil
    }

    private func handlePicker(_ result: Result<[URL], Error>) {
        errorMessage = nil
        applied = false
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let didStart = url.startAccessingSecurityScopedResource()
            defer { if didStart { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let bundle = try ShiftBundleCodec.decode(data)
                load(bundle: bundle)
            } catch {
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func apply() {
        guard let bundle = loadedBundle else { return }
        do {
            try ShareImporter.apply(
                bundle: bundle,
                container: dependencies.modelContainer,
                selectedItemIDs: selectedItemIDs
            )
            applied = true
            Task {
                await dependencies.alarmScheduler.refreshScheduledAlarms()
                await dependencies.liveActivityController.evaluate()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
