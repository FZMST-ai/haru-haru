import SwiftUI

@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    @Published private(set) var data: AppData
    @Published private(set) var today = Day.key()

    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("haruharu.json")
        if let raw = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(AppData.self, from: raw) {
            data = decoded
        } else {
            data = AppData()
        }
        prune()
        persist()
    }

    // MARK: Persistence

    private func persist() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(data).write(to: fileURL, options: .atomic)
        } catch {
            print("Save failed: \(error)")
        }
        Reminders.reschedule(data: data, today: today)
    }

    private func mutate(_ change: (inout AppData) -> Void) {
        change(&data)
        persist()
    }

    /// Drop one-off tasks finished on earlier days and log entries older than ~1 year.
    private func prune() {
        let cutoff = Day.shift(today, by: -400)
        data.once.removeAll { $0.doneOn != nil && $0.doneOn != today }
        data.log = data.log.filter { $0.key >= cutoff }
    }

    /// Call when the app becomes active or the calendar day changes.
    func refreshDay() {
        let now = Day.key()
        if now != today {
            today = now
            prune()
        }
        persist()
    }

    // MARK: Queries

    func tasks(_ kind: TaskKind) -> [TaskItem] {
        kind == .daily ? data.daily : data.once
    }

    func isDone(_ kind: TaskKind, _ task: TaskItem) -> Bool {
        switch kind {
        case .daily: return data.log[today]?.contains(task.id) ?? false
        case .once: return task.doneOn != nil
        }
    }

    func streak(_ task: TaskItem) -> Int {
        func done(_ day: String) -> Bool { data.log[day]?.contains(task.id) ?? false }
        var day = done(today) ? today : Day.shift(today, by: -1)
        var n = 0
        while done(day) {
            n += 1
            day = Day.shift(day, by: -1)
        }
        return n
    }

    var progress: (done: Int, total: Int) {
        let dailyDone = data.daily.filter { isDone(.daily, $0) }.count
        let onceDone = data.once.filter { $0.doneOn != nil }.count
        return (dailyDone + onceDone, data.daily.count + data.once.count)
    }

    struct WeekDay: Identifiable {
        let key: String
        let fraction: Double
        let hasHabits: Bool
        let isToday: Bool
        var id: String { key }
    }

    /// Habit completion for the last 7 days, oldest first.
    var week: [WeekDay] {
        (0..<7).reversed().map { offset in
            let day = Day.shift(today, by: -offset)
            let habits = data.daily.filter { $0.created <= day }
            let done = Set(data.log[day] ?? [])
            let hit = habits.filter { done.contains($0.id) }.count
            return WeekDay(
                key: day,
                fraction: habits.isEmpty ? 0 : Double(hit) / Double(habits.count),
                hasHabits: !habits.isEmpty,
                isToday: offset == 0
            )
        }
    }

    // MARK: Actions

    func add(_ title: String, kind: TaskKind) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let task = TaskItem(title: String(title.prefix(120)), created: today)
        mutate { d in
            if kind == .daily { d.daily.append(task) } else { d.once.append(task) }
        }
    }

    func toggle(_ kind: TaskKind, _ task: TaskItem) {
        setDone(kind, id: task.id, done: !isDone(kind, task))
    }

    /// Used by the "Done" action on a reminder notification.
    func markDone(_ kind: TaskKind, id: String) {
        refreshDay()
        setDone(kind, id: id, done: true)
    }

    private func setDone(_ kind: TaskKind, id: String, done: Bool) {
        let day = today
        mutate { d in
            switch kind {
            case .daily:
                var set = Set(d.log[day] ?? [])
                if done { set.insert(id) } else { set.remove(id) }
                d.log[day] = set.isEmpty ? nil : Array(set)
            case .once:
                if let i = d.once.firstIndex(where: { $0.id == id }) {
                    d.once[i].doneOn = done ? day : nil
                }
            }
        }
    }

    func update(_ kind: TaskKind, _ task: TaskItem) {
        mutate { d in
            switch kind {
            case .daily:
                if let i = d.daily.firstIndex(where: { $0.id == task.id }) { d.daily[i] = task }
            case .once:
                if let i = d.once.firstIndex(where: { $0.id == task.id }) { d.once[i] = task }
            }
        }
    }

    func delete(_ kind: TaskKind, at offsets: IndexSet) {
        mutate { d in
            if kind == .daily { d.daily.remove(atOffsets: offsets) } else { d.once.remove(atOffsets: offsets) }
        }
    }

    func delete(_ kind: TaskKind, id: String) {
        guard let i = tasks(kind).firstIndex(where: { $0.id == id }) else { return }
        delete(kind, at: IndexSet(integer: i))
    }

    func move(_ kind: TaskKind, from source: IndexSet, to destination: Int) {
        mutate { d in
            if kind == .daily {
                d.daily.move(fromOffsets: source, toOffset: destination)
            } else {
                d.once.move(fromOffsets: source, toOffset: destination)
            }
        }
    }

    // MARK: Backup

    func exportFile() throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("haru-haru-\(today).json")
        try encoder.encode(data).write(to: url, options: .atomic)
        return url
    }

    func replace(with imported: AppData) {
        data = imported
        prune()
        persist()
    }
}
