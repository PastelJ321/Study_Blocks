import Foundation
import StudyCore

@main struct Probe {
    @MainActor static func main() throws {
        let args = CommandLine.arguments
        guard args.count == 3 else { fatalError("Usage: PersistenceProbe write|read|seed STORE_PATH") }
        let store = try StudyStore(container: StudyStore.makeContainer(url: URL(fileURLWithPath: args[2])))
        if args[1] == "write" {
            var c = CourseDraft(); c.title = "재실행 검증 강좌"; c.total = 3; c.completed = 1
            let course = try store.addCourse(c)
            var b = BlockDraft(); b.kind = .lecture; b.courseID = course.id; b.lesson = 2
            let block = try store.addBlock(b); try store.setStatus(block, .done)
            var general = BlockDraft(); general.title = "문제 1~10"; general.kind = .problems; general.quantity = 10; general.unit = "문항"
            let g = try store.addBlock(general); try store.setStatus(g, .done)
            try store.saveGoal(nil, week: StudyDate.key(), subject: "수학", kind: .problems, courseID: nil, target: 20, unit: "문항")
            print("WRITE_OK courses=\(store.courses.count) completed=\(store.completedLessons(course).count) next=\(store.nextLesson(course)!)")
        } else if args[1] == "read" {
            guard let course = store.courses.first, store.completedLessons(course) == [1, 2], store.nextLesson(course) == 3,
                  store.blocks.count == 2, store.blocks.allSatisfy({store.status($0) == .done}),
                  let goal = store.goals.first, store.achieved(goal) == 10 else { fatalError("Persistence mismatch") }
            print("READ_OK courses=1 completed=2 next=3 blocks=2 weekly=10/20")
        } else if args[1] == "seed" {
            let today = StudyDate.key()
            let week = StudyDate.week(today)

            var c1 = CourseDraft()
            c1.title = "세젤쉬 확률과 통계"; c1.subject = "수학"; c1.teacher = "이미지"; c1.platform = "대성마이맥"
            c1.link = "https://www.mimacstudy.com"; c1.total = 14; c1.completed = 12
            c1.targetDate = StudyDate.date(StudyDate.adding(today, days: 5))
            let course1 = try store.addCourse(c1)

            var c2 = CourseDraft()
            c2.title = "세젤쉬 미적분Ⅰ"; c2.subject = "수학"; c2.teacher = "이미지"; c2.platform = "대성마이맥"
            c2.link = "https://www.mimacstudy.com"; c2.total = 26; c2.completed = 20
            c2.targetDate = StudyDate.date(StudyDate.adding(today, days: 14))
            let course2 = try store.addCourse(c2)

            var c3 = CourseDraft()
            c3.title = "인셉션 - 독해"; c3.subject = "국어"; c3.teacher = "김동욱"; c3.platform = "메가스터디"
            c3.link = "https://www.megastudy.net"; c3.total = 13; c3.completed = 5
            let course3 = try store.addCourse(c3)

            var c4 = CourseDraft()
            c4.title = "인셉션 - 문학개념어"; c4.subject = "국어"; c4.teacher = "김동욱"; c4.platform = "메가스터디"
            c4.link = "https://www.megastudy.net"; c4.total = 12; c4.completed = 12
            _ = try store.addCourse(c4)

            // Completed today
            var bDone1 = BlockDraft()
            bDone1.kind = .lecture; bDone1.courseID = course1.id; bDone1.lesson = 13; bDone1.day = today
            let blockDone1 = try store.addBlock(bDone1)
            try store.setStatus(blockDone1, .done)

            var bDone2 = BlockDraft()
            bDone2.kind = .lecture; bDone2.courseID = course3.id; bDone2.lesson = 6; bDone2.day = today
            let blockDone2 = try store.addBlock(bDone2)
            try store.setStatus(blockDone2, .done)

            var bDone3 = BlockDraft()
            bDone3.kind = .problems; bDone3.subject = "수학"; bDone3.title = "확률과 통계 조건부확률 기출 풀이"
            bDone3.quantity = 12; bDone3.unit = "문항"; bDone3.day = today; bDone3.isCore = true
            let blockDone3 = try store.addBlock(bDone3)
            try store.setStatus(blockDone3, .done)

            // Pending today
            var bPend1 = BlockDraft()
            bPend1.kind = .lecture; bPend1.courseID = course1.id; bPend1.lesson = 14; bPend1.day = today; bPend1.isCore = true
            let blockPend1 = try store.addBlock(bPend1)
            try store.setStatus(blockPend1, .active)

            var bPend2 = BlockDraft()
            bPend2.kind = .lecture; bPend2.courseID = course2.id; bPend2.lesson = 21; bPend2.day = today; bPend2.isCore = true
            _ = try store.addBlock(bPend2)

            var bPend3 = BlockDraft()
            bPend3.kind = .problems; bPend3.subject = "수학"; bPend3.title = "미적분Ⅰ 도함수 활용 45~64번 풀이"
            bPend3.details = "오답 문항은 풀이 과정 노트 정리"; bPend3.quantity = 20; bPend3.unit = "문항"; bPend3.day = today; bPend3.isCore = true
            _ = try store.addBlock(bPend3)

            var bPend4 = BlockDraft()
            bPend4.kind = .review; bPend4.subject = "영어"; bPend4.title = "영어 빈칸·순서 고난도 지문 복습"
            bPend4.quantity = 1; bPend4.unit = "회"; bPend4.day = today; bPend4.isCore = false
            _ = try store.addBlock(bPend4)

            // Planned on upcoming days of the week
            let tomorrow = StudyDate.adding(today, days: 1)
            var bTom1 = BlockDraft()
            bTom1.kind = .lecture; bTom1.courseID = course2.id; bTom1.lesson = 22; bTom1.day = tomorrow
            _ = try store.addBlock(bTom1)

            var bTom2 = BlockDraft()
            bTom2.kind = .lecture; bTom2.courseID = course3.id; bTom2.lesson = 7; bTom2.day = tomorrow
            _ = try store.addBlock(bTom2)

            // Weekly goals
            try store.saveGoal(nil, week: week, subject: "수학", kind: .lecture, courseID: course1.id, target: 2, unit: "강")
            try store.saveGoal(nil, week: week, subject: "수학", kind: .lecture, courseID: course2.id, target: 4, unit: "강")
            try store.saveGoal(nil, week: week, subject: "수학", kind: .problems, courseID: nil, target: 40, unit: "문항")
            try store.saveGoal(nil, week: week, subject: "국어", kind: .lecture, courseID: course3.id, target: 3, unit: "강")

            // Recurrence rules
            try store.saveRule(nil, title: "영단어 Day별 누적 복습", subject: "영어", startDay: week, weekdays: [2, 4, 6], interval: 0, enabled: true)
            try store.saveRule(nil, title: "수학 핵심 오답 문항 재풀이", subject: "수학", startDay: week, weekdays: [], interval: 3, enabled: true)

            print("SEED_OK")
        }
    }
}
