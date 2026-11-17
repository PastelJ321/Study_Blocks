import Foundation
import SwiftData

public struct CourseRecord: Codable {
    public var id: UUID
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
    init(_ model: Course) {
        id = model.id
        title = model.title
        subject = model.subject
        teacher = model.teacher
        platform = model.platform
        link = model.link
        total = model.total
        targetDate = model.targetDate
        notes = model.notes
        createdAt = model.createdAt
        archived = model.archived
    }
    func model() -> Course {
        let model = Course(id: id, title: title, subject: subject, total: total)
        model.id = id
        model.title = title
        model.subject = subject
        model.teacher = teacher
        model.platform = platform
        model.link = link
        model.total = total
        model.targetDate = targetDate
        model.notes = notes
        model.createdAt = createdAt
        model.archived = archived
        return model
    }
}

public struct LessonCompletionRecord: Codable {
    public var key: String
    public var courseID: UUID
    public var lesson: Int
    public var completedAt: Date
    public var isInitial: Bool
    init(_ model: LessonCompletion) {
        key = model.key
        courseID = model.courseID
        lesson = model.lesson
        completedAt = model.completedAt
        isInitial = model.isInitial
    }
    func model() -> LessonCompletion {
        let model = LessonCompletion(courseID: courseID, lesson: lesson)
        model.key = key
        model.courseID = courseID
        model.lesson = lesson
        model.completedAt = completedAt
        model.isInitial = isInitial
        return model
    }
}

public struct StudyBlockRecord: Codable {
    public var id: UUID
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
    init(_ model: StudyBlock) {
        id = model.id
        title = model.title
        subject = model.subject
        kindRaw = model.kindRaw
        details = model.details
        day = model.day
        originalDay = model.originalDay
        isCore = model.isCore
        statusRaw = model.statusRaw
        createdAt = model.createdAt
        completedAt = model.completedAt
        courseID = model.courseID
        lesson = model.lesson
        quantity = model.quantity
        unit = model.unit
        order = model.order
        archived = model.archived
        recurrenceID = model.recurrenceID
        occurrenceDay = model.occurrenceDay
    }
    func model() -> StudyBlock {
        let model = StudyBlock(id: id, title: title, subject: subject, day: day)
        model.id = id
        model.title = title
        model.subject = subject
        model.kindRaw = kindRaw
        model.details = details
        model.day = day
        model.originalDay = originalDay
        model.isCore = isCore
        model.statusRaw = statusRaw
        model.createdAt = createdAt
        model.completedAt = completedAt
        model.courseID = courseID
        model.lesson = lesson
        model.quantity = quantity
        model.unit = unit
        model.order = order
        model.archived = archived
        model.recurrenceID = recurrenceID
        model.occurrenceDay = occurrenceDay
        return model
    }
}

public struct WeeklyGoalRecord: Codable {
    public var id: UUID
    public var week: String
    public var subject: String
    public var kindRaw: String
    public var courseID: UUID?
    public var target: Int
    public var unit: String
    init(_ model: WeeklyGoal) {
        id = model.id
        week = model.week
        subject = model.subject
        kindRaw = model.kindRaw
        courseID = model.courseID
        target = model.target
        unit = model.unit
    }
    func model() -> WeeklyGoal {
        let model = WeeklyGoal(id: id, week: week, subject: subject, kind: BlockKind(rawValue: kindRaw)!, target: target, unit: unit)
        model.id = id
        model.week = week
        model.subject = subject
        model.kindRaw = kindRaw
        model.courseID = courseID
        model.target = target
        model.unit = unit
        return model
    }
}

public struct RecurrenceRuleRecord: Codable {
    public var id: UUID
    public var title: String
    public var subject: String
    public var details: String
    public var isCore: Bool
    public var startDay: String
    public var weekdays: [Int]
    public var interval: Int
    public var enabled: Bool
    init(_ model: RecurrenceRule) {
        id = model.id
        title = model.title
        subject = model.subject
        details = model.details
        isCore = model.isCore
        startDay = model.startDay
        weekdays = model.weekdays
        interval = model.interval
        enabled = model.enabled
    }
    func model() -> RecurrenceRule {
        let model = RecurrenceRule(id: id, title: title, subject: subject, startDay: startDay)
        model.id = id
        model.title = title
        model.subject = subject
        model.details = details
        model.isCore = isCore
        model.startDay = startDay
        model.weekdays = weekdays
        model.interval = interval
        model.enabled = enabled
        return model
    }
}

