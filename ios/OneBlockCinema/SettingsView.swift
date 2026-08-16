import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: FilmSessionViewModel
    @State private var showDataShare = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        Form {
            Section("Your local data") {
                Text("Drafts stay on this device unless you explicitly enable a future sync service.")

                Button {
                    Task {
                        await viewModel.prepareLocalDataExport()
                        showDataShare = viewModel.localDataExportURL != nil
                    }
                } label: {
                    if viewModel.isPreparingLocalDataExport {
                        Label("Preparing Export…", systemImage: "hourglass")
                    } else {
                        Label("Export Project Data", systemImage: "square.and.arrow.up")
                    }
                }
                .disabled(viewModel.isPreparingLocalDataExport)

                Text("The JSON export includes project metadata and edit decisions. Source video and audio files are not duplicated.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Delete All Local Data", role: .destructive) {
                    showDeleteConfirmation = true
                }

                if let message = viewModel.localDataDeletionMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(CinemaColors.amber)
                }
            }

            Section("Connected features") {
                LabeledContent("Accounts", value: "Off")
                LabeledContent("Cloud sync", value: "Off")
                LabeledContent("Community", value: "Off")
                LabeledContent("AI Coach", value: "Off")
                Text("Creating, editing, previewing, and exporting films remain available without an account.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Label("No advertising or cross-app tracking", systemImage: "hand.raised.fill")
                Label("No private media analytics", systemImage: "eye.slash.fill")
            }

            #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("OBCDeviceQAEnabled") {
                    DeviceQAPanel()
                }
            #endif
        }
        .scrollContentBackground(.hidden)
        .background(CinemaColors.background)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("SETTINGS")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(CinemaColors.amber)
                    .accessibilityIdentifier("settings.title")
            }
        }
        .sheet(isPresented: $showDataShare) {
            if let url = viewModel.localDataExportURL {
                ShareSheet(items: [url])
            }
        }
        .confirmationDialog(
            "Delete all local data?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Projects and Media", role: .destructive) {
                Task { await viewModel.deleteAllLocalData() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This permanently deletes every local draft, app-owned clip and audio file, "
                    + "edit decision, recovery record, and pending sync operation. "
                    + "Exported films saved elsewhere are not affected."
            )
        }
        .alert("Data Export Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "The local data export could not be prepared.")
        }
    }
}
