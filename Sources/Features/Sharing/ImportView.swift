import SwiftUI
import SwiftData
import UniformTypeIdentifiers

public struct ImportView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var pickerPresented = false
    @State private var loadedBundle: ShiftBundle?
    @State private var preview: ImportPreview?
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
                Section("import.preview_section") {
                    row("import.presets_added", value: preview.addedPresets)
                    row("import.presets_updated", value: preview.updatedPresets)
                    row("import.patterns_added", value: preview.addedPatterns)
                    row("import.patterns_updated", value: preview.updatedPatterns)
                    row("import.assignments_added", value: preview.addedAssignments)
                    row("import.assignments_updated", value: preview.updatedAssignments)
                    row("import.overrides_added", value: preview.addedOverrides)
                    row("import.overrides_updated", value: preview.updatedOverrides)
                }
                Section {
                    Button("import.apply", action: apply)
                        .disabled(!preview.hasChanges || applied)
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
        preview = ShareImporter.preview(bundle: bundle, container: dependencies.modelContainer)
        applied = false
        errorMessage = nil
    }

    private func row(_ key: LocalizedStringKey, value: Int) -> some View {
        LabeledContent {
            Text("\(value)").monospacedDigit()
        } label: {
            Text(key)
        }
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
            try ShareImporter.apply(bundle: bundle, container: dependencies.modelContainer)
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
