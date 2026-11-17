import Foundation
import SwiftData
import Observation

public struct CourseDraft {
    public var title = "", subject = "수학", teacher = "", platform = "", link = "", notes = ""
    public var total = 30, completed = 0
    public var targetDate: Date?
    public init() {}
}
public struct BlockDraft {
    public var title = "", subject = "수학", details = ""
    public var kind = BlockKind.study
    public var day = StudyDate.key()
    public var isCore = true
    public var courseID: UUID?
    public var lesson: Int?
    public var quantity = 1, unit = "회"
    public init() {}
}
public struct PlanSuggestion: Identifiable {
    public let id: String
    public let courseID: UUID
    public let title: String
    public let lesson: Int
    public let day: String
}

@MainActor @Observable public final class StudyStore {
    public let container: ModelContainer
    public let context: ModelContext
    public private(set) var courses: [Course] = []
    public private(set) var completions: [LessonCompletion] = []
    public private(set) var blocks: [StudyBlock] = []
    public private(set) var goals: [WeeklyGoal] = []
    public private(set) var rules: [RecurrenceRule] = []
    public private(set) var events: [StudyEvent] = []
    public var saveOverride: (() throws -> Void)?
    public static let bundleID = "com.pastelj.studyblocks"

    public static func makeContainer(url: URL? = nil, inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: StudySchemaV1.self)
        let config: ModelConfiguration
        if inMemory { config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none) }
        else {
            let location: URL
            if let url { location = url }
            else {
                let folder = URL.applicationSupportDirectory.appendingPathComponent(bundleID, isDirectory: true)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                location = folder.appendingPathComponent("Study.store")
            }
            config = ModelConfiguration(schema: schema, url: location, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, migrationPlan: StudyMigrationPlan.self, configurations: [config])
    }
    public init(container: ModelContainer) throws {
        self.container = container; context = ModelContext(container); context.autosaveEnabled = false; try reload()
    }
    public func reload() throws {
        courses = try context.fetch(FetchDescriptor<Course>()).sorted { $0.createdAt < $1.createdAt }
        completions = try context.fetch(FetchDescriptor<LessonCompletion>())
        blocks = try context.fetch(FetchDescriptor<StudyBlock>()).sorted { $0.order < $1.order }
        goals = try context.fetch(FetchDescriptor<WeeklyGoal>())
        rules = try context.fetch(FetchDescriptor<RecurrenceRule>())
        events = try context.fetch(FetchDescriptor<StudyEvent>()).sorted { $0.timestamp > $1.timestamp }
    }
    public func transaction(_ change: () throws -> Void) throws {
        do {
            try change()
            if let saveOverride { try saveOverride() } else { try context.save() }
            try reload()
        } catch {
            context.rollback(); try? reload(); throw error
        }
    }
    public func course(_ id: UUID?) -> Course? { courses.first { $0.id == id } }
    public func completedLessons(_ course: Course) -> Set<Int> { Set(completions.filter { $0.courseID == course.id && $0.lesson <= course.total }.map(\.lesson)) }
    public func nextLesson(_ course: Course) -> Int? { (1...max(1, course.total)).first { !completedLessons(course).contains($0) } }
    public func nextUnplanned(_ course: Course) -> Int? {
        let used = Set(blocks.filter { !$0.archived && $0.kind == .lecture && $0.courseID == course.id }.compactMap(\.lesson)).union(completedLessons(course))
        return (1...max(1, course.total)).first { !used.contains($0) }
    }
    public func plannedBlock(for course: Course, lesson: Int) -> StudyBlock? {
        blocks.first { !$0.archived && $0.kind == .lecture && $0.courseID == course.id && $0.lesson == lesson && status($0) != .done }
    }
    public func courseURL(for block: StudyBlock) -> URL? {
        guard block.kind == .lecture else { return nil }
        return course(block.courseID)?.validURL
    }
    public func completion(_ block: StudyBlock) -> LessonCompletion? {
        guard block.kind == .lecture, let courseID = block.courseID, let lesson = block.lesson else { return nil }
        return completions.first { $0.key == LessonCompletion.key(courseID, lesson) }
    }
    public func status(_ block: StudyBlock) -> BlockStatus {
        if block.kind == .lecture { return completion(block) == nil ? (block.statusRaw == "active" ? .active : .pending) : .done }
        return BlockStatus(rawValue: block.statusRaw) ?? .pending
    }
    public func completionDate(_ block: StudyBlock) -> Date? { block.kind == .lecture ? completion(block)?.completedAt : block.completedAt }
    public func dayBlocks(_ day: String) -> [StudyBlock] {
        blocks.filter { !$0.archived && $0.day == day }.sorted { $0.order == $1.order ? $0.createdAt < $1.createdAt : $0.order < $1.order }
    }
    @discardableResult public func addCourse(_ draft: CourseDraft) throws -> Course {
        try validate(draft)
        let course = Course(title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines), subject: draft.subject, teacher: draft.teacher, platform: draft.platform, link: draft.link, total: draft.total, targetDate: draft.targetDate, notes: draft.notes)
        try transaction {
            context.insert(course)
            if draft.completed > 0 { for lesson in 1...draft.completed { context.insert(LessonCompletion(courseID: course.id, lesson: lesson, isInitial: true)) } }
        }
        return course
    }
    private func validate(_ draft: CourseDraft) throws {
        guard !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !draft.subject.isEmpty else { throw StudyError.invalid("강좌명과 과목을 입력해 주세요.") }
        guard (1...10000).contains(draft.total), (0...draft.total).contains(draft.completed) else { throw StudyError.invalid("전체 강의 수와 현재 진도를 확인해 주세요. (최대 10,000강)") }
        if !draft.link.isEmpty {
            guard let url = URL(string: draft.link), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { throw StudyError.invalid("바로가기는 http 또는 https 주소를 입력해 주세요.") }
        }
    }
    public func updateCourse(_ course: Course, draft: CourseDraft, confirmTrim: Bool = false) throws {
        try validate(draft)
        let outside = completions.filter { $0.courseID == course.id && $0.lesson > draft.total }
        let outsideBlocks = blocks.filter { $0.courseID == course.id && ($0.lesson ?? 0) > draft.total }
        if draft.total < course.total && (!outside.isEmpty || !outsideBlocks.isEmpty) && !confirmTrim {
            throw StudyError.invalid("줄어든 범위를 벗어나는 강의 이력 또는 계획이 있습니다. 확인 후 변경해 주세요.")
        }
        try transaction {
            // Preserve completion history even when a course is shortened.
            // Pending blocks outside the new range are archived rather than rewritten.
            for block in outsideBlocks where completion(block) == nil {
                block.archived = true
                context.insert(StudyEvent(action: "범위 밖 계획 보관", title: block.title, blockID: block.id, courseID: course.id, lesson: block.lesson))
            }
            for block in blocks where block.courseID == course.id && block.kind == .lecture {
                if let lesson = block.lesson, block.title == "\(course.title) · \(lesson)강" { block.title = "\(draft.title) · \(lesson)강" }
                block.subject = draft.subject
            }
            course.title = draft.title; course.subject = draft.subject; course.teacher = draft.teacher; course.platform = draft.platform
            course.link = draft.link; course.total = draft.total; course.targetDate = draft.targetDate; course.notes = draft.notes
            if !outside.isEmpty { context.insert(StudyEvent(action: "강의 수 수정", title: course.title, courseID: course.id)) }
        }
    }
    public func archiveCourse(_ course: Course) throws { try transaction { course.archived.toggle() } }
    @discardableResult public func addBlock(_ draft: BlockDraft) throws -> StudyBlock {
        try validate(draft)
        if draft.kind == .lecture, let cid = draft.courseID, let lesson = draft.lesson,
           blocks.contains(where: { !$0.archived && $0.kind == .lecture && $0.courseID == cid && $0.lesson == lesson }) {
            throw StudyError.invalid("이미 계획에 있는 강의입니다. 기존 블록의 날짜를 변경해 주세요.")
        }
        let block = makeBlock(draft)
        try transaction { context.insert(block) }; return block
    }
    private func validate(_ draft: BlockDraft) throws {
        guard StudyDate.valid(draft.day), !draft.subject.isEmpty, (1...100000).contains(draft.quantity), !draft.unit.isEmpty else { throw StudyError.invalid("날짜와 학습량을 확인해 주세요.") }
        if draft.kind == .lecture {
            guard let course = course(draft.courseID), let lesson = draft.lesson, (1...course.total).contains(lesson) else { throw StudyError.invalid("강좌와 강의 번호를 선택해 주세요.") }
            guard !completedLessons(course).contains(lesson) else { throw StudyError.invalid("이미 완료한 강의입니다. 다시 공부하려면 복습 블록으로 추가해 주세요.") }
        } else if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw StudyError.invalid("학습 제목을 입력해 주세요.") }
    }
    private func makeBlock(_ draft: BlockDraft) -> StudyBlock {
        let c = course(draft.courseID)
        return StudyBlock(title: draft.kind == .lecture ? "\(c?.title ?? "강의") · \(draft.lesson ?? 1)강" : draft.title, subject: draft.kind == .lecture ? c?.subject ?? draft.subject : draft.subject, kind: draft.kind, details: draft.details, day: draft.day, isCore: draft.isCore, courseID: draft.courseID, lesson: draft.lesson, quantity: draft.kind == .lecture ? 1 : draft.quantity, unit: draft.kind == .lecture ? "강" : draft.unit, order: (dayBlocks(draft.day).map(\.order).max() ?? -1) + 1)
    }
    public func updateBlock(_ block: StudyBlock, draft: BlockDraft) throws {
        guard StudyDate.valid(draft.day), !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, (1...100000).contains(draft.quantity), !draft.unit.isEmpty else { throw StudyError.invalid("제목과 날짜, 학습량을 확인해 주세요.") }
        try transaction {
            if block.day != draft.day { context.insert(StudyEvent(action: "날짜 변경", title: block.title, blockID: block.id, fromDay: block.day, toDay: draft.day)) }
            block.title = draft.title; block.subject = block.kind == .lecture ? (course(block.courseID)?.subject ?? draft.subject) : draft.subject; block.details = draft.details; block.day = draft.day; block.isCore = draft.isCore
            if block.kind != .lecture { block.quantity = draft.quantity; block.unit = draft.unit }
        }
    }
    private func changeLesson(_ course: Course, lesson: Int, done: Bool, block: StudyBlock? = nil) throws {
        let existing = completions.first { $0.key == LessonCompletion.key(course.id, lesson) }
        guard (1...course.total).contains(lesson) || (!done && existing != nil) else { throw StudyError.invalid("강의 번호가 범위를 벗어났습니다.") }
        if (existing != nil) == done { return }
        if done { context.insert(LessonCompletion(courseID: course.id, lesson: lesson)) }
        else {
            if let existing { context.delete(existing) }
            for b in blocks where b.courseID == course.id && b.lesson == lesson && b.kind == .lecture { b.statusRaw = "pending" }
        }
        context.insert(StudyEvent(action: done ? "수강 완료" : "완료 취소", title: "\(course.title) · \(lesson)강", blockID: block?.id, courseID: course.id, lesson: lesson))
    }
    public func setLesson(_ course: Course, lesson: Int, done: Bool, block: StudyBlock? = nil) throws {
        try transaction { try changeLesson(course, lesson: lesson, done: done, block: block) }
    }
    public func setStatus(_ block: StudyBlock, _ status: BlockStatus) throws {
        try transaction {
            if block.kind == .lecture, let course = course(block.courseID), let lesson = block.lesson {
                try changeLesson(course, lesson: lesson, done: status == .done, block: block)
                block.statusRaw = status == .active ? "active" : "pending"
            } else {
                if self.status(block) != status {
                    context.insert(StudyEvent(action: status == .done ? "학습 완료" : (self.status(block) == .done ? "완료 취소" : "상태 변경"), title: block.title, blockID: block.id))
                }
                block.statusRaw = status.rawValue; block.completedAt = status == .done ? (block.completedAt ?? Date()) : nil
            }
        }
    }
    public func move(_ block: StudyBlock, to day: String) throws {
        guard StudyDate.valid(day), status(block) != .done else { throw StudyError.invalid("완료하지 않은 학습만 옮길 수 있습니다.") }
        try transaction {
            context.insert(StudyEvent(action: "이월", title: block.title, blockID: block.id, fromDay: block.day, toDay: day))
            block.day = day; block.order = (dayBlocks(day).map(\.order).max() ?? -1) + 1
        }
    }
    public func archive(_ block: StudyBlock) throws { try transaction { block.archived.toggle() } }
    public func reorder(_ source: UUID, before target: UUID, day: String) throws {
        var list = dayBlocks(day)
        guard let s = list.firstIndex(where: { $0.id == source }), source != target else { return }
        let block = list.remove(at: s)
        guard let t = list.firstIndex(where: { $0.id == target }) else { return }
        list.insert(block, at: t)
        try transaction { for (index, block) in list.enumerated() { block.order = index } }
    }
    @discardableResult public func rollover(to day: String, limit: Int = 12) throws -> Int {
        let overdue = blocks.filter { !$0.archived && $0.day < day && status($0) != .done }.sorted { $0.day < $1.day }
        let candidates = Array(overdue.prefix(max(0, limit - dayBlocks(day).filter { status($0) != .done }.count)))
        guard !candidates.isEmpty else { return 0 }
        try transaction {
            for (index, block) in candidates.enumerated() {
                context.insert(StudyEvent(action: "자동 이월", title: block.title, blockID: block.id, fromDay: block.day, toDay: day))
                block.day = day; block.order = dayBlocks(day).count + index
            }
        }
        return candidates.count
    }
    public func saveGoal(_ goal: WeeklyGoal?, week: String, subject: String, kind: BlockKind, courseID: UUID?, target: Int, unit: String) throws {
        guard (1...100000).contains(target), !subject.isEmpty, !unit.isEmpty else { throw StudyError.invalid("목표 학습량을 확인해 주세요.") }
        try transaction {
            if let goal { goal.subject = subject; goal.kindRaw = kind.rawValue; goal.courseID = courseID; goal.target = target; goal.unit = unit }
            else { context.insert(WeeklyGoal(week: StudyDate.week(week), subject: subject, kind: kind, courseID: courseID, target: target, unit: unit)) }
        }
    }
    public func deleteGoal(_ goal: WeeklyGoal) throws { try transaction { context.delete(goal) } }
    public func achieved(_ goal: WeeklyGoal) -> Int {
        if goal.kind == .lecture {
            return completions.filter { c in !c.isInitial && StudyDate.week(StudyDate.key(c.completedAt)) == goal.week && (goal.courseID == nil ? course(c.courseID)?.subject == goal.subject : c.courseID == goal.courseID) }.count
        }
        return blocks.filter { b in b.kind == goal.kind && b.subject == goal.subject && b.unit == goal.unit && status(b) == .done && completionDate(b).map { StudyDate.week(StudyDate.key($0)) == goal.week } == true }.reduce(0) { $0 + $1.quantity }
    }
    public func plannedPending(_ goal: WeeklyGoal) -> Int {
        if goal.kind == .lecture {
            return blocks.filter { b in
                !b.archived && b.kind == .lecture && status(b) != .done && StudyDate.week(b.day) == goal.week && (goal.courseID == nil ? b.subject == goal.subject : b.courseID == goal.courseID)
            }.count
        }
        return blocks.filter { b in
            !b.archived && b.kind == goal.kind && b.subject == goal.subject && b.unit == goal.unit && status(b) != .done && StudyDate.week(b.day) == goal.week
        }.reduce(0) { $0 + $1.quantity }
    }
    public func saveRule(_ rule: RecurrenceRule?, title: String, subject: String, startDay: String, weekdays: [Int], interval: Int, enabled: Bool) throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, StudyDate.valid(startDay), (!weekdays.isEmpty || interval > 0), interval <= 365 else { throw StudyError.invalid("반복할 학습과 요일 또는 간격을 선택해 주세요.") }
        try transaction {
            let r = rule ?? RecurrenceRule(title: title, subject: subject, startDay: startDay)
            r.title = title; r.subject = subject; r.startDay = startDay; r.weekdays = weekdays; r.interval = interval; r.enabled = enabled
            if rule == nil { context.insert(r) }
            // Previously generated occurrences remain intact; edits apply to new dates.
        }
    }
    public func materialize(day: String) throws {
        let matching = rules.filter { rule in
            guard rule.enabled, day >= rule.startDay else { return false }
            if rule.interval > 0 { return (StudyDate.calendar.dateComponents([.day], from: StudyDate.date(rule.startDay), to: StudyDate.date(day)).day ?? 0) % rule.interval == 0 }
            return rule.weekdays.contains(StudyDate.calendar.component(.weekday, from: StudyDate.date(day)))
        }.filter { r in !blocks.contains { $0.recurrenceID == r.id && $0.occurrenceDay == day } }
        guard !matching.isEmpty else { return }
        try transaction {
            for (i, r) in matching.enumerated() {
                let b = StudyBlock(title: r.title, subject: r.subject, kind: .review, details: r.details, day: day, isCore: r.isCore, order: dayBlocks(day).count + i)
                b.recurrenceID = r.id; b.occurrenceDay = day; context.insert(b)
            }
        }
    }
    public func suggestions(week: String, today: String = StudyDate.key()) -> [PlanSuggestion] {
        let start = max(StudyDate.week(week), today), end = StudyDate.adding(StudyDate.week(week), days: 6)
        guard start <= end else { return [] }
        var result: [PlanSuggestion] = []
        var remainingByGoal: [UUID: Int] = [:]
        for goal in goals where goal.week == StudyDate.week(week) && goal.kind == .lecture {
            let planned = blocks.filter { b in
                !b.archived && b.kind == .lecture && status(b) != .done && StudyDate.week(b.day) == goal.week && (goal.courseID == nil ? b.subject == goal.subject : b.courseID == goal.courseID)
            }.count
            remainingByGoal[goal.id] = max(0, goal.target - achieved(goal) - planned)
        }
        for c in courses where !c.archived {
            let occupied = Set(blocks.filter { !$0.archived && $0.courseID == c.id && $0.kind == .lecture }.compactMap(\.lesson)).union(completedLessons(c))
            let available = (1...c.total).filter { !occupied.contains($0) }
            let matchingGoals = goals.filter { $0.week == StudyDate.week(week) && $0.kind == .lecture && ($0.courseID == c.id || ($0.courseID == nil && $0.subject == c.subject)) }
            var count = matchingGoals.map { remainingByGoal[$0.id] ?? 0 }.min() ?? 0
            let days = (StudyDate.calendar.dateComponents([.day], from: StudyDate.date(start), to: StudyDate.date(end)).day ?? 0) + 1
            if let target = c.targetDate, matchingGoals.isEmpty {
                let until = max(1, (StudyDate.calendar.dateComponents([.day], from: StudyDate.date(today), to: target).day ?? 0) + 1)
                count = Int(ceil(Double(available.count) / Double(until) * Double(days)))
            }
            count = min(count, available.count, days * 4)
            for i in 0..<max(0, count) {
                let day = StudyDate.adding(start, days: min(days - 1, i * days / max(1, count)))
                let lesson = available[i]
                result.append(PlanSuggestion(id: LessonCompletion.key(c.id, lesson), courseID: c.id, title: c.title, lesson: lesson, day: day))
            }
            for goal in matchingGoals { remainingByGoal[goal.id] = max(0, (remainingByGoal[goal.id] ?? 0) - count) }
        }
        return result
    }
    public func apply(_ suggestions: [PlanSuggestion]) throws {
        try transaction {
            var used = Set(blocks.filter { !$0.archived && $0.kind == .lecture }.compactMap { b -> String? in guard let c = b.courseID, let l = b.lesson else { return nil }; return LessonCompletion.key(c, l) })
            used.formUnion(completions.map(\.key))
            for s in suggestions where !used.contains(s.id) {
                var d = BlockDraft(); d.kind = .lecture; d.courseID = s.courseID; d.lesson = s.lesson; d.day = s.day
                try validate(d); context.insert(makeBlock(d)); used.insert(s.id)
            }
        }
    }
}
