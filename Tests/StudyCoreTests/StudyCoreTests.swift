import XCTest
import SwiftData
@testable import StudyCore

@MainActor final class StudyCoreTests: XCTestCase {
    func makeStore() throws -> StudyStore { try StudyStore(container: StudyStore.makeContainer(inMemory: true)) }
    func course(_ store: StudyStore, total: Int = 3, completed: Int = 0) throws -> Course {
        var d = CourseDraft(); d.title = "확률과 통계"; d.total = total; d.completed = completed
        return try store.addCourse(d)
    }
    func lecture(_ store: StudyStore, _ c: Course, _ number: Int, day: String = StudyDate.key()) throws -> StudyBlock {
        var d = BlockDraft(); d.kind = .lecture; d.courseID = c.id; d.lesson = number; d.day = day
        return try store.addBlock(d)
    }
    func testNextLessonAndFinalCompletion() throws {
        let s = try makeStore(), c = try course(s, completed: 1)
        XCTAssertEqual(s.nextLesson(c), 2)
        let b = try lecture(s, c, 2)
        try s.setStatus(b, .done)
        XCTAssertEqual(s.completedLessons(c), [1, 2]); XCTAssertEqual(s.nextLesson(c), 3)
        try s.setLesson(c, lesson: 3, done: true)
        XCTAssertNil(s.nextLesson(c)); XCTAssertNil(s.nextUnplanned(c))
    }
    func testDuplicateCompletionAndUndoAcrossScreens() throws {
        let s = try makeStore(), c = try course(s)
        let b = try lecture(s, c, 1)
        try s.setLesson(c, lesson: 1, done: true)
        XCTAssertEqual(s.status(b), .done)
        try s.setStatus(b, .done); try s.setLesson(c, lesson: 1, done: true)
        XCTAssertEqual(s.completions.count, 1)
        try s.setStatus(b, .pending)
        XCTAssertTrue(s.completedLessons(c).isEmpty); XCTAssertEqual(s.nextLesson(c), 1); XCTAssertEqual(s.status(b), .pending)
    }
    func testSkippedLessonAndMultiplePlannedLectures() throws {
        let s = try makeStore(), c = try course(s, total: 5)
        try s.setLesson(c, lesson: 3, done: true)
        XCTAssertEqual(s.nextLesson(c), 1)
        _ = try lecture(s, c, 1)
        XCTAssertEqual(s.nextUnplanned(c), 2)
        _ = try lecture(s, c, 2)
        XCTAssertEqual(s.nextUnplanned(c), 4)
        XCTAssertThrowsError(try lecture(s, c, 1))
    }
    func testGeneralBlockAndIndependentProblemProgress() throws {
        let s = try makeStore(), c = try course(s)
        let b = try lecture(s, c, 1)
        var d = BlockDraft(); d.title = "1강 예제 풀이"; d.kind = .problems; d.courseID = c.id; d.lesson = 1; d.quantity = 12; d.unit = "문항"
        let problems = try s.addBlock(d)
        try s.setStatus(b, .done)
        XCTAssertEqual(s.status(problems), .pending)
        try s.setStatus(problems, .done); XCTAssertNotNil(problems.completedAt)
        try s.setStatus(b, .pending)
        XCTAssertEqual(s.status(problems), .done)
    }
    func testRolloverMovesIdentityAndCapsBacklog() throws {
        let s = try makeStore(), day = StudyDate.key()
        for n in 0..<15 { var d = BlockDraft(); d.title = "복습 \(n)"; d.day = StudyDate.adding(day, days: -2); _ = try s.addBlock(d) }
        let ids = Set(s.blocks.map(\.id))
        XCTAssertEqual(try s.rollover(to: day), 12)
        XCTAssertEqual(s.dayBlocks(day).count, 12); XCTAssertEqual(s.blocks.count, 15); XCTAssertEqual(Set(s.blocks.map(\.id)), ids)
        XCTAssertEqual(try s.rollover(to: day), 0)
        let b = s.dayBlocks(day)[0]
        try s.setStatus(b, .done)
        XCTAssertThrowsError(try s.move(b, to: StudyDate.adding(day, days: 1)))
    }
    func testWeeklyQuantityAndUndo() throws {
        let s = try makeStore(), c = try course(s, total: 5, completed: 2), day = StudyDate.key()
        try s.saveGoal(nil, week: day, subject: "수학", kind: .lecture, courseID: c.id, target: 2, unit: "강")
        let lectureGoal = s.goals[0]
        XCTAssertEqual(s.achieved(lectureGoal), 0, "Initial progress must not count as today's study")
        try s.setLesson(c, lesson: 3, done: true); try s.setLesson(c, lesson: 4, done: true)
        XCTAssertEqual(s.achieved(lectureGoal), 2)
        try s.setLesson(c, lesson: 4, done: false); XCTAssertEqual(s.achieved(lectureGoal), 1)
        var d = BlockDraft(); d.title = "문제 풀이"; d.kind = .problems; d.quantity = 25; d.unit = "문항"
        let b = try s.addBlock(d); try s.setStatus(b, .done)
        try s.saveGoal(nil, week: day, subject: "수학", kind: .problems, courseID: nil, target: 20, unit: "문항")
        let g = s.goals.first { $0.kind == .problems }!
        XCTAssertEqual(s.achieved(g), 25)
        try s.archive(b); XCTAssertEqual(s.achieved(g), 25)
        try s.setStatus(b, .pending); XCTAssertEqual(s.achieved(g), 0)
    }
    func testSaveFailureRollsBackWholeOperation() throws {
        let s = try makeStore(), c = try course(s), b = try lecture(s, c, 1)
        enum DiskError: Error { case full }
        s.saveOverride = { throw DiskError.full }
        XCTAssertThrowsError(try s.setStatus(b, .done))
        XCTAssertTrue(s.completions.isEmpty); XCTAssertEqual(s.status(b), .pending); XCTAssertTrue(s.events.isEmpty)
        XCTAssertThrowsError(try s.setStatus(b, .active)); XCTAssertEqual(b.statusRaw, "pending")
        s.saveOverride = nil
        try s.setStatus(b, .done)
        XCTAssertEqual(s.completedLessons(c), [1])
    }
    func testCourseResizePreservesHistoryAndRequiresConfirmation() throws {
        let s = try makeStore(), c = try course(s, total: 5)
        try s.setLesson(c, lesson: 4, done: true)
        let b = try lecture(s, c, 5)
        var d = CourseDraft(); d.title = c.title; d.total = 3
        XCTAssertThrowsError(try s.updateCourse(c, draft: d))
        XCTAssertEqual(c.total, 5)
        try s.updateCourse(c, draft: d, confirmTrim: true)
        XCTAssertTrue(s.completedLessons(c).isEmpty); XCTAssertEqual(s.completions.count, 1); XCTAssertTrue(b.archived)
        d.total = 6; try s.updateCourse(c, draft: d)
        XCTAssertEqual(s.completedLessons(c), [4])
    }
    func testRecurringReviewDoesNotDuplicateAfterMoveOrArchive() throws {
        let s = try makeStore(), day = StudyDate.key()
        try s.saveRule(nil, title: "단어 복습", subject: "영어", startDay: day, weekdays: [], interval: 2, enabled: true)
        try s.materialize(day: day); try s.materialize(day: day)
        XCTAssertEqual(s.blocks.count, 1)
        let b = s.blocks[0]; try s.move(b, to: StudyDate.adding(day, days: 1)); try s.archive(b)
        try s.materialize(day: day); XCTAssertEqual(s.blocks.count, 1)
        try s.materialize(day: StudyDate.adding(day, days: 1)); XCTAssertEqual(s.blocks.count, 1)
        try s.materialize(day: StudyDate.adding(day, days: 2)); XCTAssertEqual(s.blocks.count, 2)
        let r = s.rules[0]
        try s.saveRule(r, title: r.title, subject: r.subject, startDay: day, weekdays: [], interval: 2, enabled: false)
        try s.materialize(day: StudyDate.adding(day, days: 4)); XCTAssertEqual(s.blocks.count, 2)
    }
    func testSuggestionsAreIdempotentAndRespectManualBlocks() throws {
        let s = try makeStore(), c = try course(s, total: 10), day = StudyDate.key()
        let manual = try lecture(s, c, 1)
        try s.saveGoal(nil, week: day, subject: "수학", kind: .lecture, courseID: c.id, target: 4, unit: "강")
        let suggestions = s.suggestions(week: day)
        XCTAssertEqual(suggestions.count, 3)
        try s.apply(suggestions); try s.apply(suggestions)
        XCTAssertEqual(s.blocks.count, 4); XCTAssertTrue(s.blocks.contains { $0.id == manual.id })
        XCTAssertTrue(s.suggestions(week: day).isEmpty)
        let goal = s.goals[0]
        try s.saveGoal(goal, week: day, subject: "수학", kind: .lecture, courseID: c.id, target: 1, unit: "강")
        XCTAssertTrue(s.suggestions(week: day).isEmpty); XCTAssertEqual(s.blocks.count, 4)
    }
    func testBackupRoundTripAndValidationAreAtomic() throws {
        let s = try makeStore(), c = try course(s)
        let b = try lecture(s, c, 1); try s.setStatus(b, .done)
        let data = try s.exportJSON()
        try s.restoreJSON(data); XCTAssertEqual(s.courses.count, 1); XCTAssertEqual(s.completions.count, 1)
        let other = try makeStore(); try other.restoreJSON(data)
        XCTAssertEqual(other.courses[0].id, c.id); XCTAssertEqual(other.blocks[0].id, b.id); XCTAssertEqual(other.status(other.blocks[0]), .done)
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json["formatVersion"] = 999
        XCTAssertThrowsError(try s.restoreJSON(JSONSerialization.data(withJSONObject: json)))
        XCTAssertEqual(s.completedLessons(c), [1])
        var backup = try StudyStore.inspectBackup(data)
        backup.completions.append(backup.completions[0])
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        XCTAssertThrowsError(try s.restoreJSON(encoder.encode(backup)))
        enum DiskError: Error { case full }
        s.saveOverride = { throw DiskError.full }
        XCTAssertThrowsError(try s.restoreJSON(data))
        XCTAssertEqual(s.courses.count, 1); XCTAssertEqual(s.completions.count, 1)
    }
    func testSeoulMidnightAndWeekBoundary() {
        let formatter = ISO8601DateFormatter()
        XCTAssertEqual(StudyDate.key(formatter.date(from: "2026-11-16T14:59:59Z")!), "2026-11-16")
        XCTAssertEqual(StudyDate.key(formatter.date(from: "2026-11-16T15:00:00Z")!), "2026-11-17")
        XCTAssertEqual(StudyDate.week("2026-11-22"), "2026-11-16")
        XCTAssertEqual(StudyDate.week("2026-11-23"), "2026-11-23")
        XCTAssertFalse(StudyDate.valid("2026-02-30")); XCTAssertFalse(StudyDate.valid("oops"))
    }
    func testReorderAndMoveRetainSingleBlock() throws {
        let s = try makeStore(), day = StudyDate.key()
        var d = BlockDraft(); d.title = "첫 학습"
        let first = try s.addBlock(d); d.title = "둘째 학습"
        let second = try s.addBlock(d); d.title = "셋째 학습"
        let third = try s.addBlock(d)
        try s.reorder(third.id, before: first.id, day: day)
        XCTAssertEqual(s.dayBlocks(day).map(\.id), [third.id, first.id, second.id])
        try s.move(second, to: StudyDate.adding(day, days: 1))
        XCTAssertEqual(s.blocks.count, 3); XCTAssertEqual(s.dayBlocks(day).count, 2)
        XCTAssertEqual(s.dayBlocks(StudyDate.adding(day, days: 1)).map(\.id), [second.id])
        XCTAssertEqual(second.originalDay, day)
    }
    func testCourseMetadataUpdatesLinkedBlocksAndKeepsCustomTitles() throws {
        let s = try makeStore(), c = try course(s)
        let b = try lecture(s, c, 1)
        var d = CourseDraft(); d.title = "새 강좌명"; d.subject = "과학"; d.total = 4
        try s.updateCourse(c, draft: d)
        XCTAssertEqual(b.title, "새 강좌명 · 1강"); XCTAssertEqual(b.subject, "과학")
        var edit = BlockDraft(); edit.title = "직접 쓴 제목"; edit.subject = "영어"
        try s.updateBlock(b, draft: edit); XCTAssertEqual(b.subject, "과학")
        d.title = "두 번째 이름"; try s.updateCourse(c, draft: d)
        XCTAssertEqual(b.title, "직접 쓴 제목")
    }
    func testTrimmedHistorySurvivesBackupAndCanBeUndone() throws {
        let s = try makeStore(), c = try course(s, total: 5)
        try s.setLesson(c, lesson: 5, done: true)
        var d = CourseDraft(); d.title = c.title; d.total = 3
        try s.updateCourse(c, draft: d, confirmTrim: true)
        let other = try makeStore(); try other.restoreJSON(s.exportJSON())
        XCTAssertEqual(other.completions.first?.lesson, 5)
        XCTAssertEqual(other.courses.first?.total, 3)
        try other.setLesson(other.courses[0], lesson: 5, done: false)
        XCTAssertTrue(other.completions.isEmpty)
    }
    func testDiskPersistenceAfterNewContainer() throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("Study.store")
        var savedID: UUID!
        do {
            let s = try StudyStore(container: StudyStore.makeContainer(url: url)), c = try course(s)
            savedID = c.id; let b = try lecture(s, c, 1); try s.setStatus(b, .done)
        }
        let restored = try StudyStore(container: StudyStore.makeContainer(url: url))
        XCTAssertEqual(restored.courses.first?.id, savedID)
        XCTAssertEqual(restored.status(restored.blocks[0]), .done)
        XCTAssertEqual(restored.nextLesson(restored.courses[0]), 2)
    }
    func testCourseURLAndPlannedHelpers() throws {
        let s = try makeStore()
        var cd = CourseDraft(); cd.title = "미적분 개념완성"; cd.subject = "수학"; cd.link = "https://www.ebsi.co.kr/course/123"; cd.total = 10; cd.completed = 2
        let c = try s.addCourse(cd)
        XCTAssertEqual(c.validURL?.absoluteString, "https://www.ebsi.co.kr/course/123")
        let b = try lecture(s, c, 3)
        XCTAssertEqual(s.courseURL(for: b)?.host, "www.ebsi.co.kr")
        XCTAssertEqual(s.plannedBlock(for: c, lesson: 3)?.id, b.id)
        try s.saveGoal(nil, week: StudyDate.key(), subject: "수학", kind: .lecture, courseID: c.id, target: 4, unit: "강")
        let g = s.goals[0]
        XCTAssertEqual(s.plannedPending(g), 1)
        try s.setStatus(b, .done)
        XCTAssertNil(s.plannedBlock(for: c, lesson: 3))
        XCTAssertEqual(s.plannedPending(g), 0)
        XCTAssertEqual(s.achieved(g), 1)
    }
}
