import SwiftData
import SwiftUI

public struct ExportView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var fileURL: URL?
    @State private var preparing = false
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        Form {
            Section("export.summary_section") {
                Text("export.description")
                    .foregroundStyle(.secondary)
            }
            Section {
                Button {
                    prepare()
                } label: {
                    if preparing {
                        ProgressView()
                    } else {
                        Text("export.create")
                    }
                }
                .disabled(preparing)
                if let url = fileURL {
                    ShareLink(item: url) {
                        Label("export.share", systemImage: "square.and.arrow.up")
                    }
                }
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("settings.export")
    }

    private func prepare() {
        preparing = true
        errorMessage = nil
        let container = dependencies.modelContainer
        Task {
            do {
                let bundle = try ShareExporter.snapshot(from: container)
                let url = try ShareExporter.writeTemporaryFile(bundle: bundle)
                fileURL = url
            } catch {
                errorMessage = error.localizedDescription
            }
            preparing = false
        }
    }
}
