import SwiftUI

struct CoursesView: View {
    @Bindable var app: AppState
    let store: StudyStore
    @State private var selected: Course?
    @State private var showArchived = false
    var body: some View {
        let courses = store.courses.filter { $0.archived == showArchived }
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .bottom) {
                    PageHeader(eyebrow: "\(courses.count)개 강좌 · \(courses.filter { store.nextLesson($0) == nil }.count)개 완강", title: "나의 강좌")
                    Toggle("보관한 강좌", isOn: $showArchived).toggleStyle(.button).font(.callout)
                    Button("강좌 등록") { app.showNewCourse = true }.buttonStyle(.borderedProminent)
                }
                if courses.isEmpty {
                    EmptyCard(symbol: "play.rectangle", title: showArchived ? "보관한 강좌가 없어요" : "듣고 있는 강좌를 등록하세요", detail: showArchived ? "" : "현재 진도를 한 번 입력하면 다음 강의가 이어집니다.", action: "강좌 등록") { app.showNewCourse = true }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 20)], spacing: 20) {
                        ForEach(courses) { c in
                            VStack(alignment: .leading, spacing: 18) {
                                HStack { SubjectTag(subject: c.subject); Spacer(); Text(store.nextLesson(c) == nil ? "완강" : store.completedLessons(c).isEmpty ? "시작 전" : "수강 중").font(.caption).foregroundStyle(store.nextLesson(c) == nil ? Color.studyAccent : .secondary) }
                                Button { selected = c } label: { Text(c.title).font(.system(size: 18, weight: .semibold)).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.plain)
                                Text([c.teacher, c.platform].filter { !$0.isEmpty }.joined(separator: " · ")).font(.callout).foregroundStyle(.secondary)
                                VStack(spacing: 8) {
                                    HStack { Text("\(store.completedLessons(c).count) / \(c.total)강"); Spacer(); Text("\(Int(Double(store.completedLessons(c).count) / Double(c.total) * 100))%") }.font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                    ProgressView(value: Double(store.completedLessons(c).count), total: Double(c.total)).tint(Color.subject(c.subject))
                                }
                                HStack {
                                    if let next = store.nextLesson(c) { Text("다음 \(next)강").font(.callout.weight(.medium)) }
                                    else { Label("모든 강의를 마쳤어요", systemImage: "checkmark").font(.callout).foregroundStyle(Color.studyAccent) }
                                    Spacer()
                                    Button("상세 보기") { selected = c }.buttonStyle(.borderless)
                                }
                                if !c.archived && store.nextUnplanned(c) != nil {
                                    Button { addNext(c) } label: { Label("다음 강의 오늘에 추가", systemImage: "plus").frame(maxWidth: .infinity) }.buttonStyle(.bordered).controlSize(.large)
                                }
                            }.padding(22).background(Color.card, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(.primary.opacity(0.08)))
                        }
                    }
                }
            }.padding(32).frame(maxWidth: 1200)
        }.navigationTitle("강좌").sheet(item: $selected) { c in CourseDetail(app: app, store: store, course: c) }
    }
    private func addNext(_ c: Course) {
        guard let lesson = store.nextUnplanned(c) else { return }
        var draft = BlockDraft(); draft.kind = .lecture; draft.courseID = c.id; draft.lesson = lesson; draft.day = StudyDate.key()
        app.perform { try store.addBlock(draft); app.notice = "\(lesson)강을 오늘 학습에 추가했습니다." }
    }
}

struct CourseDetail: View {
    @Bindable var app: AppState
    let store: StudyStore
    let course: Course
    @State private var editing = false
    @State private var showBlock = false
    @State private var lessonPage = 0
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            HStack { SubjectTag(subject: course.subject); Spacer(); Button("수정") { editing = true }; Button("닫기") { dismiss() }.keyboardShortcut(.cancelAction) }.padding(24)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(course.title).font(.title.bold())
                    Text([course.teacher, course.platform].filter { !$0.isEmpty }.joined(separator: " · ")).foregroundStyle(.secondary)
                    HStack { Text("\(store.completedLessons(course).count) / \(course.total)강 완료").font(.headline); Spacer(); Text(store.nextLesson(course).map { "다음 \($0)강" } ?? "완강").foregroundStyle(Color.studyAccent) }
                    ProgressView(value: Double(store.completedLessons(course).count), total: Double(course.total))
                    HStack {
                        if let next = store.nextLesson(course) {
                            Button("\(next)강 수강 완료") { app.perform { try store.setLesson(course, lesson: next, done: true) } }.buttonStyle(.borderedProminent)
                        }
                        Button("학습에 추가") { showBlock = true }.disabled(store.nextUnplanned(course) == nil)
                        if let url = URL(string: course.link), ["http", "https"].contains(url.scheme ?? "") { Link("강좌 열기 ↗", destination: url) }
                    }
                    if let target = course.targetDate { Label("완강 목표 \(StudyDate.label(StudyDate.key(target), format: "yyyy. M. d."))", systemImage: "flag").font(.callout).foregroundStyle(.secondary) }
                    if !course.notes.isEmpty { Text(course.notes).font(.callout).textSelection(.enabled) }
                    Divider()
                    HStack {
                        Text("강의별 진도").font(.headline); Spacer()
                        if course.total > 50 {
                            Button { lessonPage = max(0, lessonPage - 1) } label: { Image(systemName: "chevron.left") }.disabled(lessonPage == 0)
                            Text("\(lessonPage * 50 + 1)–\(min(course.total, (lessonPage + 1) * 50))").font(.caption.monospacedDigit())
                            Button { lessonPage += 1 } label: { Image(systemName: "chevron.right") }.disabled((lessonPage + 1) * 50 >= course.total)
                        }
                    }
                    Text("강의 번호를 누르면 완료하거나 취소할 수 있어요. 건너뛴 강의도 따로 표시됩니다.").font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 8)], spacing: 8) {
                        ForEach(Array((min(lessonPage * 50 + 1, course.total))...min(course.total, (lessonPage + 1) * 50)), id: \.self) { lesson in
                            let done = store.completedLessons(course).contains(lesson)
                            Button { app.perform { try store.setLesson(course, lesson: lesson, done: !done) } } label: {
                                HStack(spacing: 4) { if done { Image(systemName: "checkmark").font(.caption2) }; Text("\(lesson)강").monospacedDigit() }.frame(maxWidth: .infinity).padding(.vertical, 12).foregroundStyle(done ? Color.studyAccent : .secondary).background(done ? Color.studyAccent.opacity(0.12) : .secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
                            }.buttonStyle(.plain).accessibilityLabel("\(lesson)강 \(done ? "완료 취소" : "완료")")
                        }
                    }
                    Divider()
                    Button(course.archived ? "보관 해제" : "강좌 보관") { app.perform { try store.archiveCourse(course); dismiss() } }.foregroundStyle(.secondary)
                }.padding(24)
            }
        }.frame(width: 640, height: 700)
        .sheet(isPresented: $editing) { CourseEditor(app: app, store: store, course: course) }
        .sheet(isPresented: $showBlock) { BlockEditor(app: app, store: store, day: app.selectedDay, presetCourse: course) }
        .onChange(of: course.total) { _, _ in lessonPage = min(lessonPage, (course.total - 1) / 50) }
    }
}
