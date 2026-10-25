import SwiftUI

extension Color {
    static let gold = Color(red: 0.88, green: 0.66, blue: 0.18)
}

struct HeaderView: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        let date = Day.date(store.today) ?? Date()
        let progress = store.progress
        VStack(spacing: 20) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(date.formatted(.dateTime.weekday(.wide)).uppercased())
                        .font(.footnote.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(Color.accentColor)
                    Text(date.formatted(.dateTime.month(.wide).day()))
                        .font(.largeTitle.bold())
                }
                Spacer()
                ProgressRing(done: progress.done, total: progress.total)
            }
            WeekStrip(days: store.week)
        }
        .padding(.vertical, 8)
    }
}

struct ProgressRing: View {
    let done: Int
    let total: Int

    var body: some View {
        let fraction = total == 0 ? 0 : Double(done) / Double(total)
        let complete = total > 0 && done == total
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 6)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(complete ? Color.gold : Color.accentColor,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(done)/\(total)")
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
        }
        .frame(width: 64, height: 64)
        .animation(.easeOut(duration: 0.4), value: fraction)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(done) of \(total) done today")
    }
}

struct WeekStrip: View {
    let days: [Store.WeekDay]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days) { day in
                let date = Day.date(day.key) ?? Date()
                let full = day.hasHabits && day.fraction >= 1
                VStack(spacing: 6) {
                    ZStack {
                        if full {
                            Circle().fill(Color.gold)
                        } else {
                            Circle().stroke(Color.secondary.opacity(0.25), lineWidth: 2)
                            Circle()
                                .trim(from: 0, to: day.fraction)
                                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .padding(3)
                        }
                    }
                    .frame(width: 28, height: 28)
                    Text(date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption.weight(day.isToday ? .bold : .regular))
                        .foregroundStyle(day.isToday ? Color.primary : Color.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Habit completion for the last 7 days")
    }
}

struct TaskRow: View {
    @EnvironmentObject private var store: Store
    let kind: TaskKind
    let task: TaskItem
    let onTap: () -> Void

    var body: some View {
        let done = store.isDone(kind, task)
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(done ? Color.accentColor : Color.secondary, lineWidth: 2)
                        .background(Circle().fill(done ? Color.accentColor : .clear))
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 24, height: 24)

                Text(task.title)
                    .strikethrough(done)
                    .foregroundStyle(done ? Color.secondary : Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                meta
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(done ? .isSelected : [])
    }

    @ViewBuilder
    private var meta: some View {
        HStack(spacing: 8) {
            if let remind = task.remind {
                Label(ClockTime.display(remind), systemImage: "bell")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if kind == .daily {
                let streak = store.streak(task)
                if streak > 1 {
                    Label("\(streak)", systemImage: "flame.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.gold)
                }
            } else if task.doneOn == nil, task.created < store.today, let since = Day.date(task.created) {
                Text("since \(since.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .monospacedDigit()
    }
}
