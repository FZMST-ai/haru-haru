import Foundation

/// A task. Daily habits ignore `doneOn` (completion lives in `AppData.log`);
/// one-off tasks set `doneOn` to the day they were finished.
/// The JSON shape matches the web app's export, so backups move between the two.
struct TaskItem: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var created: String
    var doneOn: String?
    /// Optional reminder time as "HH:mm".
    var remind: String?

    init(title: String, created: String = Day.key()) {
        self.id = Self.makeID()
        self.title = title
        self.created = created
    }

    static func makeID() -> String {
        String(Int(Date().timeIntervalSince1970 * 1000), radix: 36)
            + String(UInt32.random(in: 0...UInt32.max), radix: 36)
    }
}

enum TaskKind: String, CaseIterable, Identifiable {
    case once, daily
    var id: Self { self }
}

struct AppData: Codable {
    var v = 1
    var daily: [TaskItem] = []
    var once: [TaskItem] = []
    /// Day key → ids of daily habits completed that day.
    var log: [String: [String]] = [:]

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        v = try c.decodeIfPresent(Int.self, forKey: .v) ?? 1
        daily = try c.decodeIfPresent([TaskItem].self, forKey: .daily) ?? []
        once = try c.decodeIfPresent([TaskItem].self, forKey: .once) ?? []
        log = try c.decodeIfPresent([String: [String]].self, forKey: .log) ?? [:]
    }
}

/// Days are handled as local-time "yyyy-MM-dd" keys, same as the web app.
enum Day {
    static var calendar: Calendar { Calendar.current }

    static func key(_ date: Date = Date()) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func date(_ key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    static func shift(_ key: String, by days: Int) -> String {
        guard let d = date(key), let s = calendar.date(byAdding: .day, value: days, to: d) else { return key }
        return Self.key(s)
    }
}

/// Reminder times are stored as "HH:mm".
enum ClockTime {
    static func parts(_ s: String) -> (hour: Int, minute: Int)? {
        let p = s.split(separator: ":").compactMap { Int($0) }
        guard p.count == 2, (0..<24).contains(p[0]), (0..<60).contains(p[1]) else { return nil }
        return (p[0], p[1])
    }

    static func string(from date: Date) -> String {
        let c = Day.calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    /// Today at the given time, for use with a DatePicker.
    static func date(from s: String) -> Date {
        let (h, m) = parts(s) ?? (9, 0)
        return Day.calendar.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date()
    }

    static func display(_ s: String) -> String {
        date(from: s).formatted(date: .omitted, time: .shortened)
    }
}
