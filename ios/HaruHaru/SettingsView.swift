import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    @AppStorage(Reminders.checkInEnabledKey) private var checkInOn = false
    @AppStorage(Reminders.checkInTimeKey) private var checkInTime = Reminders.defaultCheckInTime

    @State private var exportURL: URL?
    @State private var showImporter = false
    @State private var pendingImport: AppData?
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Evening check-in", isOn: $checkInOn)
                    if checkInOn {
                        DatePicker("Time", selection: checkInDate, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("A nudge listing what's left, skipped on days you finish everything. Set reminders for individual tasks by swiping right on them.")
                }

                Section {
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Export backup", systemImage: "square.and.arrow.up")
                        }
                    }
                    Button {
                        showImporter = true
                    } label: {
                        Label("Import backup", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Backups are JSON files and work with the Haru-haru web app too.")
                }

                Section {
                    LabeledContent("Version", value: appVersion)
                } footer: {
                    Text("하루하루 — day by day.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { exportURL = try? store.exportFile() }
            .onChange(of: checkInOn) { on in
                Task {
                    if on { await Reminders.requestPermission() }
                    store.refreshDay()
                }
            }
            .onChange(of: checkInTime) { _ in store.refreshDay() }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                handleImport(result)
            }
            .alert("Replace your current tasks?", isPresented: Binding(
                get: { pendingImport != nil },
                set: { if !$0 { pendingImport = nil } }
            )) {
                Button("Replace", role: .destructive) {
                    if let pendingImport { store.replace(with: pendingImport) }
                    pendingImport = nil
                    message = "Imported."
                }
                Button("Cancel", role: .cancel) { pendingImport = nil }
            } message: {
                Text("Everything in the app will be replaced with the backup.")
            }
            .alert(message ?? "", isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private var checkInDate: Binding<Date> {
        Binding(
            get: { ClockTime.date(from: checkInTime) },
            set: { checkInTime = ClockTime.string(from: $0) }
        )
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    private func handleImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            pendingImport = try JSONDecoder().decode(AppData.self, from: Data(contentsOf: url))
        } catch {
            message = "That file isn't a Haru-haru backup."
        }
    }
}
