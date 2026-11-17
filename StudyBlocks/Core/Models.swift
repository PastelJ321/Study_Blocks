import Foundation
import SwiftData

public enum BlockKind: String, Codable, CaseIterable, Identifiable {
    case lecture, problems, review, study
    public var id: String { rawValue }
    public var label: String { switch self { case .lecture: "인강"; case .problems: "문제 풀이"; case .review: "복습"; case .study: "일반 학습" } }
    public var symbol: String { switch self { case .lecture: "play.rectangle"; case .problems: "pencil.line"; case .review: "arrow.triangle.2.circlepath"; case .study: "book" } }
}
public enum BlockStatus: String, Codable, CaseIterable { case pending, active, done }

@Model public final class Course {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var subject: String
    public var teacher: String
    public var platform: String
    public var link: String
    public var total: Int
    public var targetDate: Date?
    public var notes: String
    public var createdAt: Date
    public var archived: Bool
    public init(id: UUID = UUID(), title: String, subject: String, teacher: String = "", platform: String = "", link: String = "", total: Int, targetDate: Date? = nil, notes: String = "") {
        self.id = id; self.title = title; self.subject = subject; self.teacher = teacher; self.platform = platform
        self.link = link; self.total = total; self.targetDate = targetDate; self.notes = notes; createdAt = Date(); archived = false
    }
}

@Model public final class LessonCompletion {
    @Attribute(.unique) public var key: String
    public var courseID: UUID
    public var lesson: Int
    public var completedAt: Date
    public var isInitial: Bool
    public init(courseID: UUID, lesson: Int, completedAt: Date = Date(), isInitial: Bool = false) {
        key = Self.key(courseID, lesson); self.courseID = courseID; self.lesson = lesson; self.completedAt = completedAt; self.isInitial = isInitial
    }
    public static func key(_ courseID: UUID, _ lesson: Int) -> String { "\(courseID.uuidString):\(lesson)" }
}

@Model public final class StudyBlock {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var subject: String
    public var kindRaw: String
    public var details: String
    public var day: String
    public var originalDay: String
    public var isCore: Bool
    public var statusRaw: String
    public var createdAt: Date
    public var completedAt: Date?
    public var courseID: UUID?
    public var lesson: Int?
    public var quantity: Int
    public var unit: String
    public var order: Int
    public var archived: Bool
    public var recurrenceID: UUID?
    public var occurrenceDay: String?
    public init(id: UUID = UUID(), title: String, subject: String, kind: BlockKind = .study, details: String = "", day: String, isCore: Bool = true, courseID: UUID? = nil, lesson: Int? = nil, quantity: Int = 1, unit: String = "회", order: Int = 0) {
        self.id = id; self.title = title; self.subject = subject; kindRaw = kind.rawValue; self.details = details
        self.day = day; originalDay = day; self.isCore = isCore; statusRaw = BlockStatus.pending.rawValue; createdAt = Date()
        self.courseID = courseID; self.lesson = lesson; self.quantity = quantity; self.unit = unit; self.order = order; archived = false
    }
    public var kind: BlockKind { BlockKind(rawValue: kindRaw) ?? .study }
}

@Model public final class WeeklyGoal {
    @Attribute(.unique) public var id: UUID
    public var week: String
    public var subject: String
    public var kindRaw: String
    public var courseID: UUID?
    public var target: Int
    public var unit: String
    public init(id: UUID = UUID(), week: String, subject: String, kind: BlockKind, courseID: UUID? = nil, target: Int, unit: String) {
        self.id = id; self.week = week; self.subject = subject; kindRaw = kind.rawValue; self.courseID = courseID; self.target = target; self.unit = unit
    }
    public var kind: BlockKind { BlockKind(rawValue: kindRaw) ?? .study }
}

@Model public final class RecurrenceRule {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var subject: String
    public var details: String
    public var isCore: Bool
    public var startDay: String
    public var weekdays: [Int]
    public var interval: Int
    public var enabled: Bool
    public init(id: UUID = UUID(), title: String, subject: String, details: String = "", isCore: Bool = false, startDay: String, weekdays: [Int] = [], interval: Int = 0) {
        self.id = id; self.title = title; self.subject = subject; self.details = details; self.isCore = isCore
        self.startDay = startDay; self.weekdays = weekdays; self.interval = interval; enabled = true
    }
}

@Model public final class StudyEvent {
    @Attribute(.unique) public var id: UUID
    public var timestamp: Date
    public var action: String
    public var title: String
    public var blockID: UUID?
    public var courseID: UUID?
    public var lesson: Int?
    public var fromDay: String?
    public var toDay: String?
    public init(action: String, title: String, blockID: UUID? = nil, courseID: UUID? = nil, lesson: Int? = nil, fromDay: String? = nil, toDay: String? = nil) {
        id = UUID(); timestamp = Date(); self.action = action; self.title = title; self.blockID = blockID; self.courseID = courseID; self.lesson = lesson; self.fromDay = fromDay; self.toDay = toDay
    }
}

public enum StudySchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    public static var models: [any PersistentModel.Type] { [Course.self, LessonCompletion.self, StudyBlock.self, WeeklyGoal.self, RecurrenceRule.self, StudyEvent.self] }
}
public enum StudyMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [StudySchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

public enum StudyDate {
    public static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Seoul")!; c.firstWeekday = 2; c.minimumDaysInFirstWeek = 4; return c
    }
    public static func key(_ date: Date = Date()) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    public static func date(_ key: String) -> Date {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return calendar.startOfDay(for: Date()) }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) ?? Date()
    }
    public static func valid(_ key: String) -> Bool { key.count == 10 && Self.key(date(key)) == key }
    public static func adding(_ day: String, days: Int) -> String { key(calendar.date(byAdding: .day, value: days, to: date(day))!) }
    public static func week(_ day: String) -> String {
        key(calendar.dateInterval(of: .weekOfYear, for: date(day))!.start)
    }
    public static func label(_ day: String, format: String = "M월 d일 EEEE") -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.timeZone = calendar.timeZone; f.dateFormat = format; return f.string(from: date(day))
    }
}

public enum StudyError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { switch self { case .invalid(let message): message } }
}
