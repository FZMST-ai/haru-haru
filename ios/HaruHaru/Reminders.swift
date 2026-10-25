import UserNotifications

/// Local notifications. Everything is rescheduled from scratch whenever data changes,
/// a week ahead, so reminders for habits already done today are skipped.
enum Reminders {
    static let category = "TASK_REMINDER"
    static let doneAction = "MARK_DONE"

    static let checkInEnabledKey = "checkInEnabled"
    static let checkInTimeKey = "checkInTime"
    static let defaultCheckInTime = "20:00"

    /// iOS keeps at most 64 pending requests per app.
    private static let maxPending = 60
    private static let horizonDays = 7

    static func registerCategories() {
        let done = UNNotificationAction(identifier: doneAction, title: "Mark done", options: [])
        let cat = UNNotificationCategory(identifier: category, actions: [done], intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([cat])
    }

    @discardableResult
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func reschedule(data: AppData, today: String) {
        let defaults = UserDefaults.standard
        let checkInOn = defaults.bool(forKey: checkInEnabledKey)
        let checkInTime = defaults.string(forKey: checkInTimeKey) ?? defaultCheckInTime

        let now = Date()
        let doneToday = Set(data.log[today] ?? [])
        var pending: [(date: Date, request: UNNotificationRequest)] = []

        func add(id: String, day: String, time: String, body: String, title: String, info: [String: String]?) {
            guard let t = ClockTime.parts(time),
                  let dayDate = Day.date(day),
                  let fire = Day.calendar.date(bySettingHour: t.hour, minute: t.minute, second: 0, of: dayDate),
                  fire > now else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            if let info {
                content.userInfo = info
                content.categoryIdentifier = category
            }
            let comps = Day.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            pending.append((fire, UNNotificationRequest(identifier: "\(id)@\(day)", content: content, trigger: trigger)))
        }

        for offset in 0..<horizonDays {
            let day = Day.shift(today, by: offset)

            for t in data.daily {
                guard let time = t.remind, !(offset == 0 && doneToday.contains(t.id)) else { continue }
                add(id: t.id, day: day, time: time, body: t.title, title: "Daily habit",
                    info: ["kind": TaskKind.daily.rawValue, "id": t.id])
            }
            // Unfinished one-off tasks carry over, so their reminder repeats until done.
            for t in data.once where t.doneOn == nil {
                guard let time = t.remind else { continue }
                add(id: t.id, day: day, time: time, body: t.title, title: "Reminder",
                    info: ["kind": TaskKind.once.rawValue, "id": t.id])
            }

            if checkInOn {
                let habits = offset == 0 ? data.daily.filter { !doneToday.contains($0.id) } : data.daily
                let left = (habits + data.once.filter { $0.doneOn == nil }).map(\.title)
                if left.isEmpty { continue }
                let preview = left.prefix(3).joined(separator: ", ") + (left.count > 3 ? "…" : "")
                let title = left.count == 1 ? "1 task left today" : "\(left.count) tasks left today"
                add(id: "checkin", day: day, time: checkInTime, body: preview, title: title, info: nil)
            }
        }

        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        for item in pending.sorted(by: { $0.date < $1.date }).prefix(maxPending) {
            center.add(item.request)
        }
    }
}