public struct StudyEventRecord: Codable {
    public var id: UUID
    public var timestamp: Date
    public var action: String
    public var title: String
    public var blockID: UUID?
    public var courseID: UUID?
    public var lesson: Int?
    public var fromDay: String?
    public var toDay: String?
    init(_ model: StudyEvent) {
        id = model.id
        timestamp = model.timestamp
        action = model.action
        title = model.title
        blockID = model.blockID
        courseID = model.courseID
        lesson = model.lesson
        fromDay = model.fromDay
        toDay = model.toDay
    }
    func model() -> StudyEvent {
        let model = StudyEvent(action: action, title: title)
        model.id = id
        model.timestamp = timestamp
        model.action = action
        model.title = title
        model.blockID = blockID
        model.courseID = courseID
        model.lesson = lesson
        model.fromDay = fromDay
        model.toDay = toDay
        return model
    }
}

public struct StudyBackup: Codable {
    public var formatVersion: Int
    public var exportedAt: Date
    public var courses: [CourseRecord]
    public var completions: [LessonCompletionRecord]
    public var blocks: [StudyBlockRecord]
    public var goals: [WeeklyGoalRecord]
    public var rules: [RecurrenceRuleRecord]
    public var events: [StudyEventRecord]
}

extension StudyStore {
    public func exportJSON() throws -> Data {
        let backup = StudyBackup(formatVersion: 1, exportedAt: Date(), courses: courses.map(CourseRecord.init), completions: completions.map(LessonCompletionRecord.init), blocks: blocks.map(StudyBlockRecord.init), goals: goals.map(WeeklyGoalRecord.init), rules: rules.map(RecurrenceRuleRecord.init), events: events.map(StudyEventRecord.init))
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }
    public static func inspectBackup(_ data: Data) throws -> StudyBackup {
        guard data.count <= 20_000_000 else { throw StudyError.invalid("백업 파일은 20MB 이하만 가져올 수 있습니다.") }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let b = try decoder.decode(StudyBackup.self, from: data)
        guard b.formatVersion == 1 else { throw StudyError.invalid("지원하지 않는 백업 버전입니다.") }
        func require(_ ok: Bool) throws { if !ok { throw StudyError.invalid("백업 데이터가 손상되었거나 서로 일치하지 않습니다.") } }
        func unique<T: Hashable>(_ values: [T]) -> Bool { Set(values).count == values.count }
        try require(b.courses.count + b.blocks.count + b.completions.count + b.goals.count + b.rules.count + b.events.count <= 100000)
        try require(unique(b.courses.map(\.id)) && unique(b.blocks.map(\.id)) && unique(b.completions.map(\.key)) && unique(b.goals.map(\.id)) && unique(b.rules.map(\.id)) && unique(b.events.map(\.id)))
        let courses = Dictionary(uniqueKeysWithValues: b.courses.map { ($0.id, $0) })
        let rules = Set(b.rules.map(\.id))
        for c in b.courses { try require(!c.title.isEmpty && !c.subject.isEmpty && (1...10000).contains(c.total)) }
        for c in b.completions { try require(c.key == LessonCompletion.key(c.courseID, c.lesson) && courses[c.courseID] != nil && (1...10000).contains(c.lesson)) }
        var occurrences = Set<String>()
        for block in b.blocks {
            try require(StudyDate.valid(block.day) && StudyDate.valid(block.originalDay) && !block.title.isEmpty && !block.subject.isEmpty && (1...100000).contains(block.quantity) && !block.unit.isEmpty && BlockKind(rawValue: block.kindRaw) != nil && BlockStatus(rawValue: block.statusRaw) != nil)
            try require(block.courseID == nil || courses[block.courseID!] != nil)
            if block.kindRaw == "lecture" {
                try require(block.courseID != nil && block.lesson != nil)
                try require(courses[block.courseID!] != nil && (1...10000).contains(block.lesson!))
            } else { try require((block.statusRaw == "done") == (block.completedAt != nil)) }
            if let r = block.recurrenceID {
                try require(rules.contains(r) && block.occurrenceDay.map(StudyDate.valid) == true)
                try require(occurrences.insert("\(r):\(block.occurrenceDay!)").inserted)
            }
        }
        for g in b.goals { try require(StudyDate.valid(g.week) && StudyDate.week(g.week) == g.week && !g.subject.isEmpty && (1...100000).contains(g.target) && !g.unit.isEmpty && BlockKind(rawValue: g.kindRaw) != nil && (g.courseID == nil || courses[g.courseID!] != nil)) }
        for r in b.rules { try require(StudyDate.valid(r.startDay) && !r.title.isEmpty && !r.subject.isEmpty && (0...365).contains(r.interval) && (r.interval > 0 || !r.weekdays.isEmpty) && r.weekdays.allSatisfy { (1...7).contains($0) }) }
        for e in b.events { try require(e.fromDay.map(StudyDate.valid) ?? true); try require(e.toDay.map(StudyDate.valid) ?? true) }
        return b
    }
    public func restoreJSON(_ data: Data) throws {
        let b = try Self.inspectBackup(data)
        try transaction {
            let coursesByID = Dictionary(uniqueKeysWithValues: courses.map { ($0.id, $0) })
            let incomingcourses = Set(b.courses.map(\.id))
            for old in courses where !incomingcourses.contains(old.id) { context.delete(old) }
            for record in b.courses {
                if let model = coursesByID[record.id] {
                    model.id = record.id
                    model.title = record.title
                    model.subject = record.subject
                    model.teacher = record.teacher
                    model.platform = record.platform
                    model.link = record.link
                    model.total = record.total
                    model.targetDate = record.targetDate
                    model.notes = record.notes
                    model.createdAt = record.createdAt
                    model.archived = record.archived
                } else { context.insert(record.model()) }
            }
            let completionsByID = Dictionary(uniqueKeysWithValues: completions.map { ($0.key, $0) })
            let incomingcompletions = Set(b.completions.map(\.key))
            for old in completions where !incomingcompletions.contains(old.key) { context.delete(old) }
            for record in b.completions {
                if let model = completionsByID[record.key] {
                    model.key = record.key
                    model.courseID = record.courseID
                    model.lesson = record.lesson
                    model.completedAt = record.completedAt
                    model.isInitial = record.isInitial
                } else { context.insert(record.model()) }
            }
            let blocksByID = Dictionary(uniqueKeysWithValues: blocks.map { ($0.id, $0) })
            let incomingblocks = Set(b.blocks.map(\.id))
            for old in blocks where !incomingblocks.contains(old.id) { context.delete(old) }
            for record in b.blocks {
                if let model = blocksByID[record.id] {
                    model.id = record.id
                    model.title = record.title
                    model.subject = record.subject
                    model.kindRaw = record.kindRaw
                    model.details = record.details
                    model.day = record.day
                    model.originalDay = record.originalDay
                    model.isCore = record.isCore
                    model.statusRaw = record.statusRaw
                    model.createdAt = record.createdAt
                    model.completedAt = record.completedAt
                    model.courseID = record.courseID
                    model.lesson = record.lesson
                    model.quantity = record.quantity
                    model.unit = record.unit
                    model.order = record.order
                    model.archived = record.archived
                    model.recurrenceID = record.recurrenceID
                    model.occurrenceDay = record.occurrenceDay
                } else { context.insert(record.model()) }
            }
            let goalsByID = Dictionary(uniqueKeysWithValues: goals.map { ($0.id, $0) })
            let incominggoals = Set(b.goals.map(\.id))
            for old in goals where !incominggoals.contains(old.id) { context.delete(old) }
            for record in b.goals {
                if let model = goalsByID[record.id] {
                    model.id = record.id
                    model.week = record.week
                    model.subject = record.subject
                    model.kindRaw = record.kindRaw
                    model.courseID = record.courseID
                    model.target = record.target
                    model.unit = record.unit
                } else { context.insert(record.model()) }
            }
            let rulesByID = Dictionary(uniqueKeysWithValues: rules.map { ($0.id, $0) })
            let incomingrules = Set(b.rules.map(\.id))
            for old in rules where !incomingrules.contains(old.id) { context.delete(old) }
            for record in b.rules {
                if let model = rulesByID[record.id] {
                    model.id = record.id
                    model.title = record.title
                    model.subject = record.subject
                    model.details = record.details
                    model.isCore = record.isCore
                    model.startDay = record.startDay
                    model.weekdays = record.weekdays
                    model.interval = record.interval
                    model.enabled = record.enabled
                } else { context.insert(record.model()) }
            }
            let eventsByID = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0) })
            let incomingevents = Set(b.events.map(\.id))
            for old in events where !incomingevents.contains(old.id) { context.delete(old) }
            for record in b.events {
                if let model = eventsByID[record.id] {
                    model.id = record.id
                    model.timestamp = record.timestamp
                    model.action = record.action
                    model.title = record.title
                    model.blockID = record.blockID
                    model.courseID = record.courseID
                    model.lesson = record.lesson
                    model.fromDay = record.fromDay
                    model.toDay = record.toDay
                } else { context.insert(record.model()) }
            }
        }
    }
}
