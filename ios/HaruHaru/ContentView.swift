import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: Store
    @State private var newTitle = ""
    @State private var newKind: TaskKind = .once
    @State private var editTarget: EditTarget?
    @State private var showSettings = false
    @State private var editMode: EditMode = .inactive
    @FocusState private var composerFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HeaderView()
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))

                taskSection(.daily, title: "Every day",
                            empty: "Add habits you want to do every day. They reset at midnight.")
                taskSection(.once, title: "Today",
                            empty: "One-off tasks for today. Unfinished ones carry over to tomorrow.")
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, $editMode)
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) { composer }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(editMode.isEditing ? "Done" : "Edit") {
                        withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                    }
                    .fontWeight(editMode.isEditing ? .semibold : .regular)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
            }
            .sheet(item: $editTarget) { target in
                TaskEditor(target: target).environmentObject(store)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView().environmentObject(store)
            }
        }
    }

    @ViewBuilder
    private func taskSection(_ kind: TaskKind, title: String, empty: String) -> some View {
        let items = store.tasks(kind)
        Section {
            if items.isEmpty {
                Text(empty)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                ForEach(items) { task in
                    TaskRow(kind: kind, task: task) {
                        if editMode.isEditing {
                            editTarget = EditTarget(kind: kind, task: task)
                        } else {
                            Haptics.tap()
                            withAnimation(.easeOut(duration: 0.15)) { store.toggle(kind, task) }
                        }
                    }
                    .contextMenu {
                        Button { editTarget = EditTarget(kind: kind, task: task) } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) { store.delete(kind, id: task.id) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button { editTarget = EditTarget(kind: kind, task: task) } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.accentColor)
                    }
                }
                .onDelete { store.delete(kind, at: $0) }
                .onMove { store.move(kind, from: $0, to: $1) }
            }
        } header: {
            HStack {
                Text(title)
                Spacer()
                if !items.isEmpty {
                    let done = items.filter { store.isDone(kind, $0) }.count
                    Text("\(done)/\(items.count)").monospacedDigit()
                }
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Task type", selection: $newKind) {
                Text("Today").tag(TaskKind.once)
                Text("Every day").tag(TaskKind.daily)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)

            HStack(spacing: 8) {
                TextField("Add a task…", text: $newTitle)
                    .focused($composerFocused)
                    .submitLabel(.done)
                    .onSubmit(addTask)
                    .padding(.leading, 12)
                Button(action: addTask) {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .accessibilityLabel("Add task")
                .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(6)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(.separator), lineWidth: 0.5))
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.bar)
    }

    private func addTask() {
        guard !newTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        withAnimation { store.add(newTitle, kind: newKind) }
        newTitle = ""
        composerFocused = true
    }
}

struct EditTarget: Identifiable {
    let kind: TaskKind
    let task: TaskItem
    var id: String { task.id }
}

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
