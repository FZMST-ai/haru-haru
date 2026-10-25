import SwiftUI

struct TaskEditor: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    let target: EditTarget
    @State private var title: String
    @State private var remindOn: Bool
    @State private var remindAt: Date

    init(target: EditTarget) {
        self.target = target
        _title = State(initialValue: target.task.title)
        _remindOn = State(initialValue: target.task.remind != nil)
        _remindAt = State(initialValue: ClockTime.date(from: target.task.remind ?? "09:00"))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task", text: $title)
                }
                Section {
                    Toggle("Remind me", isOn: $remindOn.animation())
                    if remindOn {
                        DatePicker("Time", selection: $remindAt, displayedComponents: .hourAndMinute)
                    }
                } footer: {
                    Text(target.kind == .daily
                         ? "A notification every day at this time, unless you've already done it."
                         : "A notification at this time each day until it's done.")
                }
                Section {
                    Button("Delete Task", role: .destructive) {
                        store.delete(target.kind, id: target.task.id)
                        dismiss()
                    }
                }
            }
            .navigationTitle(target.kind == .daily ? "Daily Habit" : "Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        var task = target.task
        task.title = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
        task.remind = remindOn ? ClockTime.string(from: remindAt) : nil
        store.update(target.kind, task)
        if remindOn {
            Task {
                await Reminders.requestPermission()
                store.refreshDay()
            }
        }
        dismiss()
    }
}
