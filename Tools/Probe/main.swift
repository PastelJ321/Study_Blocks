import Foundation
import StudyCore

@main struct Probe {
    @MainActor static func main() throws {
        let args = CommandLine.arguments
        guard args.count == 3 else { fatalError("Usage: PersistenceProbe write|read STORE_PATH") }
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
        } else {
            guard let course = store.courses.first, store.completedLessons(course) == [1, 2], store.nextLesson(course) == 3,
                  store.blocks.count == 2, store.blocks.allSatisfy({store.status($0) == .done}),
                  let goal = store.goals.first, store.achieved(goal) == 10 else { fatalError("Persistence mismatch") }
            print("READ_OK courses=1 completed=2 next=3 blocks=2 weekly=10/20")
        }
    }
}
